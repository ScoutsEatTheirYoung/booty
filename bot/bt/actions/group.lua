local Action = require('booty.bot.bt.core.action')
local State  = require('booty.bot.bt.core.state')
local mq     = require('mq')

local group = {}

function group.acceptInviteFromLeader()
    return Action:new("[A]_Accept_Invite_From_Leader", function(_, context)
        local inviter    = context.group.lastInviteFrom
        local leaderName = context.leaderName
        if not leaderName then return State.FAILURE, "No leader name" end
        if not inviter    then return State.FAILURE, "No invite recorded" end

        if inviter:lower() == leaderName:lower() then
            mq.cmd('/invite')
            return State.RUNNING, "Clicked accept, waiting for server sync..."
        end

        return State.FAILURE, "Pending invite is not from leader"
    end)
end

function group.dexLeaderForInvite()
    return Action:new("[A]_Dex_Leader_For_Invite", function(_, context)
        if not context.leaderName then
            return State.FAILURE, "No leader name"
        end

        mq.cmdf('/dex %s /invite %s', context.leaderName, mq.TLO.Me.Name())
        return State.SUCCESS, "Sent invite request to " .. context.leaderName
    end)
end

return group
