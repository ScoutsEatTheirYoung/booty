local mq            = require('mq')
local fsm           = require('booty.bot.fsm')
local movementActions = require('booty.bot.bricks.movementActions')
local groupActions  = require('booty.bot.bricks.groupActions')
local groupUtils    = require('booty.bot.bricks.groupUtils')
local travel        = require('booty.bot.travel')

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
    leader     = "Alpha",
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
        return false, "Idle — waiting for /setstate"
    end,
}

-- ============================================================
-- State: INIT (shared)
-- Navigates to leader, requests group invite, accepts it.
-- Auto-transitions to FOLLOW once grouped.
-- ============================================================
local INVITE_COOLDOWN = 5   -- seconds between invite requests
local INIT_CLOSE_DIST = 20  -- distance at which we request the invite

fsm.states["INIT"] = {
    onEnter = function()
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
        groupActions.resetInviteTimer()
    end,
    execute = function()
        if groupUtils.isGrouped() then
            fsm.changeState("FOLLOW")
            return
        end
        local c, r = groupActions.navGroupInvite(LEADER, INVITE_COOLDOWN, INIT_CLOSE_DIST)
        if c then return c, r end
        return false, "Waiting for group invite"
    end,
    onExit = function()
        mq.cmd('/squelch /nav stop')
    end,
}

-- ============================================================
-- State: GUILDHALLPORT (shared)
-- Params set by /guildport <porter> <location> before transitioning.
-- ============================================================
local guildHallPort = {
    porterName = nil,
    location = nil,
}

fsm.states["GUILDHALLPORT"] = {
    onEnter = function()
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
    end,
    execute = function()
        if not guildHallPort.porterName or not guildHallPort.location then
            return false, "No port destination set — use /guildport <porter> <location>"
        end
        local c, r = travel.ascendantGuildHallPort(guildHallPort.porterName, guildHallPort.location)
        if c then return c, r end
        fsm.changeState("FOLLOW")
    end,
    onExit = function()
        mq.cmd('/squelch /nav stop')
        guildHallPort.porterName = nil
        guildHallPort.location = nil
    end,
}

mq.bind('/guildport', function(porter, location)
    guildHallPort.porterName = porter
    guildHallPort.location = location
    fsm.changeState("GUILDHALLPORT")
end)

-- ============================================================
-- State: FOLLOW (shared)
-- ============================================================
fsm.states["FOLLOW"] = {
    onEnter = function()
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
    end,
    execute = function()
        local c, r = movementActions.navFanFollow(config.leader, config.offset, config.followDist)
        if c then return c, r end
        return false, "Following " .. config.leader
    end,
    onExit = function()
        mq.cmd('/squelch /nav stop')
    end,
}

-- ============================================================
-- Name-based dispatch
-- Map each bot's character name to its module.
-- ============================================================
local NAME_MODULES = {
    Beta  = 'booty.bot.shaman',
    Gamma = 'booty.bot.mage',
}

local myName = mq.TLO.Me.Name()
local modulePath = NAME_MODULES[myName]

if modulePath then
    require(modulePath)(config)
else
    print(string.format('\ar[Bot]\aw No module for character: \ay%s\ar. States: IDLE, FOLLOW only.', myName))
end

-- ============================================================
-- Main Loop
-- ============================================================
print(string.format('\ag[Bot]\aw Online as \ay%s\aw — /setstate <IDLE|FOLLOW|MELEE>', myName))

fsm.changeState("INIT")

while true do
    fsm.update()
    mq.delay(50)
end
