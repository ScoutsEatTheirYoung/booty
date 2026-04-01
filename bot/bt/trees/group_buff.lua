local sequence = require('booty.bot.bt.composites.sequence')
local buff     = require('booty.bot.bt.leaves.buff')
local check    = require('booty.bot.bt.leaves.check')

local function GroupBuffTree()
    return sequence:new("Maintain_Group_Buffs_Phase", {
        check.notNil("buff.list"), -- ensure we have a buff list to work with
        
    })
        

end

return GroupBuffTree
