local mq  = require('mq')
local bit = require('bit')

local groupUtils = {}

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

--- True if the given PC has their weapons drawn aggressively (PlayerState bits 4 or 8).
---@param spawnID integer
---@return boolean
function groupUtils.isPCEngaged(spawnID)
    local pc = mq.TLO.Spawn(spawnID)
    if not pc() then return false end
    return bit.band(pc.PlayerState() or 0, 12) ~= 0
end

--- True if any mob is actively targeting a group member (via extended target list).
---@return boolean
function groupUtils.isGroupEngaged()
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and (xt.ID() or 0) > 0 then return true end
    end
    return false
end

--- Return the first live NPC spawn from the XTarget list, or nil.
---@return MQSpawn|nil
function groupUtils.getEngagedTarget()
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and (xt.ID() or 0) > 0 then
            local spawn = mq.TLO.Spawn(xt.ID())
            if spawn() and spawn.Type() == "NPC" and (spawn.PctHPs() or 0) > 0 then
                return spawn
            end
        end
    end
    return nil
end

---@return boolean
function groupUtils.isGrouped()
    return mq.TLO.Me.Grouped() == true
end

---@return boolean
function groupUtils.hasPendingInvite()
    return mq.TLO.Me.Invited() == true
end

--- Return the lowest HP% across all group members (not self).
---@return number
function groupUtils.minGroupHp()
    local min = 100
    local count = mq.TLO.Group.Members() or 0
    for i = 1, count do
        local m = mq.TLO.Group.Member(i)
        if m then min = math.min(min, m.PctHPs() or 100) end
    end
    return min
end

--- True if any currently-engaged NPC is within radius of campPoint.
---@param campPoint Point
---@param radius number
---@return boolean
function groupUtils.isEngagementNearPoint(campPoint, radius)
    if not campPoint then return false end
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and (xt.ID() or 0) > 0 then
            local spawn = mq.TLO.Spawn(xt.ID())
            if spawn() and spawn.Type() == "NPC" and (spawn.PctHPs() or 0) > 0 then
                local dx = spawn.X() - (campPoint.x or 0)
                local dy = spawn.Y() - (campPoint.y or 0)
                if math.sqrt(dx * dx + dy * dy) <= radius then
                    return true
                end
            end
        end
    end
    return false
end

--- True when the camp should go active:
---   - Any mob is engaged but the leader is NOT (mob reached camp from elsewhere), OR
---   - The leader is engaged and the mob is within pullRadius of campPoint.
---@param leaderID integer
---@param campPoint Point|nil
---@param pullRadius number
---@return boolean
function groupUtils.isCampEngaged(leaderID, campPoint, pullRadius)
    if not groupUtils.isGroupEngaged() then return false end
    -- Non-leader engagement: defend camp regardless of pull range
    if not groupUtils.isPCEngaged(leaderID) then return true end
    -- Leader is engaged: only engage if the pull has reached camp
    return groupUtils.isEngagementNearPoint(campPoint, pullRadius)
end

return groupUtils
