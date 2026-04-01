local Leaf = require('booty.bot.bt.core.leaf')
local State = require('booty.bot.bt.core.state')
local mq = require('mq')

local setup = {}

function setup.acceptInviteFromLeader()
    return Leaf:new("AcceptInviteFromLeader", function(_, context)
        local inviter = context.group.lastInviteFrom
        local leaderName = context.leaderName
        print(string.format("Checking invite: inviter=%s, leader=%s", inviter, leaderName))
        if not leaderName then return State.FAILURE, "No leader name" end
        if not inviter then return State.FAILURE, "No invite recorded" end

        if inviter:lower() == leaderName:lower() then
            mq.cmd('/invite')
            return State.RUNNING, "Clicked accept, waiting for server sync..."
        end

        return State.FAILURE, "Pending invite is not from leader"
    end)
end

function setup.dexLeaderForInvite()
    return Leaf:new("DexLeaderForInvite", function(_, context)
        if not context.leaderName then 
            return State.FAILURE 
        end
        
        mq.cmdf('/dex %s /invite %s', context.leaderName, mq.TLO.Me.Name())
        return State.SUCCESS
    end)
end

return setup