local BuffManager = require('booty.buff.manager')

local myBuffs = {
    { name = "Spirit of Herikol", targets = {"pet_summon"} },
    { name = "Spirit of Inferno",  targets = {"pet"} },
    { name = "Spirit Strength",   targets = {"self", "pet"} },
    { name = "Inner Fire",        targets = {"self", "pet"} },
    { name = "Spirit of Wolf",     targets = {"self", "pet"} },
    { name = "Spirit of Bear",    targets = {"self", "pet"} },
}

BuffManager.checkAndCast(myBuffs, 8)