local mq = require('mq')
local utils = require('booty.utils')


local name = mq.TLO.Me.Name()

local startTrees = {
    Beta = require('booty.bot.bt.trees.shaman'),
}

if not startTrees[name] then
    utils.error(string.format("No behavior tree defined for character '%s'. Please add one to bot/bt/trees and update bot/init.lua.", name))
    return
end

-- Initialize the shared game state
local context = {
    leaderName = "Alpha",  -- Replace with your actual tank's name
    group = {
        lastInviteFrom = nil,
    },
    combat = {
        mode = "Walk",  -- Default combat mode, can be changed by behavior tree
    }
}
local startTree = startTrees[name](context)

mq.event('CatchInvite', '#1# invites you to join a group.', function(_, inviter_name)
    context.group.lastInviteFrom = inviter_name
end)

local lastStatus = nil
while true do
    mq.doevents()
    local _, status = startTree:tick(context)
    if status ~= lastStatus then
        print(string.format("[BT] %s", status or "idle"))
        lastStatus = status
    end
    mq.delay(50)
end