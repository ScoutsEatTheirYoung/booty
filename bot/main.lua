local mq = require('mq')
local bb = require('booty.bot.bt.blackboard')
local bt = require('booty.bot.bt.engine')
-- Load your specific class tree (e.g., Shaman or Mage)
local brains = {
    beta = 'shaman',
    gamma = 'mage'
}

local myName = mq.TLO.Me.Name()
local brainPath = "booty.bot.brains." .. brains[myName:lower()]
print(string.format("Loading brain for %s from path: %s", myName, brainPath))
local brain = require(brainPath)
-- if not status then
--     printf("\ar[Error]\ax Could not find brain file at: %s.lua", brainPath)
--     mq.exit()
-- end

-- 1. PERSISTENT STATE INITIALIZATION
-- This happens ONCE when you /lua run.
bb.set("camp_x", mq.TLO.Me.X())
bb.set("camp_y", mq.TLO.Me.Y())
bb.set("camp_z", mq.TLO.Me.Z())
bb.set("isPaused", false)
bb.set("leaderName", "Alpha")
bb.set("followDist", 10)
bb.set("inviteCooldown", 5)
bb.set("lastInviteFrom", nil)
bb.set("lastBTPath", '')
bb.set("targetID", 0)

mq.unevent('CatchInvite')
mq.event('CatchInvite', '#1# invites you to join a group.', function(line, inviter)
    -- Write the extracted name directly to persistent state
    bb.set("lastInviteFrom", inviter)
end)

mq.bind('/btree', function()
    bt.PrintTree(brain)
end)

local function printAndSaveBTree()
    local filename = string.format('%s_dump.txt', brain.name)
    local path = string.format('C:\\MQ2\\lua\\booty\\bot\\brains\\%s', filename)
    local f = io.open(path, 'w')
    if not f then return end
    local function dump(node, depth, prefix, isLast)
        depth = depth or 0
        prefix = prefix or ""
        isLast = isLast == nil and true or isLast

        local connector = isLast and "└── " or "├── "
        local childPrefix = prefix .. (isLast and "    " or "│   ")

        if type(node) ~= "table" then
            f:write(prefix .. connector .. "[bare_fn] (not a bt node)\n")
            return
        end
        f:write(prefix .. connector .. string.format("[%s] %s\n", node.type or "?", node.name or "?"))
        if node.children then
            for i, child in ipairs(node.children) do
                dump(child, depth + 1, childPrefix, i == #node.children)
            end
        end
    end
    f:write(string.format("[%s] %s\n", brain.type or "?", brain.name or "?"))
    if brain.children then
        for i, child in ipairs(brain.children) do
            dump(child, 1, "", i == #brain.children)
        end
    end
    f:close()
    mq.cmd('/echo Behavior Tree structure saved to ' .. filename)
end

mq.bind('/btreefile', function()
    printAndSaveBTree()
end)


mq.bind('/pausebot', function()
    local paused = bb.get("isPaused")
    bb.set("isPaused", not paused)
    mq.cmdf('/echo Behavior Tree %s', not paused and "Paused" or "Resumed")
end)

-- 2. TELEMETRY HELPER
local function get_status_label(status)
    if status == 1 then return "\agSUCCESS\ax" end
    if status == 2 then return "\arFAILURE\ax" end
    if status == 3 then return "\ayRUNNING\ax" end
    return "UNKNOWN"
end

-- 3. THE HEARTBEAT MAPPING
local function main()
    printf("\ag[BootyBot]\ax Engine Started. Anchor set at: %.2f, %.2f", bb.get("camp_x"), bb.get("camp_y"))
    while true do
        -- A. Handle MQ Events (Chat, Spells, etc.)
        mq.doevents()

        -- B. Global Pause Check (Manual Override)
        if not bb.get("isPaused") then
            
            -- C. START THE TICK: Invalidate 10ms cache
            bb.NewTick()

            -- D. EXECUTE THE TREE: The Triple Return
            -- Status = Int, Msg = String, Path = Breadcrumb String
            local status, msg, path = brain()

            -- E. TELEMETRY OUTPUT
            -- Only print if the status is RUNNING or SUCCESS to avoid log spam
            if status ~= bt.FAILURE then 
                local log_line = string.format("[%s] %s : %s", get_status_label(status), path, msg)
                if log_line ~= bb.get("lastBTPath") then
                    bb.set("lastBTPath", log_line)
                    print(log_line)
                end
            end
        end

        -- F. YIELD: Give the EQ Client its frames back
        mq.delay(10) 
    end
end

main()