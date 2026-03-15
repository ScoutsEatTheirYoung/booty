local mq = require('mq')

local actions = {}

-- for all actions, return true if there is more work to do, or false if we're done and can move on to the next action in the list

-- Returns the spawn ID of the leader's current target without touching our own target.
function actions.getLeaderTargetID(leaderName)
    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return 0 end
    return leader.TargetOfTarget.ID() or 0
end

function actions.getPcTarget(pcName)
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return nil end
    return pc.TargetOfTarget
end

-- Navigate to leader's position + offset if we've drifted beyond threshold.
-- Returns immediately; nav handles the pathing over multiple ticks.
function actions.fanFollow(leaderName, offset, threshold)
    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return end
    if leader.Distance() > threshold and not mq.TLO.Navigation.Active() then
        local destY = leader.Y() + (offset.y or 0)
        local destX = leader.X() + (offset.x or 0)
        mq.cmd(string.format('/squelch /nav locyx %f %f', destY, destX))
    end
end

-- Navigate toward the current target if outside melee range.
-- Stops 2 units short so we land in weapon range, not on top of the mob.
function actions.approachTarget(meleeRange)
    local target = mq.TLO.Target
    if not target() then return end
    if target.Distance() > meleeRange and not mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav target distance=' .. (meleeRange - 2))
    end
end

-- Turn auto-attack on if it isn't already.
function actions.attackOn()
    if not mq.TLO.Me.Combat() then
        mq.cmd('/attack on')
    end
end

-- Turn off auto-attack and stand down the pet.
function actions.combatOff()
    if mq.TLO.Me.Combat() then
        mq.cmd('/attack off')
    end
    if mq.TLO.Me.Pet.ID() > 0 then
        mq.cmd('/squelch /pet back off')
    end
end

-- Send pet to attack the target if it isn't already on it.
function actions.sendPet(targetID)
    if mq.TLO.Me.Pet.ID() > 0 and mq.TLO.Pet.Target.ID() ~= targetID then
        mq.cmd('/pet attack')
    end
end

-- Target a spawn by ID. Returns true if the target was already correct (no cmd sent).
function actions.targetID(id)
    if mq.TLO.Target.ID() == id then return true end
    mq.cmd('/squelch /tar id ' .. id)
    return false
end

-- ============================================================
-- Buff casting
-- ============================================================
-- Supported target specifiers in buff.targets:
--   "self"   -> you
--   "pet"    -> your pet
--   "group"  -> all group members + all their pets (including you and your pet)
--   "Name"   -> a specific named PC in the zone
--
-- @param buff: { name = "Spell Name", refreshTime = 300, targets = {"self", "pet", "group", "Beta"} }
--   refreshTime: recast when remaining duration (seconds) drops below this value
-- @param spellGemNum: gem slot to use/memorize this spell into (1-12)
--
-- One action per call (target, cast, or mem), then returns.
-- Call this every tick from your state's execute().

-- Tracks which target index we're currently evaluating for each buff.
local buffProgress = {}

-- Resolves target specifiers to a flat list of { id, label } pairs.
-- IDs are stored (not TLO refs) so lookups stay fresh each tick.
local function resolveTargets(targetList)
    local list = {}
    local seen = {}

    local function add(spawn, label)
        if not spawn then return end
        local id = spawn.ID()
        if not id or id <= 0 or seen[id] then return end
        seen[id] = true
        table.insert(list, { id = id, label = label })
    end

    for _, t in ipairs(targetList) do
        if t == "self" then
            add(mq.TLO.Me, "self")

        elseif t == "pet" then
            add(mq.TLO.Me.Pet, "my pet")

        elseif t == "group" then
            -- Group members + their pets
            -- Group.Members() returns count of OTHER members (excludes self)
            -- Group.Member(i).Spawn = their spawn, Group.Member(i).Pet = their pet spawn
            local count = mq.TLO.Group.Members() or 0
            for i = 1, count do
                local m = mq.TLO.Group.Member(i)
                if m and m.Name() then
                    add(m.Spawn,  m.Name())
                    add(m.Pet,    m.Name() .. "'s pet")
                end
            end

        else
            -- Named PC
            add(mq.TLO.Spawn('pc =' .. t), t)
        end
    end

    return list
end

function actions.castBuffs(buff, spellGemNum)
    -- Don't interrupt a cast or an open spellbook
    if mq.TLO.Me.Casting() or mq.TLO.Window('SpellBookWnd').Open() then return true end

    if not mq.TLO.Me.Book(buff.name)() then
        print(string.format('\ar[Bot]\aw Missing spell from book: %s', buff.name))
        return false
    end

    local targets = resolveTargets(buff.targets)
    if #targets == 0 then return true end

    -- Get current position; wrap back to 1 when we've seen everyone
    local idx = buffProgress[buff.name] or 1
    if idx > #targets then
        buffProgress[buff.name] = 1
        return  -- Full cycle done; start over next tick
    end

    local t = targets[idx]

    -- Fresh spawn lookup by ID each tick — handles zoning, death, etc.
    local spawn = mq.TLO.Spawn('id ' .. t.id)
    if not spawn() or spawn.Type() == "Corpse" then
        buffProgress[buff.name] = idx + 1
        return  -- Skip, advance
    end

    -- Acquire target; if we just sent /tar, return and let it land next tick
    if mq.TLO.Target.ID() ~= t.id then
        mq.cmd('/squelch /tar id ' .. t.id)
        return
    end

    -- Target is set — check buff status via Target TLO (works for PCs and pets)
    local duration = mq.TLO.Target.Buff(buff.name).Duration.TotalSeconds() or 0
    local needsBuff = not mq.TLO.Target.Buff(buff.name)() or duration <= buff.refreshTime

    if needsBuff then
        if mq.TLO.Me.Gem(spellGemNum)() == buff.name then
            if mq.TLO.Me.SpellReady(buff.name)() then
                mq.cmd('/cast ' .. spellGemNum)
                buffProgress[buff.name] = idx + 1  -- Move on after casting
            end
            -- Spell on cooldown: stay here, try again next tick
        else
            -- Wrong spell in gem slot — memorize and wait
            mq.cmd(string.format('/memspell %d "%s"', spellGemNum, buff.name))
        end
    else
        -- Already buffed — advance
        buffProgress[buff.name] = idx + 1
    end
end

return actions
