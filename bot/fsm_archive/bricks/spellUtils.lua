local mq = require('mq')

local spellUtils = {}

-- ============================================================
-- Gem slot scoring
-- Each cast increments a gem's score (higher = more used = keep it).
-- Each mem resets a gem's score to 0 (freshly loaded = low priority).
-- nextGem() finds the lowest-scoring gem(s) and picks randomly among ties,
-- so frequently cast spells stay on the bar while idle gems get evicted.
-- Initialized lazily so Me.NumGems() is valid at call time.
-- ============================================================
---@type integer[]
local _gemScores = {}

local function initScores()
    if #_gemScores > 0 then return end
    local n = mq.TLO.Me.NumGems() or 12
    for i = 1, n do _gemScores[i] = 0 end
end

--- Return the gem slot to evict for the next mem.
--- Picks randomly among all gems tied at the lowest score.
---@return integer
function spellUtils.nextGem()
    initScores()
    local minScore = math.huge
    for _, s in ipairs(_gemScores) do
        if s < minScore then minScore = s end
    end
    local candidates = {}
    for gem, s in ipairs(_gemScores) do
        if s == minScore then table.insert(candidates, gem) end
    end
    return candidates[math.random(#candidates)]
end

--- Call after issuing /cast to register use of that gem slot.
---@param gem integer
function spellUtils.onCastGem(gem)
    initScores()
    if _gemScores[gem] ~= nil then _gemScores[gem] = _gemScores[gem] + 1 end
end

--- Call after issuing /memspell to reset that gem slot's score.
---@param gem integer
function spellUtils.onMemGem(gem)
    initScores()
    if _gemScores[gem] ~= nil then _gemScores[gem] = 0 end
end

-- ============================================================
-- Fizzle tracking
-- ============================================================
local FIZZLE_BACKOFF = 0.2  -- seconds to back off after a fizzle
local lastFizzleTime = 0

mq.event('SpellFizzle', '#*#Your spell fizzles#*#', function()
    lastFizzleTime = os.clock()
end)

---@return boolean
function spellUtils.justFizzled()
    return (os.clock() - lastFizzleTime) < FIZZLE_BACKOFF
end

-- ============================================================
-- Pure checks  (is* / has* / find* / get*)
-- ============================================================

--- Iterate gem slots 1-12 and return the slot number if spellName is memmed, else nil.
---@param spellName string
---@return integer|nil
function spellUtils.findGemForSpell(spellName)
    for i = 1, 12 do
        if mq.TLO.Me.Gem(i)() == spellName then
            return i
        end
    end
    return nil
end

---@param spellName string
---@return boolean
function spellUtils.isSpellMemmed(spellName)
    return spellUtils.findGemForSpell(spellName) ~= nil
end

--- True if spellName appears in any gem slot on the spell bar.
---@param spellName string
---@return boolean
function spellUtils.isOnBar(spellName)
    return spellUtils.findGemForSpell(spellName) ~= nil
end

---@param spellName string
---@return boolean
function spellUtils.isSpellReady(spellName)
    local gem = spellUtils.findGemForSpell(spellName)
    if not gem then return false end
    return mq.TLO.Me.SpellReady(gem)() == true
end

---@param spellName string
---@return boolean
function spellUtils.hasManaForSpell(spellName)
    local cost = mq.TLO.Spell(spellName).Mana() or 0
    return mq.TLO.Me.CurrentMana() >= cost
end

return spellUtils
