local mq = require('mq')
local bt = require('booty.bot.bt.engine')

local group = {}

--------------------------------------------------------------------------------
--- Sensors
function group.isGroupEngaged()
    return mq.TLO.Me.XTarget(1)() ~= nil
end

--- SUCCESS if in a group.
function group.inGroup()
    return function()
        if mq.TLO.Me.Grouped() then
            return bt.SUCCESS, "In group", "inGroup"
        end
        return bt.FAILURE, "Not in group", "inGroup"
    end
end

--- SUCCESS if NOT in a group.
function group.notInGroup()
    return function()
        if not mq.TLO.Me.Grouped() then
            return bt.SUCCESS, "Not in group", "notInGroup"
        end
        return bt.FAILURE, "Already in group", "notInGroup"
    end
end

--- SUCCESS if there is a pending group invite.
function group.hasPendingInvite()
    return function()
        if mq.TLO.Me.Invited() then
            return bt.SUCCESS, "Invite from " .. mq.TLO.Me.Invited(), "hasPendingInvite"
        end
        return bt.FAILURE, "No pending invite", "hasPendingInvite"
    end
end

--- Accept a pending group invite. FAILURE if none pending.
function group.acceptInvite()
    return function()
        if not mq.TLO.Me.Invited() then
            return bt.FAILURE, "No invite to accept", "acceptInvite"
        end
        mq.cmd('/invite')
        return bt.SUCCESS, "Accepted invite", "acceptInvite"
    end
end

return group
