local mq = require('mq')
local bt = require('booty.bot.bt.engine')
local bb = require('booty.bot.bt.blackboard')

local target = {}

function target.clearTarget()
    return function()
        if not mq.TLO.Target() then
            return bt.SUCCESS, "No target", "clearTarget"
        end
        mq.cmd('/squelch /target clear')
        return bt.RUNNING, "Clearing target", "clearTarget"
    end
end


--- Helper: Checks if the EverQuest client already holds this ID's buff data in RAM
local function requiresBuffSync(targetId)
    -- Self and Pet never require a server sync
    if targetId == mq.TLO.Me.ID() or targetId == mq.TLO.Me.Pet.ID() then
        return false
    end
    
    -- Group members never require a server sync
    local groupCount = mq.TLO.Group.Members() or 0
    for i = 1, groupCount do
        if mq.TLO.Group.Member(i).ID() == targetId then
            return false
        end
    end
    
    -- Everyone else (Raid members, XTarget, NPCs) requires the server handshake
    return true
end

function target.targetIdAndSync(blackboard_key)
    local myName = "TargetIdAndSync(" .. blackboard_key .. ")"
    local lastTargetChangeCommandIssueTime = 0
    local targetChangeDelayTime = 200
    return bt.Leaf(myName, function()
        local targetId = tonumber(bb.get(blackboard_key))
        if not targetId or targetId == 0 then
            return bt.FAILURE, "Invalid or missing ID on blackboard"
        end
        
        local spawn = mq.TLO.Spawn(string.format('id %d', targetId))
        if not spawn() then
            return bt.FAILURE, "Spawn ID " .. targetId .. " is no longer in zone"
        end

        local currentTargetId = mq.TLO.Target.ID() or 0
        local now = mq.gettime()
        -- STEP 1: Physical Target Change
        if currentTargetId ~= targetId then
            if targetId == mq.TLO.Me.ID() then
                mq.cmd('/tar myself')
            elseif targetId == mq.TLO.Me.Pet.ID() then
                mq.cmd('/tar pet')
            else
                mq.cmdf('/squelch /tar id %d', targetId)
            end

            lastTargetChangeCommandIssueTime = now
            return bt.RUNNING, "Acquiring target..."
        elseif (now - lastTargetChangeCommandIssueTime) < targetChangeDelayTime then
            -- We recently issued a target change command, wait for it to register
            return bt.RUNNING, "Delayed after target command " .. targetChangeDelayTime .. "ms"
        end

        -- STEP 2: The Fast-Path Sync Check
        if requiresBuffSync(targetId) then
            if not mq.TLO.Target.BuffsPopulated() then
                return bt.RUNNING, "Waiting for server buff data..."
            end
        end
        
        return bt.SUCCESS, "Target acquired and synced"
    end)
end

return target