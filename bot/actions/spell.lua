local mq = require('mq')

local spellActions = {}

function spellActions.isSpellOnSpellBar

function spellActions.summonPet(petSpellName, reagent)
    if not mq.TLO.Me.Book(petSpellName) then
        utils.info(string.format("Pet summon spell '%s' is not in spell book.", petSpellName))
        return false
    end
    if reagent and not mq.TLO.Inventory(reagent).Count() then
        utils.info(string.format("Missing reagent '%s' for pet summon spell '%s'.", reagent, petSpellName))
        return false
    end
end

return spellActions