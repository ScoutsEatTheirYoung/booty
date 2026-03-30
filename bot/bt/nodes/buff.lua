local mq    = require('mq')
local bt    = require('booty.bot.bt.engine')
local spell = require('booty.bot.bt.nodes.spell')
local bb = require('booty.bot.bt.blackboard')
local target = require('booty.bot.bt.nodes.target')

local buff = {}

-- ============================================================
-- Helpers
-- ============================================================

local bbBuffQueueKey = "BuffQueue"
local bbBuffSpellNameKey = "CurrentBuffSpell"
local bbBuffTargetIDKey = "BuffTargetID"
local bbBuffTargetLabelKey = "BuffTargetLabel"
local bbBuffRefreshTimeKey = "BuffRefreshTime"

local function tableToString(tbl, indent_level, seen_tables)
    seen_tables = seen_tables or {}
    indent_level = indent_level or 0

    -- Check for circular references
    if seen_tables[tbl] then
        return "\"<circular reference>\""
    end
    seen_tables[tbl] = true

    local result = "{\n"
    local indent_space = string.rep("  ", indent_level) -- Use 2 spaces for indentation
    local nested_indent_space = string.rep("  ", indent_level + 1)

    for key, value in pairs(tbl) do
        local key_str
        if type(key) == "string" and key:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
            -- Use dot notation for simple string keys
            key_str = key
        else
            -- Use square brackets for other keys (numbers, non-identifier strings)
            key_str = string.format("[%s]", tostring(key))
        end

        result = result .. nested_indent_space .. key_str .. " = "

        if type(value) == "table" then
            -- Recursively call the function for nested tables
            result = result .. tableToString(value, indent_level + 1, seen_tables)
        elseif type(value) == "string" then
            -- Enclose strings in quotes
            result = result .. string.format("\"%s\"", value:gsub("\"", "\\\""):gsub("\n", "\\n"))
        else
            -- Use tostring for other types (numbers, booleans, etc.)
            result = result .. tostring(value)
        end
        result = result .. ",\n"
    end

    result = result .. indent_space .. "}"
    seen_tables[tbl] = nil -- Allow the table to be serialized again if needed elsewhere
    return result
end


--- Expand a BUFFS table into a flat list of {spellName, spawnID, label, refreshTime}.
--- Called at the start of each pass so group membership / pet status is current.
local function buildWorkList(buffs)
    local list = {}
    for _, entry in ipairs(buffs) do
        for _, target in ipairs(entry.targets or {}) do
            if target == "self" then
                table.insert(list, {
                    spellName   = entry.spellName,
                    spawnID     = mq.TLO.Me.ID(),
                    label       = "self",
                    refreshTime = entry.refreshTime or 0,
                })
            elseif target == "pet" then
                local petID = mq.TLO.Me.Pet.ID()
                if petID and petID > 0 then
                    table.insert(list, {
                        spellName   = entry.spellName,
                        spawnID     = petID,
                        label       = "pet",
                        refreshTime = entry.refreshTime or 0,
                    })
                end
            elseif target == "group" then
                local n = mq.TLO.Group.Members() or 0
                for i = 1, n do
                    local m = mq.TLO.Group.Member(i)
                    -- exclude self to avoid double-buffing when "self" is also listed
                    if m() and m.ID() ~= mq.TLO.Me.ID() then
                        table.insert(list, {
                            spellName   = entry.spellName,
                            spawnID     = m.ID(),
                            label       = m.Name() or ("member" .. i),
                            refreshTime = entry.refreshTime or 0,
                        })
                    end
                    if m.Pet and m.Pet.ID() and m.Pet.ID() > 0 then
                        table.insert(list, {
                            spellName   = entry.spellName,
                            spawnID     = m.Pet.ID(),
                            label       = (m.Name() or ("member" .. i)) .. "'s pet",
                            refreshTime = entry.refreshTime or 0,
                        })
                    end
                end
            else
                -- specific name
                local s = mq.TLO.Spawn("pc = " .. target)
                if s and s() then
                    table.insert(list, {
                        spellName   = entry.spellName,
                        spawnID     = s.ID(),
                        label       = target,
                        refreshTime = entry.refreshTime or 0,
                    })
                end
            end
        end
    end
    return list
