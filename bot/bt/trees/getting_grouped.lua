-- 1. Import Composites & Decorators
local sequence = require('booty.bot.bt.composites.sequence')
local selector = require('booty.bot.bt.composites.selector')
local invert = require('booty.bot.bt.decorators.invert')
local cooldown = require('booty.bot.bt.decorators.cooldown')

-- 2. Import Leaves (Sensors, Actions, and Stateful Nodes)
local check = require('booty.bot.bt.leaves.check')
local setup = require('booty.bot.bt.leaves.setup')
local action = require('booty.bot.bt.leaves.action')
local navToLeader = require('booty.bot.bt.leaves.movement.nav_to_leader')

-- 3. Construct the Tree Structure
local GettingGrouped = sequence:new("Getting_Grouped_Phase", {
    
    -- EXIT CONDITION: Skip this whole phase if already grouped
    invert:new("Not_Grouped", check.isGrouped()),
    
    -- APPROACH: Stateful node that handles its own /nav stop on abort
    navToLeader:new("Approach_Leader"),
    
    -- HANDSHAKE LOOP: Evaluate priorities frame-by-frame
    selector:new("Invite_Handler", {
        
        -- Priority 1: Accept if box is open
        sequence:new("Accept_Pending", {
            check.hasPendingInvite(),
            setup.acceptInviteFromLeader()
        }),
        
        -- Priority 2: Ask for invite, but throttle the spam to every 5 seconds
        cooldown:new("Throttle_Requests", 5000,
            setup.dexLeaderForInvite()
        ),
        
        -- Priority 3: The Trap. Return RUNNING to hold the tree here while waiting
        action.returnRunning("Waiting for group invite...")
    })
})

return GettingGrouped