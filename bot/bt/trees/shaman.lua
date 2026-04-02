local sequence          = require('booty.bot.bt.composites.sequence')
local gettingGrouped    = require('booty.bot.bt.trees.getting_grouped')
local nav            = require('booty.bot.bt.actions.nav')

return sequence:new("Shaman_Root", {
    gettingGrouped,
    nav.toLeader(),
})
