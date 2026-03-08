local BuffManager = require('booty.buff.manager')

local myBuffs = {
    { name = "Spirit of Kashek", targets = {"pet_summon"} },
    { name = "Yekan's Quickening", targets = {"pet"} },
    { name = "Spirit of Vermin",  targets = {"pet"} },
    { name = "Raging Strength",   targets = {"self", "pet"} },
    { name = "Inner Fire",        targets = {"self", "pet"} },
    { name = "Spirit of Ox",    targets = {"self", "pet"} },
    { name = "Spirit of Monkey", targets = {"self", "pet"} },
    { name = "Protect", targets = {"self", "pet"} },
}

BuffManager.checkAndCast(myBuffs, 8)