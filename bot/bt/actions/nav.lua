local Node  = require('booty.bot.bt.core.node')
local State = require('booty.bot.bt.core.state')
local mq    = require('mq')

-- Internal stateful Node subclass. Needs onExit to guarantee /nav stop fires
-- whenever the tree moves on, succeeds, fails, or is aborted.
---@class NavToLeaderNode : Node
local NavToLeaderNode = {}
setmetatable(NavToLeaderNode, { __index = Node })
NavToLeaderNode.__index = NavToLeaderNode

function NavToLeaderNode:new(name)
    return Node.new(self, name) --[[@as NavToLeaderNode]]
end

function NavToLeaderNode:execute(context)
    if not context.leaderName then return State.FAILURE, "No leader name" end

    local leader = mq.TLO.Spawn('pc =' .. context.leaderName)
    if not leader() then
        return State.FAILURE, "Leader not in zone"
    end

    if leader.Distance3D() < 30 then
        if mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
        end
        return State.SUCCESS, "Arrived at leader"
    end

    if not mq.TLO.Navigation.Active() then
        mq.cmdf('/squelch /nav spawn %s', context.leaderName)
    end

    return State.RUNNING, "Navigating to " .. context.leaderName
end

function NavToLeaderNode:onExit()
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
end

-- Public API
local nav = {}

function nav.toLeader()
    return NavToLeaderNode:new("[A]_Nav_To_Leader")
end

return nav
