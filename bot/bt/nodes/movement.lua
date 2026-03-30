local mq = require('mq')
local bt = require('booty.bot.bt.engine')
local BB = require('booty.bot.bt.blackboard')

local movement = {}

--- Navigate to a fixed world point. RUNNING until nav completes.
---@param x number
---@param y number
---@param z number
function movement.navToPoint(x, y, z)
    return bt.Leaf("navToPoint", function()
        if mq.TLO.Navigation.Active() then
            return bt.RUNNING, "Navigating to point", "navToPoint"
        end
        mq.cmdf('/squelch /nav locxyz %d %d %d', x, y, z)
        return bt.RUNNING, "Starting navigation to point", "navToPoint"
    end)
end

--- Stop any active navigation. Always succeeds.
function movement.stopNav()
    return bt.Leaf("stopNav", function()
        if mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
        end
        return bt.SUCCESS, "Nav stopped", "stopNav"
    end)
end

function movement.goToLeader()
    return bt.Leaf("goToLeader", function()
        local leaderName = BB.get("leaderName")
        if not leaderName then
            return bt.FAILURE, "No leader name set"
        end

        local leaderSpawn = mq.TLO.Spawn(leaderName)
        if not leaderSpawn() then
            return bt.FAILURE, "Leader not found"
        end

        local followDist = BB.get("followDist") or 10
        if leaderSpawn.Distance() <= followDist then
            return bt.SUCCESS, "Close to leader"
        end

        mq.cmdf('/squelch /nav locxyz %d %d %d', leaderSpawn.X(), leaderSpawn.Y(), leaderSpawn.Z())
        return bt.RUNNING, "Navigating to leader"
    end)
end

--- Follow the leader from the blackboard. SUCCESS when within followDist.
--- Continuously updates nav destination as leader moves.
function movement.followLeader()
    local x, y, z = 0, 0, 0
    return bt.Leaf("followLeader", function()
        local leaderName = BB.get("leaderName")
        if not leaderName then
            return bt.FAILURE, "No leader name set"
        end

        local leaderSpawn = mq.TLO.Spawn(leaderName)
        if not leaderSpawn() then
            return bt.FAILURE, "Leader not found"
        end

        local followDist = BB.get("followDist") or 10
        if leaderSpawn.Distance() <= followDist then
            mq.cmd('/squelch /nav stop')
            return bt.SUCCESS, "Close to leader"
        end

        if mq.TLO.Navigation.Active() then
            local drift = math.sqrt(
                (leaderSpawn.X() - x)^2 +
                (leaderSpawn.Y() - y)^2 +
                (leaderSpawn.Z() - z)^2
            )
            if drift > followDist / 2 then
                x, y, z = leaderSpawn.X(), leaderSpawn.Y(), leaderSpawn.Z()
                mq.cmdf('/squelch /nav locxyz %d %d %d', x, y, z)
            end
            return bt.RUNNING, "Navigating to leader"
        end

        x, y, z = leaderSpawn.X(), leaderSpawn.Y(), leaderSpawn.Z()
        mq.cmdf('/squelch /nav locxyz %d %d %d', x, y, z)
        return bt.RUNNING, "Starting navigation to leader"
    end)
end

return movement
