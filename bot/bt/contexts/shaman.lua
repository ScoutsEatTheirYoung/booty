---@param context table
return function(context)
    context.leaderName = context.leaderName or "Alpha"
    context.buff = {
        list = {
            { spellName = "Inner Fire",        refreshTime = 600, targets = { "self", "group" } },
            { spellName = "Raging Strength",   refreshTime = 600, targets = { "self", "group" } },
            { spellName = "Rising Dexterity",  refreshTime = 600, targets = { "self", "group" } },
            { spellName = "Nimble",            refreshTime = 600, targets = { "self", "group" } },
            { spellName = "Health",            refreshTime = 600, targets = { "self", "group" } },
            { spellName = "Shifting Shield",   refreshTime = 600, targets = { "self", "group" } },
            { spellName = "Regeneration",      refreshTime = 60,  targets = { "self", "group" } },
            { spellName = "Quickness",         refreshTime = 60,  targets = { "self", "group" } },
            { spellName = "Talisman of Tnarg", refreshTime = 600, targets = { "self", "group" } },
        },
    }
end
