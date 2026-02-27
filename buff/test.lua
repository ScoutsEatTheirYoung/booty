local BuffManager = require('booty.buff.manager')

local myBuffs = {
    { name = "Spirit of Yekan", targets = {"pet_summon"} },
    { name = "Yekan's Quickening", targets = {"pet"} },
    { name = "Spirit of the Scorpion",  targets = {"pet"} },
    { name = "Raging Strength",   targets = {"self", "pet"} },
    { name = "Inner Fire",        targets = {"self", "pet"} },
    { name = "Spirit of Wolf",     targets = {"self", "pet"} },
    { name = "Spirit of Ox",    targets = {"self", "pet"} },
    { name = "Spirit of Monkey", targets = {"self", "pet"} },
}

BuffManager.checkAndCast(myBuffs, 8)