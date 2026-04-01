local mq    = require('mq')
local utils = require('booty.utils')

local name = mq.TLO.Me.Name()

local characters = {
    Beta = {
        config = require('booty.bot.bt.configs.shaman'),
        tree   = require('booty.bot.bt.trees.shaman'),
    },
}

if not characters[name] then
    utils.error(string.format(
        "No behavior tree defined for '%s'. Add an entry to bot/init.lua.",
        name))
    return
end

local context = {
    leaderName = "Alpha",
    group  = { lastInviteFrom = nil },
    combat = { mode = "Walk" },
}

local char = characters[name]
char.config(context)
local startTree = char.tree

mq.event('CatchInvite', '#1# invites you to join a group.', function(_, inviterName)
    context.group.lastInviteFrom = inviterName
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
