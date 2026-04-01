local Leaf  = require('booty.bot.bt.core.leaf')
local State = require('booty.bot.bt.core.state')
local mq    = require('mq')

local buff = {}

-- Returns the gem slot (1-12) that spellName is memmed in, or nil.
local function findGem(spellName)
    for i = 1, 12 do
        local gem = mq.TLO.Me.Gem(i)
        if gem() and gem.Name() == spellName then return i end
    end
    return nil
end

-- Returns true when spawnID needs spellName cast on them.
-- Duration() returns ticks (1 tick = 6 sec). refreshTime is in seconds.
local function needsBuff(spawnID, spellName, refreshTime)
    local s = mq.TLO.Spawn(spawnID)
    if not s() then return false end
    local b = s.Buff(spellName)
    if not b() then return true end
    return (b.Duration() * 6) < refreshTime
end

-- Expands the buff config into a flat list of { spawnID, spellName, label, refreshTime }.
-- Rebuilt each tick so group changes (joins, leaves, pets) are reflected immediately.
--
-- "self"  → your character
-- "pet"   → your pet
-- "group" → each other group member (PC) + their pet
local function buildWorkList(buffs)
    local list = {}
    for _, entry in ipairs(buffs) do
        for _, target in ipairs(entry.targets or {}) do
            local spellName   = entry.spellName
            local refreshTime = entry.refreshTime or 0

            if target == "self" then
                table.insert(list, {
                    spellName = spellName, refreshTime = refreshTime,
                    spawnID   = mq.TLO.Me.ID(),
                    label     = "self",
                })

            elseif target == "pet" then
                local petID = mq.TLO.Me.Pet.ID()
                if petID and petID > 0 then
                    table.insert(list, {
                        spellName = spellName, refreshTime = refreshTime,
                        spawnID   = petID,
                        label     = "my pet",
                    })
                end

            elseif target == "group" then
                local n = mq.TLO.Group.Members() or 0
                for i = 1, n do
                    local m = mq.TLO.Group.Member(i)
                    if m() then
                        local memberName = m.Name() or ("member" .. i)
                        table.insert(list, {
                            spellName = spellName, refreshTime = refreshTime,
                            spawnID   = m.ID(),
                            label     = memberName,
                        })
                        -- Get their pet via spawn lookup (groupmember has no .Pet field)
                        local ms = mq.TLO.Spawn('pc =' .. memberName)
                        if ms() then
                            local petID = ms.Pet.ID()
                            if petID and petID > 0 then
                                table.insert(list, {
                                    spellName = spellName, refreshTime = refreshTime,
                                    spawnID   = petID,
                                    label     = memberName .. "'s pet",
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    return list
end

function buff.ensureQueueExists()
    return Leaf:new("EnsureBuffQueueExists", function(_, context)
        if context.buff.queue == nil then
            context.buff.queue = buildWorkList(context.buff.list)
            return State.SUCCESS, "Buff queue initialized with " .. #context.buff.queue .. " entries"
        elseif #context.buff.queue >= 0 then
            return State.SUCCESS, "Buff queue already exists with " .. #context.buff.queue .. " entries"
        end
        return State.FAILURE, "Buff queue doesn't exist and config is empty, nothing to do"
    end)
end

function buff.peakBuffQueue()
    return Leaf:new("PeakBuffQueue", function(_, context)
        local queue = context.buff.queue
        if #queue > 0 then
            local nextBuff = queue[1]
            return State.SUCCESS, "Next buff: " .. nextBuff.spellName .. " on " .. nextBuff.label
        end
        return State.FAILURE, "Buff queue is empty"
    end)
end

-- Returns a leaf that keeps all buffs in the list active.
--
-- Each tick:
--   1. If currently casting → RUNNING (wait for it to land)
--   2. Scan work list for the first (spell, target) that needs a buff AND is ready to cast
--   3. If target not selected → issue /tar, RUNNING
--   4. If target selected → issue /cast, RUNNING
--   5. All buffs satisfied → FAILURE (caller's Selector falls through to next branch)
--
-- FAILURE is the "nothing to do" signal, not an error. The caller decides what to do next.
---@param buffs {spellName:string, refreshTime:number, targets:string[]}[]
---@return Leaf
function buff.keepUp(buffs)
    return Leaf:new("BuffKeepUp", function()
        -- Phase 1: wait for any in-progress cast
        if mq.TLO.Me.Casting() then
            return State.RUNNING, "Casting " .. (mq.TLO.Me.Casting() or "spell")
        end

        -- Phase 2: scan for the first buff that needs casting and is ready
        local workList = buildWorkList(buffs)
        for _, item in ipairs(workList) do
            if needsBuff(item.spawnID, item.spellName, item.refreshTime) then
                local gem = findGem(item.spellName)
                -- Skip if spell not memmed or gem is on cooldown
                if gem and mq.TLO.Me.SpellReady(gem)() then
                    if mq.TLO.Target.ID() ~= item.spawnID then
                        mq.cmdf('/tar id %d', item.spawnID)
                        return State.RUNNING, "Targeting " .. item.label
                    end
                    mq.cmdf('/cast %d', gem)
                    return State.RUNNING, "Casting " .. item.spellName .. " on " .. item.label
                end
            end
        end

        return State.FAILURE, "All buffs up"
    end)
end

return buff
