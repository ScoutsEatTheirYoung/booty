local Node  = require('booty.bot.bt.core.node')
local State = require('booty.bot.bt.core.state')
local mq    = require('mq')

-- NavToLeader is a stateful Node subclass (not a plain Action leaf) because it
-- needs onExit to stop navigation when the tree moves on or aborts.

---@class NavToLeader : Node
local NavToLeader = {}
setmetatable(NavToLeader, { __index = Node })
NavToLeader.__index = NavToLeader

---@param name? string
---@return NavToLeader
function NavToLeader:new(name)
    return Node.new(self, name or "[A]_Nav_To_Leader") --[[@as NavToLeader]]
end

function NavToLeader:execute(context)
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

function NavToLeader:onExit()
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
end

return NavToLeader
