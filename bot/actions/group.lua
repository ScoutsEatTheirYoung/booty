local mq = require('mq')

local group = {}

local lastInviteRequestTime = 0

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

function group.isGrouped()
    return mq.TLO.Me.Grouped() == true
end

function group.hasPendingInvite()
    return mq.TLO.Me.Invited() ~= nil
end

-- ============================================================
-- Actors  (nav* / do*)
-- ============================================================

-- Full invite flow: run to leader, request invite via /dex, accept when it arrives.
-- Call every tick from INIT state. Returns true, reason on any action taken.
function group.navGroupInvite(leaderName, inviteCooldown, closeDistance)
    -- Accept pending invite
    if group.hasPendingInvite() then
        mq.cmd('/invite')
        return true, 'Accepting group invite'
    end

    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return false end

    -- Navigate toward leader if too far
    if leader.Distance() > closeDistance then
        if not mq.TLO.Navigation.Active() then
            mq.cmdf('/squelch /nav id %d distance=%d', leader.ID(), closeDistance - 2)
        end
        return true, string.format('Running to %s (%.0f units)', leaderName, leader.Distance())
    end

    -- Close enough — request invite on cooldown
    local now = os.clock()
    if (now - lastInviteRequestTime) >= inviteCooldown then
        lastInviteRequestTime = now
        mq.cmdf('/dex %s /invite %s', leaderName, mq.TLO.Me.Name())
        return true, string.format('Requesting invite from %s', leaderName)
    end

    return false
end

-- Reset invite cooldown (call from INIT state onEnter).
function group.resetInviteTimer()
    lastInviteRequestTime = 0
end

return group
