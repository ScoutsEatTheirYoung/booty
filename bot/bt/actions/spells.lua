local Action = require('booty.bot.bt.core.action')
local Sensor = require('booty.bot.bt.core.sensor')
local State  = require('booty.bot.bt.core.state')
local mq     = require('mq')

local spells = {}

-- Returns the gem slot (1-12) that spellName is memmed in, or nil.
local function findGem(spellName)
    for i = 1, mq.TLO.Me.NumGems() do
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

-- Expands context.buff.list into a flat list of { spawnID, spellName, label, refreshTime }.
-- Rebuilt each tick so group roster changes are reflected immediately.
--
-- "self"  → your character
-- "pet"   → your pet
-- "group" → each other group member (PC) + their pet
local function buildWorkList(buffList)
    local list = {}
    for _, entry in ipairs(buffList) do
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

-- Scans context.buff.list each tick and casts the first buff that is missing or
-- expiring. Returns RUNNING while targeting or casting, FAILURE when all buffs
-- are satisfied (lets the Selector fall through to the next branch).
function spells.keepUp()
    local function execute(_, context)
        if mq.TLO.Me.Casting() then
            return State.RUNNING, "Casting " .. (mq.TLO.Me.Casting() or "spell")
        end

        local buffList = context.buff and context.buff.list
        if not buffList then return State.FAILURE, "No buff list in context" end

        local workList = buildWorkList(buffList)
        for _, item in ipairs(workList) do
            if needsBuff(item.spawnID, item.spellName, item.refreshTime) then
                local gem = findGem(item.spellName)
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
    end

    return Action:new("[A]_Buff_Keep_Up", { execute = execute })
end

-- Peeks at the front of context.buff.queue without consuming it.
function spells.peekBuffQueue()
    local function evaluate(_, context)
        local queue = context.buff and context.buff.queue
        if not queue or #queue == 0 then
            return State.FAILURE, "Buff queue is empty"
        end
        local next = queue[1]
        return State.SUCCESS, "Next buff: " .. next.spellName .. " on " .. next.label
    end

    return Sensor:new("[S]_Peek_Buff_Queue", evaluate)
end

-- Initializes context.buff.queue from context.buff.list if it doesn't exist yet.
function spells.ensureQueueExists()
    local function execute(_, context)
        if not context.buff or not context.buff.list then
            return State.FAILURE, "No buff list in context"
        end
        if context.buff.queue == nil then
            context.buff.queue = buildWorkList(context.buff.list)
            return State.SUCCESS, "Buff queue initialized (" .. #context.buff.queue .. " entries)"
        end
        return State.SUCCESS, "Buff queue already exists (" .. #context.buff.queue .. " entries)"
    end

    return Action:new("[A]_Ensure_Buff_Queue_Exists", { execute = execute })
end

return spells
