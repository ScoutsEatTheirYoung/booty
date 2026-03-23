local mq            = require('mq')
local spellUtils    = require('booty.bot.bricks.spellUtils')
local spellActions  = require('booty.bot.bricks.spellActions')
local targetActions = require('booty.bot.bricks.targetActions')
local groupUtils    = require('booty.bot.bricks.groupUtils')

local healActions = {}

--- Heal the first group member (leader priority, then group, then self) below threshold.
--- Uses emergency threshold when group is engaged, normal threshold otherwise.
--- One step per tick: mem → target → cast.
---@param healName string
---@param healGem integer
---@param healPct number        heal threshold out of combat
---@param emergencyPct number   heal threshold in combat
---@param leaderID integer      spawn ID of the leader — healed first
---@return boolean, string
function healActions.healGroup(healName, healGem, healPct, emergencyPct, leaderID)
    if not healName or healName == "" then return false, "No heal configured" end

    if not spellUtils.isOnBar(healName) then
        return spellActions.memorizeSpell(healGem, healName)
    end

    -- Don't consume the tick if spell is on cooldown — let combat proceed
    if not spellUtils.isSpellReady(healName) then return false, "Heal not ready" end

    local threshold = groupUtils.isGroupEngaged() and emergencyPct or healPct

    local function tryHeal(spawn)
        if not spawn or not spawn() then return false, "" end
        if (spawn.PctHPs() or 100) >= threshold then return false, "" end
        local name = spawn.Name() or '?'
        local c = targetActions.targetSpawn(spawn)
        if c then return true, string.format("Targeting %s to heal", name) end
        c = spellActions.castSpellInGem(healName, healGem)
        if c then return true, string.format("Healing %s (%d%%)", name, spawn.PctHPs() or 0) end
        return false, ""
    end

    -- Leader first
    local c, r = tryHeal(mq.TLO.Spawn(leaderID))
    if c then return c, r end

    -- Group members
    local count = mq.TLO.Group.Members() or 0
    for i = 1, count do
        local m = mq.TLO.Group.Member(i)
        if m and m.Name() and m.Name() ~= mq.TLO.Me.Name() then
            c, r = tryHeal(m.Spawn)
            if c then return c, r end
        end
    end

    -- Self last
    c, r = tryHeal(mq.TLO.Me)
    if c then return c, r end

    return false, "No heal needed"
end

return healActions
