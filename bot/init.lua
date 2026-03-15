local mq      = require('mq')
local fsm     = require('booty.bot.fsm')
local actions = require('booty.bot.actions')
local groupActs = require('booty.bot.actions.group')

-- ============================================================
-- Shared config — class modules receive this table
-- ============================================================
local LEADER      = "Alpha"
local FOLLOW_DIST = 15

local OFFSETS = {
    Beta  = { x =  8, y =  8 },
    Gamma = { x = -8, y = -8 },
}

local config = {
    leader     = LEADER,
    offset     = OFFSETS[mq.TLO.Me.Name()] or { x = 0, y = 0 },
    followDist = FOLLOW_DIST,
}

-- ============================================================
-- State: IDLE (shared)
-- ============================================================
fsm.states["IDLE"] = {
    onEnter = function()
        mq.cmd('/squelch /nav stop')
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
    end,
    execute = function()
        -- Waiting for /setstate
    end,
}

-- ============================================================
-- State: INIT (shared)
-- Runs on startup. Navigates to the leader, asks them via DNet
-- to invite us, then accepts the invite. Once grouped, transitions
-- automatically to FOLLOW.
--
-- Tick flow:
--   1. Already grouped? → FOLLOW (done)
--   2. Pending invite? → /invite to accept
--   3. Leader not in zone? → wait
--   4. Too far from leader? → nav toward them
--   5. Close enough + no invite → /dtell leader to invite (5s cooldown)
-- ============================================================
local INVITE_COOLDOWN  = 5     -- seconds between invite requests
local INIT_CLOSE_DIST  = 20    -- how close we need to be before requesting invite

fsm.states["INIT"] = {
    onEnter = function()
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
        groupActs.lastInviteRequestTime = 0
    end,
    execute = function()
        -- Already grouped — we're done
        if mq.TLO.Me.Grouped() then
            fsm.changeState("FOLLOW")
            return
        end
        groupActs.runToLeaderAndRequest(LEADER, config.offset, INVITE_COOLDOWN, INIT_CLOSE_DIST)
    end,
    onExit = function()
        mq.cmd('/squelch /nav stop')
    end,
}

-- ============================================================
-- State: FOLLOW (shared)
-- ============================================================
fsm.states["FOLLOW"] = {
    onEnter = function()
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
    end,
    execute = function()
        actions.fanFollow(config.leader, config.offset, config.followDist)
    end,
    onExit = function()
        mq.cmd('/squelch /nav stop')
    end,
}

-- ============================================================
-- Class dispatch
-- ============================================================
local CLASS_MODULES = {
    SHM = 'booty.bot.shaman',
    MAG = 'booty.bot.mage',
}

local class = mq.TLO.Me.Class.ShortName()
local modulePath = CLASS_MODULES[class]

if modulePath then
    require(modulePath)(config)
else
    print(string.format('\ar[Bot]\aw No class module for: \ay%s\ar. States: IDLE, FOLLOW only.', class or '?'))
end

-- ============================================================
-- Main Loop
-- ============================================================
print(string.format('\ag[Bot]\aw Online as \ay%s\aw (%s) — /setstate <IDLE|FOLLOW|MELEE>',
    mq.TLO.Me.Name(), class or '?'))

fsm.changeState("INIT")

while true do
    fsm.update()
    mq.delay(50)
end
