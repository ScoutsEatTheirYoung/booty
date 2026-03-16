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

-- Bool: a fizzle occurred within the backoff window.
function spell.justFizzled()
    return (os.clock() - lastFizzleTime) < FIZZLE_BACKOFF
end

-- ============================================================
-- Pure checks  (is* / has* / find* / get*)
-- ============================================================

-- Iterate gem slots 1-12 and return the slot number if spellName is memmed, else nil.
function spell.findGemForSpell(spellName)
    for i = 1, 12 do
        if mq.TLO.Me.Gem(i)() == spellName then
            return i
        end
    end
    return nil
end

-- Bool: spell is in any gem slot.
function spell.isSpellMemmed(spellName)
    return spell.findGemForSpell(spellName) ~= nil
end

-- Bool: spell is memmed AND off cooldown.
function spell.isSpellReady(spellName)
    local gem = spell.findGemForSpell(spellName)
    if not gem then return false end
    return mq.TLO.Me.SpellReady(gem)() == true
end

-- Bool: spell will land on current target (checks stacking, immunity, etc.).
function spell.willLand(spellName)
    return mq.TLO.Spell(spellName).WillLand() == true
end

-- ============================================================
-- Actors  (cast*)
-- ============================================================

-- Memorize spellName into gemNum. Returns true, reason on action taken.
function spell.memorizeSpell(gemNum, spellName)
    if not mq.TLO.Me.Book(spellName)() then
        return false
    end
    if mq.TLO.Me.Gem(gemNum)() == spellName then
        return false  -- Already memmed in that slot
    end
    mq.cmdf('/memspell %d "%s"', gemNum, spellName)
    return true, string.format('Memorizing %s into gem %d', spellName, gemNum)
end

-- Cast spellName (must already be memmed and ready) on current target.
function spell.castSpell(spellName)
    if spell.justFizzled() then
        return false
    end
    if mq.TLO.Me.Casting() then
        return true, 'Casting ' .. spellName
    end
    local gem = spell.findGemForSpell(spellName)
    if not gem then
        return false
    end
    if not mq.TLO.Me.SpellReady(gem)() then
        return true, string.format('Waiting for %s to be ready', spellName)
    end
    mq.cmdf('/cast %d', gem)
    return true, string.format('Casting %s', spellName)
end

-- Summon a pet. Mems the spell into gemNum if needed.
-- reagent is optional — pass nil if the spell needs no reagent.
function spell.castSummonPet(spellName, gemNum, reagent)
    if not mq.TLO.Me.Book(spellName)() then
        return false
    end
    if reagent and not mq.TLO.FindItem(reagent)() then
        return false  -- Missing reagent
    end
    if not spell.isSpellMemmed(spellName) then
        return spell.memorizeSpell(gemNum, spellName)
    end
    return spell.castSpell(spellName)
end

return spell
