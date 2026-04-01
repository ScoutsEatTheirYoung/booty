local sequence     = require('booty.bot.bt.composites.sequence')
local actionSpells = require('booty.bot.bt.actions.spells')

return sequence:new("Group_Buff_Phase", {
    actionSpells.ensureQueueExists(),
    actionSpells.keepUp(),
})
