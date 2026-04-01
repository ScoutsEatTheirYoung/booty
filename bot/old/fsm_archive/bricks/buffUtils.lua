local buffUtils = {}

-- ============================================================
-- Pure checks
-- ============================================================

--- True if spawn needs the buff (missing or expires within refreshTime seconds).
--- Only reliable after the spawn is the current target and BuffsPopulated is true.
---@param spawn MQSpawn|MQTarget
---@param spellName string
---@param refreshTime number  seconds before expiry to consider a refresh needed
---@return boolean
function buffUtils.spawnNeedsBuff(spawn, spellName, refreshTime)
    if not spawn or not spawn() then return false end
    local b = spawn.Buff(spellName)
    if not b() then return true end
    local timeLeft = (b.Duration and b.Duration.TotalSeconds and b.Duration.TotalSeconds()) or 0
    return timeLeft < refreshTime
end

return buffUtils
