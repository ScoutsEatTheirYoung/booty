local Action = require('booty.bot.bt.core.action')
local State  = require('booty.bot.bt.core.state')
local mq     = require('mq')

local nav = {}


function nav.toLeader()
    local function execute(_, context)
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

    local function OnExit()
        if mq.TLO.Navigation.Active() then
            mq.cmd('/squelch /nav stop')
        end
    end

    return Action:new("[A]_Nav_To_Leader", { execute = execute, onExit = OnExit })
end

return nav
