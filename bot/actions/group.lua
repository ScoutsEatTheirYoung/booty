local mq  = require('mq')
local bit = require('bit')
local move = require('booty.bot.actions.movement')

local group = {}

local lastInviteRequestTime = 0

-- ============================================================
-- Pure checks  (is* / has*)
-- ============================================================

--- True if pcName has their weapons drawn aggressively (PlayerState bits 4 or 8).
---@param pcName string
---@return boolean
function group.isPcEngaged(pcName)
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return false end
    return bit.band(pc.PlayerState() or 0, 12) ~= 0
end

--- True if any mob is actively targeting a group member (via extended target list).
---@return boolean
function group.isGroupEngaged()
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and (xt.ID() or 0) > 0 then return true end
    end
    return false
end

--- Return the first live NPC spawn from the XTarget list, or nil.
---@return MQSpawn|nil
function group.getEngagedTarget()
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and (xt.ID() or 0) > 0 then
            local spawn = mq.TLO.Spawn(xt.ID())
            if spawn() and spawn.Type() == "NPC" and (spawn.PctHPs() or 0) > 0 then
                return spawn
            end
        end
    end
    return nil
end

---@return boolean
function group.isGrouped()
    return mq.TLO.Me.Grouped() == true
end

---@return boolean
function group.hasPendingInvite()
    return mq.TLO.Me.Invited() == true
end

-- ============================================================
-- Actors  (nav* / do*)
-- ============================================================

--- Full invite flow: run to leader, request invite via /dex, accept when it arrives.
--- Call every tick from INIT state. Returns true, reason on any action taken.
---@param leaderName string
---@param inviteCooldown number
---@param closeDistance number
---@return boolean, string
function group.navGroupInvite(leaderName, inviteCooldown, closeDistance)
    -- Accept pending invite
    if group.hasPendingInvite() then
        mq.cmd('/invite')
        return true, 'Accepting group invite'
    end

    local leader = mq.TLO.Spawn('pc =' .. leaderName)
    if not leader() then return false, string.format('%s not found in zone', leaderName) end

    -- Navigate toward leader if too far
    if leader.Distance() > closeDistance then
        local c, r = move.navToPC(leaderName, closeDistance)
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
function group.resetInviteTimer()
    lastInviteRequestTime = 0
end

return group
