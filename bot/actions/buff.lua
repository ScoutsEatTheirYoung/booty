local mq = require('mq')
local utils = require('booty.utils')
local utilActs = require('booty.bot.actions.util')

local buffActions = {}

local function doesTargetNeedBuff(target, spellName, refreshTime)
    -- utils.info(string.format("Checking if target needs buff '%s'.", spellName))
    if not target or not target() then
        -- utils.info(string.format("Target is invalid or not found for buff '%s'.", spellName))
        return false 
    end

    local buff = target.Buff(spellName)
    if not buff() then
        -- utils.info(string.format("Target %s doesnt have %s", target.Name(), spellName)) 
        return true 
    end

    local timeLeft = buff.Duration.TotalSeconds() or 0
    return timeLeft <= refreshTime
end

local function isSpellOnSpellBar(spellName)
    return mq.TLO.Me.Gem(spellName)() ~= nil
end

local function isSpellReady(spellName)
    local gemNum = mq.TLO.Me.Gem(spellName)()
    return gemNum and mq.TLO.Me.SpellReady(gemNum)()
end

---comment
---@param buffList array of {spellName: string, refreshTime: number, targets: array of targets}
---- spellName is the spell name
---- resfreshTime is the minimum time in seconds
---- targets is an array of target 
----- target can be "self", "pet", "group" (which includes group pets) or a player name
---@param spellGem number spell gem to use as the swap in and out
---@return boolean
function buffActions.checkAndBuff(buffList, spellGem)
    if not buffList or #buffList == 0 then return false end
    if not spellGem or spellGem <= 0 then return false end

    -- check if we're currently casting or have the spellbook open
    if mq.TLO.Me.Casting() then return true end
    if mq.TLO.Window('SpellBookWnd').Open() then return true end

    -- lets chug through the list
    for _, currBuff in ipairs(buffList) do
        local spellName, refreshTime, targets = currBuff.spellName, currBuff.refreshTime, currBuff.targets

        -- check if we have the spell, if not, skip
        if not mq.TLO.Me.Book(spellName) then
            utils.fail(string.format('\ar[Bot]\aw Missing spell from book: %s', spellName))
            return false
        end

        -- get the targets list
        local resolvedTargets = utilActs.resolveTargets(targets)
        if #resolvedTargets == 0 then
            utils.info(string.format("No valid targets found for buff '%s'. Skipping.", spellName))
            goto nextbuff
        end

        -- check if any of the targets need the buff
        for _, targetPair in ipairs(resolvedTargets) do
            local targetSpawn, targetLabel = targetPair.spawn, targetPair.label
            --utils.info(string.format("Checking if target '%s' needs buff '%s'.", targetLabel, spellName))
            if not doesTargetNeedBuff(targetSpawn, spellName, refreshTime) then goto nexttarget end
            -- check if spell is on the spell bar, if not, memorize it
            if not isSpellOnSpellBar(spellName) then
                utils.info(string.format("Spell '%s' is not on the spell bar. Memorizing to gem %d.", spellName, spellGem))
                mq.cmd(string.format("/memspell %d %q", spellGem, spellName))
                return true -- action taken, wait for next tick to cast
            end
            -- check if spell is ready to cast if not return
            if not isSpellReady(spellName) then
                utils.info(string.format("Spell '%s' is not ready yet. Waiting.", spellName))
                return true
            end

            -- acquire the target
            if utilActs.acquireTargetSpawn(targetSpawn) then
                -- check if there is a buff that is better than this one
                if not mq.TLO.Spell(spellName).WillLand() then 
                    utils.info(string.format("A stronger version of '%s' is already on target '%s'. Skipping cast.", spellName, targetLabel))
                    goto nexttarget
                end
                -- cast the buff
                utils.info(string.format("Casting '%s' on target '%s'.", spellName, targetSpawn.Name()))
                mq.cmdf('/cast %s', spellName)
                return true 
            end
            
            utils.info(string.format("Failed to acquire target '%s' for buff '%s'.", targetSpawn.Name(), spellName))
            -- cant acquire target, go to next target
            ::nexttarget::
        end

        -- continue jump
        ::nextbuff::
    end
    return false
end

return buffActions