local Node = require('booty.bot.bt.core.node')
local State = require('booty.bot.bt.core.state')
local mq = require('mq')

local NavToLeader = setmetatable({}, { __index = Node })
NavToLeader.__index = NavToLeader

function NavToLeader:new(name)
    return Node.new(self, name or "NavToLeader")
end

function NavToLeader:execute(context)
    if not context.leaderName then return State.FAILURE end

    local leader = mq.TLO.Spawn('pc =' .. context.leaderName)

    -- If leader is not in zone, we can't navigate to them
    if not leader() then
        return State.FAILURE
    end

    -- Check if we arrived (within 30 units)
    if leader.Distance3D() < 30 then
        if mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
        end
        return State.SUCCESS
    end

    -- If we aren't close, and aren't moving, start moving
    if not mq.TLO.Navigation.Active() then
        mq.cmdf('/squelch /nav spawn %s', context.leaderName)
    end

    -- Hold the tree here while we run
    return State.RUNNING
end

-- The Engine Guarantee: If the tree is hijacked by an emergency, or we succeed/fail,
-- the engine automatically fires this cleanup block.
function NavToLeader:onExit()
    if mq.TLO.Navigation.Active() then
        mq.cmd('/squelch /nav stop')
    end
end

return NavToLeader