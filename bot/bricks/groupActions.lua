local mq             = require('mq')
local groupUtils      = require('booty.bot.bricks.groupUtils')
local movementActions = require('booty.bot.bricks.movementActions')

local groupActions = {}

local lastInviteRequestTime = 0

-- ============================================================
-- Actors  (nav* / do*)
-- ============================================================

--- Full invite flow: run to leader, request invite via /dex, accept when it arrives.
--- Call every tick from INIT state. Returns true, reason on any action taken.
---@param leaderName string
---@param inviteCooldown number
---@param closeDistance number
---@return boolean, string
function groupActions.navGroupInvite(leaderName, inviteCooldown, closeDistance)
    -- Accept pending invite
    if groupUtils.hasPendingInvite() then
        mq.cmd('/invite')
        return true, 'Accepting group invite'
    end

    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return false, string.format('%s not found in zone', leaderName) end

    -- Navigate toward leader if too far
    if leader.Distance() > closeDistance then
        local c, r = movementActions.navToPC(leaderName, closeDistance)
        if c then return c, r end
    end

    -- Close enough — request invite on cooldown
    local now = os.clock()
    if (now - lastInviteRequestTime) >= inviteCooldown then
        lastInviteRequestTime = now
        mq.cmdf('/dex %s /invite %s', leaderName, mq.TLO.Me.Name())
        return true, string.format('Requesting invite from %s', leaderName)
    end

    return false, 'Waiting for invite cooldown'
end

--- Reset invite cooldown (call from INIT state onEnter).
function groupActions.resetInviteTimer()
    lastInviteRequestTime = 0
end

return groupActions
