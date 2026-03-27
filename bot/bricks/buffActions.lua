local targetActions = require('booty.bot.bricks.targetActions')
local spellActions  = require('booty.bot.bricks.spellActions')
local buffUtils     = require('booty.bot.bricks.buffUtils')
local targetUtils   = require('booty.bot.bricks.targetUtils')

local buffActions = {}

-- Cursor across the unique-spawn queue. Persists between ticks so we don't
-- re-target spawn[1] every tick while cycling through the group.
local _cursorIdx  = 1
local _cycleCount = 0   -- how many spawns fully checked this cycle

-- ============================================================
-- Private helpers
-- ============================================================

--- Build an ordered, deduplicated list of all target spawns across the buff list.
---@param buffList BuffEntry[]
---@return {spawn: MQSpawn, label: string}[]
local function buildSpawnQueue(buffList)
    local seen  = {}
    local queue = {}
    for _, entry in ipairs(buffList) do
        local resolved = targetUtils.resolveTargets(entry.targets or {})
        for _, t in ipairs(resolved) do
            if t.spawn and t.spawn() then
                local id = t.spawn.ID()
                if not seen[id] then
                    seen[id] = true
                    table.insert(queue, { spawn = t.spawn, label = t.label })
                end
            end
        end
    end
    return queue
end

--- Find the first buff entry that applies to spawn and that spawn currently needs.
--- Only call this after spawn is targeted and BuffsPopulated.
---@param spawn MQSpawn|MQTarget
---@param buffList BuffEntry[]
---@return {spellName: string, label: string}|nil
local function findNeededBuffForSpawn(spawn, buffList)
    if not spawn or not spawn() then return nil end
    local spawnID = spawn.ID()
    for _, entry in ipairs(buffList) do
        local resolved = targetUtils.resolveTargets(entry.targets or {})
        for _, t in ipairs(resolved) do
            if t.spawn and t.spawn() and t.spawn.ID() == spawnID then
                if buffUtils.spawnNeedsBuff(spawn, entry.spellName, entry.refreshTime or 0) then
                    return { spellName = entry.spellName, label = t.label }
                end
            end
        end
    end
    return nil
end

--- Mem spellName into spellGem if needed, then cast on current target.
---@param spellName string
---@param spellGem integer
---@param label string
---@return boolean, string
local function castOnCurrentTarget(spellName, spellGem, label)
    local c, r = spellActions.castSpellInGem(spellName, spellGem)
    if c then return true, string.format("Buffing %s: %s", label, r) end
    return false, r
end

-- ============================================================
-- Actors  (cast*)
-- ============================================================

--- Cycle through buffList and cast any needed buffs. One action per tick.
---
--- Each tick:
---   1. Guard any in-progress cast.
---   2. Target the spawn at the cursor position; wait for BuffsPopulated.
---   3. Check all buff entries that apply to that spawn.
---   4. Cast the first needed buff, or advance the cursor if all are current.
---   5. When all spawns have been checked with nothing needed, return false.
---
--- buffList entry format:
---   { spellName = "Spirit of Wolf", refreshTime = 300, targets = {"group"} }
---
---@param buffList BuffEntry[]
---@param spellGem integer  Gem slot to use when the spell needs to be memorized
---@return boolean, string
function buffActions.castBuffList(buffList, spellGem)
    if not buffList or #buffList == 0 then return false, 'Buff list empty' end
    if not spellGem or spellGem <= 0 then return false, 'Invalid gem slot' end

    local c, r = spellActions.guardCasting(nil)
    if c then return c, r end

    local queue = buildSpawnQueue(buffList)
    if #queue == 0 then return false, 'No buff targets' end

    -- Clamp cursor if queue shrank (group member left, etc.)
    if _cursorIdx > #queue then
        _cursorIdx  = 1
        _cycleCount = 0
    end

    -- Full cycle complete — everyone checked, nothing needed
    if _cycleCount >= #queue then
        _cursorIdx  = 1
        _cycleCount = 0
        return false, 'All buffs current'
    end

    local current = queue[_cursorIdx]

    -- Target this spawn and wait for buff data to populate
    c, r = targetActions.targetSpawn(current.spawn)
    if c then return c, r end

    -- Targeted and populated — check all buff entries that apply to this spawn
    local needed = findNeededBuffForSpawn(current.spawn, buffList)
    if needed then
        return castOnCurrentTarget(needed.spellName, spellGem, needed.label)
    end

    -- This spawn is fully buffed — advance the cursor (no tick consumed)
    _cursorIdx  = (_cursorIdx % #queue) + 1
    _cycleCount = _cycleCount + 1
    return false, string.format('%s buffs current', current.label)
end

return buffActions
