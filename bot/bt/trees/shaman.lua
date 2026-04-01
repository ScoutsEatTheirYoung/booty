local sequence          = require('booty.bot.bt.composites.sequence')
local gettingGrouped    = require('booty.bot.bt.trees.getting_grouped')

return sequence:new("Shaman_Root", {
    gettingGrouped,
})
