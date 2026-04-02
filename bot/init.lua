local mq         = require('mq')
local utils      = require('booty.utils')
local newContext = require('booty.bot.bt.contexts.default')

local name = mq.TLO.Me.Name()

local characters = {
    Beta = {
        config = require('booty.bot.bt.contexts.shaman'),
        tree   = require('booty.bot.bt.trees.shaman'),
    },
}

if not characters[name] then
    utils.error(string.format(
        "No behavior tree defined for '%s'. Add an entry to bot/init.lua.",
        name))
    return
end

-- Shared context. Can be read and written by any node in the tree.
local context = newContext("Alpha")

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
