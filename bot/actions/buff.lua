local mq    = require('mq')
local utils = require('booty.utils')
local tgt   = require('booty.bot.actions.target')
local util  = require('booty.bot.actions.util')
local spell = require('booty.bot.actions.spell')

local buff = {}

-- ============================================================
-- Pure checks  (does*)
-- ============================================================

--- True if target spawn needs the buff (missing or expires within refreshTime seconds).
---@param target spawn
---@param spellName string
---@param refreshTime number  seconds
---@return boolean
local function doesTargetNeedBuff(target, spellName, refreshTime)
    if not target or not target() then return false end
    local b = target.Buff(spellName)
    if not b() then return true end
    local timeLeft = (b.Duration and b.Duration.TotalSeconds and b.Duration.TotalSeconds())
    if not timeLeft then return false end  -- duration unreadable (e.g. pet) — buff exists, skip recast
    return timeLeft <= refreshTime
end

-- ============================================================
-- Actors  (cast*)
-- ============================================================

--- Cycle through buffList, one action per tick. Returns true, reason if action taken.
---
--- buffList entry format:
---   { spellName = "Spirit of Wolf", refreshTime = 300, targets = {"group"} }
---
--- targets: "self", "pet", "group" (all members + pets), or a PC name.
--- spellGem: gem slot to use when the spell needs to be memorized.
---@param buffList BuffEntry[]
---@param spellGem integer  Gem slot to use when the spell needs to be memorized
---@return boolean, string
function buff.castBuffList(buffList, spellGem)
    if not buffList or #buffList == 0 then return false, 'Buff list is empty' end
    if not spellGem or spellGem <= 0 then return false, 'Invalid spell gem slot' end

    if mq.TLO.Me.Casting() then
        return true, 'Casting in progress'
    end
    if mq.TLO.Window('SpellBookWnd').Open() then
        return true, 'Spellbook open'
    end

    for _, entry in ipairs(buffList) do
        local spellName   = entry.spellName
        local refreshTime = entry.refreshTime or 0
        local targets     = entry.targets or {}

        if not mq.TLO.Me.Book(spellName)() then
            utils.fail(string.format("Missing spell from book: %s", spellName))
            -- Skip this spell, try the next
        else
            local resolvedTargets = util.resolveTargets(targets)

            for _, t in ipairs(resolvedTargets) do
                if doesTargetNeedBuff(t.spawn, spellName, refreshTime) then
                    local mc, mr = spell.memorizeSpell(spellGem, spellName)
                    if mc then return mc, mr end
                    local gem = spell.findGemForSpell(spellName)
                    if not gem then goto nexttarget end
                    if not mq.TLO.Me.SpellReady(gem)() then
                        return true, string.format("Waiting for %s to be ready", spellName)
                    end

                    -- Target them if not already
                    local switched, switchReason = tgt.targetSpawn(t.spawn)
                    if switched then
                        return true, switchReason  -- Let target land next tick
                    end

                    -- Check stacking before casting
                    if not spell.willLand(spellName) then
                        utils.info(string.format("'%s' won't land on %s, skipping", spellName, t.label))
                        goto nexttarget
                    end

                    mq.cmdf('/cast %d', gem)
                    return true, string.format("Casting '%s' on %s", spellName, t.label)
                end

                ::nexttarget::
            end
        end
    end

    return false, 'All buffs current'
end

return buff
