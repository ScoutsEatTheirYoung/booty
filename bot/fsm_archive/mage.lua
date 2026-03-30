local mq              = require('mq')
local fsm             = require('booty.bot.fsm')
local movementActions = require('booty.bot.bricks.movementActions')
local combatActions   = require('booty.bot.bricks.combatActions')
local combatUtils     = require('booty.bot.bricks.combatUtils')
local idleActions     = require('booty.bot.bricks.idleActions')
local spellActions    = require('booty.bot.bricks.spellActions')
local groupUtils      = require('booty.bot.bricks.groupUtils')

-- ============================================================
-- Mage config
-- Fill in spell names for your level / server.
-- ============================================================
local PET_SPELL   = "Minor Conjuration: Water"
local PET_REAGENT = "Malachite"
local BUFFS = {
    { spellName = "Major Shielding", refreshTime = 600, targets = { "self" } },
    { spellName = "Burnout II",      refreshTime = 600, targets = { "pet" } },
    { spellName = "Inferno Shield",  refreshTime = 60,  targets = { "group", "pet", "self" } },
}

local NUKE_NAME = "Blaze"

local CAST_RANGE  = 50
local LOS_RANGE   = 25
local PULL_RADIUS = 40  -- engage from camp when mob is within this distance

return function(cfg)
    local LEADERNAME  = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    ---@type Point|nil
    local campPoint   = nil
    local CAMP_RADIUS = 15

    local timeLastNonIdleAction = os.clock()
    local IDLE_THRESHOLD        = 5

    local function leaderID()
        local s = mq.TLO.Spawn('pc =' .. LEADERNAME)
        return (s and s() and s.ID()) or 0
    end

    -- ============================================================
    -- State: STARTUP
    -- Summon pet and cast initial buffs, then transition to ESCORT.
    -- ============================================================
    fsm.states["STARTUP"] = {
        onEnter = function()
            mq.cmd('/attack off')
        end,
        execute = function()
            local c, r

            c, r = spellActions.guardCasting(nil)
            if c then return c, r end

            if not combatUtils.hasPet() then
                c, r = spellActions.castSummonPet(PET_SPELL, PET_REAGENT)
                if c then return c, r end
                return true, r or "Waiting to summon pet"
            end

            c, r = idleActions.medAndBuff(BUFFS)
            if c then return c, r end

            fsm.changeState("ESCORT")
            return false, "Setup complete"
        end,
    }

    -- ============================================================
    -- State: MELEE
    -- Assist leader, approach target, pet attacks.
    -- ============================================================
    fsm.states["MELEE"] = {
        execute = function()
            local c, r

            c, r = combatActions.assistPC(leaderID(), false, true)
            if c then return c, r end

            if combatUtils.hasLiveTarget() then
                c, r = movementActions.navToTarget(CAST_RANGE)
                if c then return c, r end
                c, r = spellActions.castAndMem(NUKE_NAME)
                if c then return c, r end
                return false, "In combat — pet attacking"
            end

            combatActions.disengage()
            c, r = movementActions.navFanFollow(leaderID(), myOffset, FOLLOW_DIST)
            if c then return c, r end
            return false, "Holding position near leader"
        end,
        onExit = function()
            combatActions.disengage()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: ASSIST
    -- Follow leader, pet-assist on everything leader engages.
    -- Med and buff when idle.
    -- ============================================================
    fsm.states["ASSIST"] = {
        onEnter = function()
            timeLastNonIdleAction = os.clock()
        end,
        execute = function()
            local c, r

            -- Guard: never interrupt casts (mage has no emergency heal)
            c, r = spellActions.guardCasting(nil)
            if c then return c, r end

            -- Priority 1: assist leader
            c, r = combatActions.assistPC(leaderID(), false, true)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if combatUtils.hasLiveTarget() then
                c, r = movementActions.navForLoS(LOS_RANGE)
                if c then timeLastNonIdleAction = os.clock(); return c, r end

                -- Priority 2: nuke
                c, r = spellActions.castAndMem(NUKE_NAME)
                if c then timeLastNonIdleAction = os.clock(); return c, r end

                return false, "In combat — holding position"
            else
                combatActions.disengage()
            end

            c, r = movementActions.navFanFollow(leaderID(), myOffset, FOLLOW_DIST)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if (os.clock() - timeLastNonIdleAction) >= IDLE_THRESHOLD
                    and not groupUtils.isGroupEngaged() then
                c, r = idleActions.medAndBuff(BUFFS)
                if c then return c, r end
            end

            return false, "Walking with " .. LEADERNAME
        end,
        onExit = function()
            mq.cmd('/stand')
            combatActions.disengage()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: CAMP
    -- Snap camp, idle (med/buff) until combat reaches camp.
    -- Engages when: non-leader is pulled to camp, OR leader pulls within PULL_RADIUS.
    -- ============================================================
    fsm.states["CAMP"] = {
        onEnter = function()
            mq.cmd('/attack off')
            mq.cmd('/squelch /pet back off')
            local alpha = mq.TLO.Spawn('pc =' .. LEADERNAME)
            if alpha() then
                campPoint = { y = alpha.Y(), x = alpha.X() }
            end
        end,
        execute = function()
            local c, r

            -- Guard: never interrupt casts (mage has no emergency heal)
            c, r = spellActions.guardCasting(nil)
            if c then return c, r end

            if groupUtils.isCampEngaged(leaderID(), campPoint, PULL_RADIUS) then
                c, r = combatActions.assistPC(leaderID(), false, true)
                if c then return c, r end

                if combatUtils.hasLiveTarget() then
                    c, r = movementActions.navForLoS(LOS_RANGE)
                    if c then return c, r end

                    c, r = spellActions.castAndMem(NUKE_NAME)
                    if c then return c, r end

                    return false, "Defending camp"
                else
                    combatActions.disengage()
                end
            end

            if campPoint then
                c, r = movementActions.navToPoint(campPoint, CAMP_RADIUS)
                if c then return c, r end
            end

            c, r = idleActions.medAndBuff(BUFFS)
            if c then return c, r end

            return false, "Holding camp"
        end,
        onExit = function()
            mq.cmd('/stand')
            combatActions.disengage()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: BUFFTEST
    -- ============================================================
    fsm.states["BUFFTEST"] = {
        execute = function()
            local c, r
            c, r = spellActions.guardCasting(nil)
            if c then return c, r end
            c, r = idleActions.medAndBuff(BUFFS)
            if c then return c, r end
            return false, "All buffs current"
        end,
    }
end
