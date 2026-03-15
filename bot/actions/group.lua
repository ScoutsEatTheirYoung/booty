local mq = require('mq')

local groupActs = {}

groupActs.lastInviteRequestTime = 0

function groupActs.runToLeaderAndRequest(leaderName, offset, inviteCooldown, initCloseDist)

        -- Pending invite — accept it
        if mq.TLO.Me.Invited() then
            mq.cmd('/invite')
            return
        end

        local leader = mq.TLO.Spawn('pc =' .. leaderName)
        if not leader() then return end  -- Leader not in zone, wait

        -- Navigate toward leader if too far
        if leader.Distance() > initCloseDist then
            if not mq.TLO.Navigation.Active() then
                mq.cmd(string.format('/squelch /nav id %d distance=%d', leader.ID(), initCloseDist - 2))
            end
            return
        end

        -- Close enough — ask leader to invite us (throttled)
        local now = os.clock()
        if (now - groupActs.lastInviteRequestTime) >= inviteCooldown then
            groupActs.lastInviteRequestTime = now
            mq.cmd(string.format('/dex %s /invite %s', leaderName, mq.TLO.Me.Name()))
        end
    end

return groupActs