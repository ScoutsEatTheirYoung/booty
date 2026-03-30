local mq         = require('mq')
local spellUtils  = require('booty.bot.bricks.spellUtils')
local groupUtils  = require('booty.bot.bricks.groupUtils')

local spellActions = {}

-- ============================================================
-- Actors  (cast* / memorize*)
-- ============================================================

--- Memorize spellName into the least-recently-used gem slot.
--- Precondition: spellName must be in the spellbook.
---@param spellName string
---@return boolean, string
function spellActions.memorizeSpell(spellName)
    if spellUtils.isOnBar(spellName) then
        return false, string.format("'%s' already on bar", spellName)
    end
    if mq.TLO.Window('SpellBookWnd').Open() then
        return true, string.format('Memorizing %s', spellName)
    end
    local gem = spellUtils.nextGem()
    mq.cmdf('/memspell %d "%s"', gem, spellName)
    spellUtils.onMemGem(gem)
    return true, string.format('Memorizing %s into gem %d', spellName, gem)
end

--- Cast spellName (must already be memmed and ready) on current target.
---@param spellName string
---@return boolean, string
function spellActions.castSpell(spellName)
    if spellUtils.justFizzled() then
        return true, 'Backing off after fizzle'
    end
    if mq.TLO.Me.Casting() then
        return true, 'Casting ' .. mq.TLO.Me.Casting.Name()
    end
    local gem = spellUtils.findGemForSpell(spellName)
    if not gem then
        return false, string.format("'%s' not memmed", spellName)
    end
    if not spellUtils.hasManaForSpell(spellName) then
        return false, string.format("Not enough mana for '%s'", spellName)
    end
    if not mq.TLO.Me.SpellReady(gem)() then
        return true, string.format('Waiting for %s to be ready', spellName)
    end
    mq.cmdf('/cast %d', gem)
    spellUtils.onCastGem(gem)
    return true, string.format('Casting %s', spellName)
end

--- Mem spellName if needed, then cast it. One step per tick.
---@param spellName string
---@return boolean, string
function spellActions.castAndMem(spellName)
    if not spellName or spellName == "" then return false, "No spell configured" end
    if not mq.TLO.Me.Book(spellName)() then
        return false, string.format("'%s' not in spellbook", spellName)
    end
    local c, r = spellActions.memorizeSpell(spellName)
    if c then return c, r end
    return spellActions.castSpell(spellName)
end

--- While casting, consume the tick unless an emergency warrants interruption.
--- emergencyPct: if any group member HP drops below this, allow the cast to be
--- interrupted (returns false) so heal logic can run. Pass nil to never allow
--- interruption (e.g. classes with no emergency heal, like mage).
---@param emergencyPct number|nil
---@return boolean, string
function spellActions.guardCasting(emergencyPct)
    if not mq.TLO.Me.Casting() then return false, '' end
    local castName = mq.TLO.Me.Casting.Name() or 'spell'
    if emergencyPct == nil or groupUtils.minGroupHp() > emergencyPct then
        return true, string.format('Casting %s', castName)
    end
    return false, ''
end

--- Summon a pet. Mems the spell if needed.
--- reagent is optional — pass nil if the spell needs no reagent.
---@param spellName string
---@param reagent string|nil
---@return boolean, string
function spellActions.castSummonPet(spellName, reagent)
    if not mq.TLO.Me.Book(spellName)() then
        return false, string.format("'%s' not in spellbook", spellName)
    end
    if reagent and not mq.TLO.FindItem(reagent)() then
        return false, string.format("Missing reagent: %s", reagent)
    end
    local c, r = spellActions.memorizeSpell(spellName)
    if c then return c, r end
    return spellActions.castSpell(spellName)
end

return spellActions
