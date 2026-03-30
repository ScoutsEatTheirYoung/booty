local mq = require('mq')
local bt = require('booty.bot.bt.engine')
local bb = require('booty.bot.bt.blackboard')

local spell = {}

-- ============================================================
-- Gem scoring (shared with buff.lua via module cache)
-- Score increments on cast, resets to 0 on mem.
-- nextGem() picks randomly among tied lowest-score gems.
-- ============================================================
---@type integer[]
local gemScores = {}
local numGems = mq.TLO.Me.NumGems() or 8

for i = 1, numGems do gemScores[i] = 0 end

local function findGem(spellName)
    for i = 1, numGems do
        if mq.TLO.Me.Gem(i)() == spellName then return i end
    end
    return nil
end

function spell.nextGem()
    local minScore = math.huge
    local candidates = {}
    for gem, s in ipairs(gemScores) do
        if s == minScore then table.insert(candidates, gem) end
        if s < minScore then
            minScore = s
            candidates = { gem }
        end
    end
    return candidates[math.random(#candidates)]
end

function spell.gemScoreZero(gem)
    if gemScores[gem] ~= nil then gemScores[gem] = 0 end
end

function spell.gemScoreAddOne(gem)
    if gemScores[gem] ~= nil then gemScores[gem] = gemScores[gem] + 1 end
end

-- ============================================================
-- Nodes
-- ============================================================

--- RUNNING while a cast is in progress, SUCCESS when idle.
function spell.guardCasting()
    return bt.Leaf("guardCasting", function()
        if mq.TLO.Me.Casting.ID() then
            return bt.RUNNING, "Casting " .. (mq.TLO.Me.Casting.Name() or "spell")
        end
        return bt.SUCCESS, "Not casting"
    end)
end

---@param bb_key string The blackboard key containing the spell name (e.g., "PrimaryHeal")
function spell.castSpell(bb_key)
    return bt.MemSequence("Cast_Routine(" .. bb_key .. ")", {
        
        spell.isKnown(bb_key),
        spell.hasManaFor(bb_key),
        
        bt.Selector("Ensure_Memorized(" .. bb_key .. ")", {
            spell.isMemorized(bb_key),
            spell.memSpell(bb_key)
        }),
        
        spell.isReady(bb_key),
        spell.executeCast(bb_key)
    })
end
-- SENSORS

function spell.stacksOnTarget(bb_key)
    return bt.Leaf("StacksOnTarget(" .. bb_key .. ")", function()
        local spellName = bb.get(bb_key)
        print(string.format("--- Checking if %s is needed on %s", spellName, mq.TLO.Target.Name() or "target"))
        print("Checking stacks of " .. tostring(spellName) .. " on target...")
        if not spellName then return bt.FAILURE, "No spell in BB" end

        local target = mq.TLO.Target
        if not target() then return bt.FAILURE, "No target" end
        
        local stacks = mq.TLO.Spell(spellName).StacksTarget()
        if stacks then
            return bt.SUCCESS, string.format("%s stacks on target", spellName)
        else
            return bt.FAILURE, "Buff not on target"
        end
    end)
end
function spell.isKnown(bb_key)
    return bt.Leaf("IsKnown(" .. bb_key .. ")", function()
        local spellName = bb.get(bb_key)
        if not spellName then return bt.FAILURE, "No spell name in BB key: " .. bb_key end
        
        if mq.TLO.Me.Book(spellName)() then return bt.SUCCESS end
        return bt.FAILURE, spellName .. " not in spellbook"
    end)
end

function spell.hasManaFor(bb_key)
    return bt.Leaf("HasMana(" .. bb_key .. ")", function()
        local spellName = bb.get(bb_key)
        if not spellName then return bt.FAILURE, "No spell in BB" end

        local cost = mq.TLO.Spell(spellName).Mana() or 0
        if mq.TLO.Me.CurrentMana() >= cost then return bt.SUCCESS end
        return bt.FAILURE, "Not enough mana for " .. spellName
    end)
end

function spell.isMemorized(bb_key)
    return bt.Leaf("IsMemorized(" .. bb_key .. ")", function()
        local spellName = bb.get(bb_key)
        if not spellName then return bt.FAILURE, "No spell in BB" end

        if findGem(spellName) then return bt.SUCCESS end
        return bt.FAILURE, spellName .. " not memorized"
    end)
end

function spell.isReady(bb_key)
    return bt.Leaf("IsReady(" .. bb_key .. ")", function()
        local spellName = bb.get(bb_key)
        if not spellName then return bt.FAILURE, "No spell in BB" end

        local gem = findGem(spellName)
        if not gem then return bt.FAILURE, "Spell not on bar" end

        if mq.TLO.Me.SpellReady(gem)() then 
            return bt.SUCCESS 
        end
        return bt.RUNNING, string.format("Waiting for gem %d cooldown", gem)
    end)
end

-- ACTIONS
function spell.memSpell(bb_key)
    return bt.Leaf("MemSpell(" .. bb_key .. ")", function()
        local spellName = bb.get(bb_key)
        if not spellName then return bt.FAILURE, "No spell in BB" end

        if mq.TLO.Window('SpellBookWnd').Open() then
            return bt.RUNNING, "Waiting for book to close/mem to finish"
        end
        
        local gem = spell.nextGem()
        mq.cmdf('/memspell %d "%s"', gem, spellName)
        spell.gemScoreZero(gem)
        
        return bt.RUNNING, "Started memorizing " .. spellName .. " into gem " .. gem
    end)
end

-- this leaf assumes the caller has already verified the spell is memorized and ready to cast
-- and the target is properly set. It just executes the cast and waits for it to finish.
function spell.executeCast(bb_key)
    local sentCommand = false
    local timeSentCommand = 0
    local castingSpellVerified = false
    local spellCastDelay = 500

    local function resetVars()
        sentCommand = false
        timeSentCommand = 0
        castingSpellVerified = false
    end

    local me = mq.TLO.Me

    return bt.Leaf("ExecuteCast(" .. bb_key .. ")", function()
        local now = mq.gettime()

        -- STATE 3: The spell is actively channeling. Wait for it to finish.
        if castingSpellVerified then
            if not me.Casting.ID() then
                resetVars()
                return bt.SUCCESS, "Cast complete"
            else
                return bt.RUNNING, "Channeling..."
            end
        end

        -- STATE 2: We clicked the button. Bridging server latency.
        if sentCommand then
            -- Check if the server has registered the cast yet
            if me.Casting.ID() then
                castingSpellVerified = true
                return bt.RUNNING, "Cast verified, waiting to finish"
            end

            -- If we are still inside the delay window, yield and wait.
            if now < (timeSentCommand + spellCastDelay) then
                return bt.RUNNING, "Bridging server latency..."
            end

            -- If we exceeded the delay window and still aren't casting, it failed.
            resetVars()
            return bt.FAILURE, "Failed to cast (fizzle, interrupt, or lag)"
        end

        -- STATE 1: IDLE. Ready to fire.
        local spellName = bb.get(bb_key)
        if not spellName then return bt.FAILURE, "No spell in BB" end

        -- If we are already casting something else, hold here.
        if me.Casting.ID() then
            return bt.RUNNING, "Busy casting " .. (me.Casting.Name() or "spell")
        end
        
        local gem = findGem(spellName)
        if not gem then return bt.FAILURE, "Lost gem for " .. spellName end

        -- Fire the command and transition to STATE 2
        mq.cmdf('/cast %d', gem)
        spell.gemScoreAddOne(gem)
        
        sentCommand = true
        timeSentCommand = now
        
        return bt.RUNNING, "Initiating cast of " .. spellName
    end)
end

--- SUCCESS if we have a live pet.
function spell.hasPet()
    return bt.Leaf("hasPet", function()
        if mq.TLO.Me.Pet.ID() > 0 then
            return bt.SUCCESS, "Have pet"
        end
        return bt.FAILURE, "No pet"
    end)
end

function spell.hasReagent(bb_reagent_name)
    return bt.Leaf("hasReagent(" .. bb_reagent_name .. ")", function()
        local reagent = bb.get(bb_reagent_name)
        if not reagent then return bt.FAILURE, "No reagent name in BB" end

        if mq.TLO.FindItem(reagent)() then return bt.SUCCESS end
        return bt.FAILURE, "No " .. reagent .. " in bags"
    end)
end

--- Summon a pet. RUNNING while memorizing or casting.
--- FAILURE if spell not in book or reagent missing from bags.
---@param bbSpellName string
---@param bbReagentName string|nil
function spell.summonPet(bbSpellName, bbReagentName)
    return bt.Sequence("summonPet", {
        bt.Inverter("NoPet", spell.hasPet()),
        spell.isKnown(bbSpellName),
        spell.hasReagent(bbReagentName),
        spell.castSpell(bbSpellName)
    })
end

return spell
