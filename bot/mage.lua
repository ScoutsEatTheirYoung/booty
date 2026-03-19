local mq            = require('mq')
local fsm           = require('booty.bot.fsm')
local movementActions = require('booty.bot.bricks.movementActions')
local combatActions = require('booty.bot.bricks.combatActions')
local combatUtils   = require('booty.bot.bricks.combatUtils')
local buffActions   = require('booty.bot.bricks.buffActions')
local spellActions  = require('booty.bot.bricks.spellActions')
local groupUtils    = require('booty.bot.bricks.groupUtils')

-- ============================================================
-- Mage config
-- Fill in spell names for your level / server.
-- ============================================================
local PET_SPELL   = "Minor Summoning: Water"
local PET_REAGENT = "Malachite"
local PET_GEM     = 2

local BUFFS = {
    { spellName = "Lesser Shielding", refreshTime = 600, targets = { "self" } },
    { spellName = "Burnout", refreshTime = 600, targets = { "pet" } },
    { spellName = "Shield of Fire", refreshTime = 60, targets = { "group", "pet", "self" } },
}

local NUKE_NAME = "Shock of Flame"  -- e.g. "Shock of Spikes"
local NUKE_GEM  = 1   -- gem slot to hold the nuke

local CAST_RANGE = 50

return function(cfg)
    local LEADERNAME  = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    ---@type Point|nil
    local campPoint = nil
    local CAMP_RADIUS = 15

    local timeLastNonIdleAction = os.clock()
    local IDLE_THRESHOLD        = 5  -- seconds before sitting to med

    ---@return boolean, string
    local function doIdleTasks()
        local pctMana = mq.TLO.Me.PctMana() or 100
        if not mq.TLO.Me.Sitting() and pctMana < 100 then
            mq.cmd('/sit')
            return true, 'Sitting to med'
        end
        local c, r = buffActions.castBuffList(BUFFS, 8)
        if c then return c, r end
        return false, string.format('Medding (%d%% mana)', pctMana)
    end

    -- ============================================================
    -- State: SETUP
    -- Summon pet and cast initial buffs, then transition to FOLLOW.
    -- ============================================================
    fsm.states["SETUP"] = {
        onEnter = function()
            mq.cmd('/attack off')
        end,
        execute = function()
            local c, r

            if not combatUtils.hasPet() then
                c, r = spellActions.castSummonPet(PET_SPELL, PET_GEM, PET_REAGENT)
                if c then return c, r end
                return false, r or "Waiting to summon pet"
            end

            c, r = buffActions.castBuffList(BUFFS, 8)
            if c then return c, r end

            fsm.changeState("FOLLOW")
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

            c, r = combatActions.assistPC(LEADERNAME, false, true)
            if c then return c, r end

            if combatUtils.hasLiveTarget() then
                c, r = movementActions.navToTarget(CAST_RANGE)
                if c then return c, r end
                c, r = spellActions.castSpellInGem(NUKE_NAME, NUKE_GEM)
                if c then return c, r end
                return false, "In combat — pet attacking"
            end

            combatActions.disengage()
            c, r = movementActions.navFanFollow(LEADERNAME, myOffset, FOLLOW_DIST)
            if c then return c, r end
            return false, "Holding position near leader"
        end,
        onExit = function()
            combatActions.disengage()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: FOLLOWANDEXP
    -- Follow leader, pet-assist on everything leader engages.
    -- Med and buff when idle.
    -- ============================================================
    fsm.states["FOLLOWANDEXP"] = {
        onEnter = function()
            timeLastNonIdleAction = os.clock()
        end,
        execute = function()
            local c, r

            c, r = combatActions.assistPC(LEADERNAME, false, true)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if combatUtils.hasLiveTarget() then
                c, r = spellActions.castSpellInGem(NUKE_NAME, NUKE_GEM)
                if c then timeLastNonIdleAction = os.clock(); return c, r end
            else
                combatActions.disengage()
            end

            c, r = movementActions.navFanFollow(LEADERNAME, myOffset, FOLLOW_DIST)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if (os.clock() - timeLastNonIdleAction) >= IDLE_THRESHOLD
                    and not groupUtils.isGroupEngaged() then
                c, r = doIdleTasks()
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
    -- State: MAKECAMPANDEXP
    -- Snap camp at leader's position, hold it, assist when leader pulls.
    -- ============================================================
    fsm.states["MAKECAMPANDEXP"] = {
        onEnter = function()
            local alpha = mq.TLO.Spawn('pc =' .. LEADERNAME)
            if alpha() then
                campPoint = { y = alpha.Y(), x = alpha.X() }
            end
        end,
        execute = function()
            local c, r

            c, r = combatActions.assistPC(LEADERNAME, false, true)
            if c then return c, r end

            if not combatUtils.hasLiveTarget() then combatActions.disengage() end

            if campPoint then
                c, r = movementActions.navToPoint(campPoint, CAMP_RADIUS)
                if c then return c, r end
            end

            return false, "Holding camp"
        end,
        onExit = function()
            combatActions.disengage()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: BUFFTEST
    -- ============================================================
    fsm.states["BUFFTEST"] = {
        execute = function()
            local c, r = doIdleTasks()
            if c then return c, r end
            return false, "All buffs current"
        end,
    }
end
