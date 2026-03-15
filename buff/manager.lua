local mq = require('mq')
local utils = require('booty.utils')
local config = require('booty.config')

local BuffManager = {}

function BuffManager.hasPet()
    return mq.TLO.Me.Pet.ID() ~= 0 and mq.TLO.Me.Pet.ID() ~= nil
end

function BuffManager.acquireTarget(targetName)
    local cfg = config.get().buff
    if targetName == "self" then
        -- Target yourself directly instead of trying to clear your target
        mq.TLO.Me.DoTarget()
        mq.delay(cfg.target_timeout, function() return mq.TLO.Target.ID() == mq.TLO.Me.ID() end)

    elseif targetName == "pet" then
        if mq.TLO.Me.Pet.ID() > 0 then
            mq.TLO.Me.Pet.DoTarget()
            mq.delay(cfg.target_timeout, function() return mq.TLO.Target.ID() == mq.TLO.Me.Pet.ID() end)
        end

    else
        -- Search memory for an exact PC name match (=Name)
        local spawn = mq.TLO.Spawn(string.format("pc =%s", targetName))

        if spawn() then
            spawn.DoTarget()
            mq.delay(cfg.target_timeout, function() return mq.TLO.Target.CleanName() == targetName end)
        else
            -- If the target isn't in the zone, print a warning to your MQ console
            printf("\ag[Booty Buff]\ar Target '%s' not found in zone.", targetName)
        end
    end
end

function BuffManager.swapAndCast(spellName, targetName, gemNum)
    utils.info(string.format("Preparing to cast '%s' on '%s' using gem %d.", spellName, targetName, gemNum))
    local cfg = config.get().buff
    local spell = mq.TLO.Spell(spellName)

    -- 1. Pre-Flight Math: Do we have the mana? Does the spell even exist?
    if not spell() or mq.TLO.Me.CurrentMana() < spell.Mana() then
        utils.info(string.format("Cannot cast '%s'. Spell not found or insufficient mana.", spellName))
        return -- Exit immediately. The loop will naturally try again next tick.
    end

    local isMemmed = mq.TLO.Me.Gem(spellName)() ~= nil

    -- 2. Scribe or Cooldown Check
    if not isMemmed then
        --utils.info(string.format("'%s' is not currently memorized. Attempting to scribe into gem %d.", spellName, gemNum))
        mq.cmd(string.format("/memspell %d %q", gemNum, spellName))

        -- Wait for it to populate in the gem slot
        mq.delay(cfg.memorize_timeout, function() return mq.TLO.Me.Gem(gemNum)() == spellName end)
        --utils.info(string.format("'%s' is now memorized in gem %d.", spellName, gemNum))

    else
        -- If it was already memorized, ensure the gem isn't greyed out from a previous cast
        gemNum = mq.TLO.Me.Gem(spellName)()
        --utils.info(string.format("'%s' is already memorized in gem %d. Checking if it's ready to cast.", spellName, gemNum))
        if not gemNum then
            return -- This should never happen, but if it does, exit to prevent errors.
        end
    end

    --utils.info(string.format("Waiting for '%s' in gem %d to be ready to cast.", spellName, gemNum))
    mq.delay(cfg.ready_timeout, function() return mq.TLO.Me.SpellReady(gemNum)() end)
    --utils.info(string.format("'%s' in gem %d is ready to cast.", spellName, gemNum))

    if targetName ~= "pet_summon" then
        BuffManager.acquireTarget(targetName)
    else
        utils.info("Casting a pet summon. No target acquisition necessary.")
    end

    utils.info(string.format("Casting '%s' from gem %d on target '%s'.", spellName, gemNum, targetName))
    mq.cmd(string.format("/cast %q", spellName))

    -- Give the server time to confirm we started casting
    mq.delay(cfg.cast_start_timeout, function() return mq.TLO.Me.Casting() ~= nil end)

    --utils.info(string.format("Cast command issued for '%s'. Waiting for cast to complete.", spellName))

    -- ONLY wait for the cast to finish if the casting bar actually appeared.
    -- If we fizzled or got instantly bashed, this skips the wait and recovers immediately.
    if mq.TLO.Me.Casting() then
        mq.delay(cfg.cast_complete_timeout, function() return not mq.TLO.Me.Casting() end)
    end
end

-- Self vs Pets vs Others gets buffs in slightly different ways, so we have to check them differently. 
-- This function abstracts that away and just returns true/false if the buff needs to be cast.
-- This function takes in 3 parameters: 
-- the target type ("self", "pet", or a specific target name), the buff name, 
-- and an optional minimum duration threshold (in seconds) to determine if we should re-cast the buff before it expires.
function BuffManager.needBuff(targetName, buffName, minDuration)
    minDuration = minDuration or config.get().buff.rebuff_threshold
    utils.info(string.format("Checking if %s needs buff '%s' with at least %d seconds remaining.", targetName, buffName, minDuration))
    local buffDuration = 0
    if targetName == "self" then
        local buff = mq.TLO.Me.Buff(buffName)
        if buff() and buff.Duration then
            buffDuration = buff.Duration.TotalSeconds()
        end
    elseif targetName == "pet" then
        local pet = mq.TLO.Me.Pet
        if pet() == 'NO PET' then
            utils.info("No pet found when checking buffs. Returning false.")
            return false
        end
        buffDuration = pet.BuffDuration(buffName)()
        if not buffDuration then
            utils.info(string.format("Buff '%s' not found on pet. Returning true.", buffName))
            return true
        end
        if buffDuration > 0 then
            buffDuration = buffDuration / 1000 -- Convert from ms to seconds
        end
    else
        local spawn = mq.TLO.Spawn(string.format("pc %s", targetName))
        if not spawn() then
            utils.info(string.format("Target '%s' not found when checking buffs. Returning false.", targetName))
            return false
        end
        return true -- getting buff duration on other players is unreliable, so if they exist, just assume they need the buff
    end
    utils.info(string.format("Buff '%s' on '%s' has %d seconds remaining.", buffName, targetName, buffDuration))
    return buffDuration < minDuration
end


function BuffManager.checkAndCast(buff_list, gem)
    local originalSpell = mq.TLO.Me.Gem(gem)()

    for _, buff in ipairs(buff_list) do
        -- Iterate through the new targets array
        for _, targetName in ipairs(buff.targets) do
            utils.info(string.format("%s : %s", buff.name, targetName))
            if targetName == "pet_summon" then
                if not BuffManager.hasPet() then
                    BuffManager.swapAndCast(buff.name, targetName, gem) -- Scribe and cast the summon
                end
            else
                -- Verify pet exists before checking its buffs
                if targetName == "pet" and not BuffManager.hasPet() then
                    -- Skip
                elseif BuffManager.needBuff(targetName, buff.name) then
                    utils.info(string.format("'%s' does not have buff '%s'. Casting now.", targetName, buff.name))
                    BuffManager.swapAndCast(buff.name, targetName, gem)
                end
            end
            
        end
    end
    mq.cmd(string.format("/memspell %d %q", gem, originalSpell))
end

return BuffManager