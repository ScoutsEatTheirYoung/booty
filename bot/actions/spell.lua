local mq = require('mq')

local spell = {}

-- ============================================================
-- Fizzle tracking
-- ============================================================
local FIZZLE_BACKOFF = 0.2  -- seconds to back off after a fizzle
local lastFizzleTime = 0

mq.event('SpellFizzle', '#*#Your spell fizzles#*#', function()
    lastFizzleTime = os.clock()
end)

---@return boolean
function spell.justFizzled()
    return (os.clock() - lastFizzleTime) < FIZZLE_BACKOFF
end

-- ============================================================
-- Pure checks  (is* / has* / find* / get*)
-- ============================================================

--- Iterate gem slots 1-12 and return the slot number if spellName is memmed, else nil.
---@param spellName string
---@return integer|nil
function spell.findGemForSpell(spellName)
    for i = 1, 12 do
        if mq.TLO.Me.Gem(i)() == spellName then
            return i
        end
    end
    return nil
end

---@param spellName string
---@return boolean
function spell.isSpellMemmed(spellName)
    return spell.findGemForSpell(spellName) ~= nil
end

--- True if spellName appears in any gem slot on the spell bar.
---@param spellName string
---@return boolean
function spell.isOnBar(spellName)
    return spell.findGemForSpell(spellName) ~= nil
end

---@param spellName string
---@return boolean
function spell.isSpellReady(spellName)
    local gem = spell.findGemForSpell(spellName)
    if not gem then return false end
    return mq.TLO.Me.SpellReady(gem)() == true
end

--- Bool: spell will land on current target (checks stacking, immunity, etc.).
---@param spellName string
---@return boolean
function spell.willLand(spellName)
    return (mq.TLO.Spell(spellName).WillLand() or 0) > 0
end

---@param spellName string
---@return boolean
function spell.hasManaForSpell(spellName)
    local cost = mq.TLO.Spell(spellName).Mana() or 0
    return mq.TLO.Me.CurrentMana() >= cost
end

-- ============================================================
-- Actors  (cast* / memorize*)
-- ============================================================

--- Memorize spellName into gemNum.
--- Precondition: spellName must be in the spellbook and gemNum must be a valid slot.
---@param gemNum integer
---@param spellName string
---@return boolean, string
function spell.memorizeSpell(gemNum, spellName)
    if spell.isOnBar(spellName) then
        return false, string.format("'%s' already on bar", spellName)
    end
    if mq.TLO.Window('SpellBookWnd').Open() then
        return true, string.format('Memorizing %s', spellName)
    end
    mq.cmdf('/memspell %d "%s"', gemNum, spellName)
    return true, string.format('Memorizing %s into gem %d', spellName, gemNum)
end

--- Cast spellName (must already be memmed and ready) on current target.
---@param spellName string
---@return boolean, string
function spell.castSpell(spellName)
    if spell.justFizzled() then
        return false, 'Backing off after fizzle'
    end
    if mq.TLO.Me.Casting() then
        return true, 'Casting ' .. spellName
    end
    local gem = spell.findGemForSpell(spellName)
    if not gem then
        return false, string.format("'%s' not memmed", spellName)
    end
    if not spell.hasManaForSpell(spellName) then
        return false, string.format("Not enough mana for '%s'", spellName)
    end
    if not mq.TLO.Me.SpellReady(gem)() then
        return true, string.format('Waiting for %s to be ready', spellName)
    end
    mq.cmdf('/cast %d', gem)
    return true, string.format('Casting %s', spellName)
end

--- Mem spellName into gemNum if needed, then cast it. One step per tick.
---@param spellName string
---@param gemNum integer
---@return boolean, string
function spell.castSpellInGem(spellName, gemNum)
    if not spellName or spellName == "" then return false, "No spell configured" end
    if not mq.TLO.Me.Book(spellName)() then
        return false, string.format("'%s' not in spellbook", spellName)
    end
    local c, r = spell.memorizeSpell(gemNum, spellName)
    if c then return c, r end
    local gem = spell.findGemForSpell(spellName)
    if not gem then return false, string.format("'%s' not on bar", spellName) end
    if not mq.TLO.Me.SpellReady(gem)() then
        return true, string.format('Waiting for %s to be ready', spellName)
    end
    return spell.castSpell(spellName)
end

--- Summon a pet. Mems the spell into gemNum if needed.
--- reagent is optional — pass nil if the spell needs no reagent.
---@param spellName string
---@param gemNum integer
---@param reagent string|nil
---@return boolean, string
function spell.castSummonPet(spellName, gemNum, reagent)
    if not mq.TLO.Me.Book(spellName)() then
        return false, string.format("'%s' not in spellbook", spellName)
    end
    if reagent and not mq.TLO.FindItem(reagent)() then
        return false, string.format("Missing reagent: %s", reagent)
    end
    local c, r = spell.memorizeSpell(gemNum, spellName)
    if c then return c, r end
    return spell.castSpell(spellName)
end

return spell
