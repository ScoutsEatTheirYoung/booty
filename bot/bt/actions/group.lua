local Action = require('booty.bot.bt.core.action')
local State  = require('booty.bot.bt.core.state')
local mq     = require('mq')

local group = {}

function group.acceptInviteFromLeader()
    local function execute(_, context)
        local inviter    = context.group.lastInviteFrom
        local leaderName = context.leaderName
        if not leaderName then return State.FAILURE, "No leader name" end
        if not inviter    then return State.FAILURE, "No invite recorded" end

        if inviter:lower() == leaderName:lower() then
            mq.cmd('/invite')
            return State.RUNNING, "Clicked accept, waiting for server sync..."
        end

        return State.FAILURE, "Pending invite is not from leader"
    end

    return Action:new("[A]_Accept_Invite_From_Leader", { execute = execute })
end

function group.dexLeaderForInvite()
    local function execute(_, context)
        if not context.leaderName then
            return State.FAILURE, "No leader name"
        end

        mq.cmdf('/dex %s /invite %s', context.leaderName, mq.TLO.Me.Name())
        return State.SUCCESS, "Sent invite request to " .. context.leaderName
    end

    return Action:new("[A]_Dex_Leader_For_Invite", { execute = execute })
end

return group
