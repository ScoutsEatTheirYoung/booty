local mq = require('mq')
local bt = require('booty.bot.bt.engine')
local BB = require('booty.bot.bt.blackboard')

local combat = {}

--- SUCCESS if current target is a live NPC.
function combat.hasLiveTarget()
    return bt.Leaf("hasLiveTarget", function()
        local t = mq.TLO.Target
        if t() and t.Type() == "NPC" and not t.Dead() then
            return bt.SUCCESS, "Have live target"
        end
        return bt.FAILURE, "No live target"
    end)
end

--- SUCCESS if currently in combat.
function combat.isInCombat()
    return bt.Leaf("isInCombat", function()
        if mq.TLO.Me.Combat() then
            return bt.SUCCESS, "In combat"
        end
        return bt.FAILURE, "Not in combat"
    end)
end

--- Target the leader's current target. SUCCESS when already on it.
function combat.assistLeader()
    return bt.Leaf("assistLeader", function()
        local leaderName = BB.get("leaderName")
        if not leaderName then
            return bt.FAILURE, "No leader set"
        end

        local leader = mq.TLO.Spawn(leaderName)
        if not leader() then
            return bt.FAILURE, "Leader not found"
        end

        local leaderTarget = leader.TargetOfTarget
        if not leaderTarget() then
            return bt.FAILURE, "Leader has no target"
        end
        if leaderTarget.Type() ~= "NPC" or leaderTarget.Dead() then
            return bt.FAILURE, "Leader target is not a live NPC"
        end

        if mq.TLO.Target.ID() == leaderTarget.ID() then
            return bt.SUCCESS, "Assisting " .. (leaderTarget.Name() or "target")
        end

        mq.cmdf('/squelch /tar id %d', leaderTarget.ID())
        return bt.RUNNING, "Targeting leader's target"
    end)
end

--- Turn attack on. SUCCESS when already in combat.
function combat.attack()
    return bt.Leaf("attack", function()
        if not mq.TLO.Target() then
            return bt.FAILURE, "No target"
        end
        if mq.TLO.Me.Combat() then
            return bt.SUCCESS, "Attacking"
        end
        mq.cmd('/attack on')
        return bt.RUNNING, "Starting attack"
    end)
end

--- Turn attack off and stand down. Always succeeds.
function combat.disengage()
    return bt.Leaf("disengage", function()
        mq.cmd('/attack off')
        return bt.SUCCESS, "Disengaged"
    end)
end

return combat
