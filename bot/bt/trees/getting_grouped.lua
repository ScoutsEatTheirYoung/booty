local sequence  = require('booty.bot.bt.composites.sequence')
local selector  = require('booty.bot.bt.composites.selector')
local invert    = require('booty.bot.bt.decorators.invert')
local cooldown  = require('booty.bot.bt.decorators.cooldown')
local sensorGroup  = require('booty.bot.bt.sensors.group')
local actionGroup  = require('booty.bot.bt.actions.group')
local actionNav    = require('booty.bot.bt.actions.nav')
local actionCtrl   = require('booty.bot.bt.actions.control')

return sequence:new("Getting_Grouped_Phase", {

    -- EXIT CONDITION: skip this whole phase if already grouped
    invert:new("Not_Grouped",
        sensorGroup.isGrouped()
    ),

    -- APPROACH: navigate to leader, stops nav automatically on abort
    actionNav:new("[A]_Approach_Leader"),

    -- HANDSHAKE LOOP: evaluate priorities every tick
    selector:new("Invite_Handler", {

        -- Priority 1: accept if confirmation box is open
        sequence:new("Accept_Pending", {
            sensorGroup.hasPendingInvite(),
            actionGroup.acceptInviteFromLeader(),
        }),

        -- Priority 2: ask for invite, throttled to once every 5 seconds
        cooldown:new("Throttle_Requests", 5000,
            actionGroup.dexLeaderForInvite()
        ),

        -- Priority 3: hold the tree open while waiting for the invite
        actionCtrl.returnRunning("Waiting for group invite..."),
    }),
})