end
function buff.ensureQueueExists(buffConfig)
    return bt.Leaf("GenerateBuffQueue", function()
        local q = bb.get(bbBuffQueueKey)
        
        -- If q is nil, the cycle is starting fresh.
        if q == nil then
            bb.set(bbBuffQueueKey, buildWorkList(buffConfig))
            return bt.RUNNING, "Generated new buff queue"
        end
        
        -- If q exists (even if it currently has 0 items), proceed.
        return bt.SUCCESS, "Queue exists"
    end)
end


function buff.peekNext()
    return bt.Leaf("PeekNextBuff", function()
        local q = bb.get(bbBuffQueueKey)
        
        -- THIS IS THE EXIT: If the queue is empty, the cycle is OVER.
        if q and #q == 0 then
            -- Destroy the queue so it regenerates on the NEXT cooldown cycle
            bb.set(bbBuffQueueKey, nil) 
            -- Return FAILURE to cleanly break the Sequence and reset your Cooldown timer
            return bt.FAILURE, "Buff cycle complete" 
        end
        
        if not q then return bt.FAILURE, "No queue" end
        
        local item = q[1]
        bb.set(bbBuffTargetIDKey, item.spawnID)
        bb.set(bbBuffSpellNameKey, item.spellName)
        bb.set(bbBuffTargetLabelKey, item.label)
        bb.set(bbBuffRefreshTimeKey, item.refreshTime or 0)
        
        return bt.SUCCESS, "Peeking " .. item.spellName .. " for " .. item.label
    end)
end
function buff.popQueue()
    return bt.Leaf("PopBuffQueue", function()
        local q = bb.get(bbBuffQueueKey)
        if q and #q > 0 then
            table.remove(q, 1)
            bb.set(bbBuffQueueKey, q)
        end
        return bt.RUNNING, "Item popped, moving to next buff if queue not empty"
    end)
end

function buff.targetBuffOverThreshold()
    return bt.Leaf("HasBuff", function()
        local label = bb.get(bbBuffTargetLabelKey)
        local spellName = bb.get(bbBuffSpellNameKey)
        local refreshTime = bb.get(bbBuffRefreshTimeKey)
        local targetId = bb.get(bbBuffTargetIDKey)

        local target = mq.TLO.Target
        if target.ID() ~= targetId then -- somehow the target was lost between ticks
            return bt.FAILURE, "Buff target not acquired"
        end

        local timeLeft = (target and
            target.Buff(spellName) and
            target.Buff(spellName).Duration.TotalSeconds and
            target.Buff(spellName).Duration.TotalSeconds()) or 0
        if timeLeft >= refreshTime then
            return bt.SUCCESS, "Buff is good"
        end
        return bt.FAILURE, "Buff missing or below refresh threshold"
    end)
end

function buff.isBuffNeededOntarget()
    return bt.Sequence("IsBuffNeededOnTarget", {
        spell.stacksOnTarget(bbBuffSpellNameKey),
        bt.Inverter('Under Threshold', buff.targetBuffOverThreshold()),
    })
end

--- COMPOSITE: The universal buffing sequence.
---@param buffConfig table The class-specific table of buffs to maintain
function buff.MaintainGroupBuffs(buffConfig)
    return bt.Sequence("Group_Buff_Cycle", {
        buff.ensureQueueExists(buffConfig),
        buff.peekNext(),
        bt.AlwaysSucceed("Try_Process_Buff",
            bt.MemSequence("Target_Check_Cast", {
                target.targetIdAndSync(bbBuffTargetIDKey),
                buff.isBuffNeededOntarget(),
                spell.castSpell(bbBuffSpellNameKey)
            })
        ),
        buff.popQueue(),
    })
end

return buff