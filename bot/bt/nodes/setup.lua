local mq = require('mq')
local bt = require('booty.bot.bt.engine')
local bb = require('booty.bot.bt.blackboard')

local setup = {}

-- Keep your event listener exactly as is
mq.event('CatchInvite', '#1# invites you to join a group.', function(line, inviter_name)
    bb.set("lastInviteFrom", inviter_name) 
end)

-----------------------------------------------------------------------------
-- 1. SENSORS (Instant True/False Checks)
-----------------------------------------------------------------------------
function setup.isGrouped()
    return bt.Leaf("isGrouped", function()
        if mq.TLO.Me.Grouped() then return bt.SUCCESS end
        return bt.FAILURE
    end)
end

function setup.hasPendingInvite()
    return bt.Leaf("hasPendingInvite", function()
        if mq.TLO.Me.Invited() then return bt.SUCCESS end
        return bt.FAILURE
    end)
end

-----------------------------------------------------------------------------
-- 2. ACTIONS (Dumb Verbs)
-----------------------------------------------------------------------------
function setup.dexLeaderForInvite()
    local lastInviteRequestTime = 0
    return bt.Leaf("RequestInvite", function()
        local leaderName = bb.get("leaderName")
        if not leaderName then return bt.FAILURE, "No leader name" end
        
        local now = os.clock()
        local inviteCooldown = bb.get("inviteCooldown") or 5
        
        -- If we are off cooldown, ask for the invite
        if (now - lastInviteRequestTime) >= inviteCooldown then
            lastInviteRequestTime = now
            mq.cmdf('/dex %s /invite %s', leaderName, mq.TLO.Me.Name())
        end
        
        -- ALWAYS return RUNNING so the tree waits here for the server/leader to respond
        return bt.RUNNING, "Waiting for leader to send invite..."
    end)
end

function setup.acceptInvitationFromLeader()

    return bt.Leaf("acceptInvitationFromLeader", function()
        local inviter = bb.get("lastInviteFrom") or ""
        local leaderName = bb.get("leaderName")
        if not leaderName then return bt.FAILURE, "No leader name" end

        if inviter:lower() == leaderName:lower() then
            mq.cmd('/invite')
            -- We return RUNNING here. The server takes a moment to put us in the group.
            -- Returning RUNNING holds the tree here until the server catches up.
            return bt.RUNNING, "Clicked accept, waiting for server sync..."
        end

        return bt.FAILURE, "Pending invite is not from leader"
    end)
end

-----------------------------------------------------------------------------
-- 3. THE STRUCTURE (The Intelligence)
-----------------------------------------------------------------------------
function setup.goToLeaderAndGroup()
    local movement = require('booty.bot.bt.nodes.movement')
    
    return bt.Selector("Group Setup", {
        -- OPTION 1: We are already grouped. Succeed instantly and move on.
        setup.isGrouped(),
        
        -- OPTION 2: We need to join. 
        -- If any step here fails, the Selector tries again next tick.
        bt.Sequence("Join Group", {
            movement.goToLeader(),
            
            -- Fallback/Selector: We either already have an invite, or we must ask for one
            bt.Selector("Obtain Invite", {
                setup.hasPendingInvite(),
                setup.dexLeaderForInvite() -- This returns RUNNING until hasPendingInvite is true
            }),
            
            setup.acceptInvitationFromLeader()
        })
    })
end

return setup