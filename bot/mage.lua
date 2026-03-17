local mq     = require('mq')
local fsm    = require('booty.bot.fsm')
local move   = require('booty.bot.actions.movement')
local combat = require('booty.bot.actions.combat')
local buff   = require('booty.bot.actions.buff')
local spell  = require('booty.bot.actions.spell')
local group  = require('booty.bot.actions.group')

-- ============================================================
-- Mage config
-- Fill in spell names for your level / server.
-- ============================================================
local PET_SPELL   = "Elementalkin: Water"
local PET_REAGENT = "Malachite"
local PET_GEM     = 1

local BUFFS = {
    { spellName = "Minor Shielding", refreshTime = 600, targets = { "self" } },
}

local NUKE_NAME = ""  ---@diagnostic disable-line: unused-local

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
        local c, r = buff.castBuffList(BUFFS, 8)
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

            if not combat.hasPet() then
                c, r = spell.castSummonPet(PET_SPELL, PET_GEM, PET_REAGENT)
                if c then return c, r end
                return false, r or "Waiting to summon pet"
            end

            c, r = buff.castBuffList(BUFFS, 8)
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

            c, r = combat.assistLeader(LEADERNAME, false, true)
            if c then return c, r end

            if combat.hasLiveTarget() then
                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end
                -- TODO: c, r = spell.castSpell("Shock of Spikes"); if c then return c, r end
                return false, "In combat — pet attacking"
            end

            combat.disengage()
            c, r = move.navFanFollow(LEADERNAME, myOffset, FOLLOW_DIST)
            if c then return c, r end
            return false, "Holding position near leader"
        end,
        onExit = function()
            combat.disengage()
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

            c, r = combat.assistLeader(LEADERNAME, false, true)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            combat.disengage()

            c, r = move.navFanFollow(LEADERNAME, myOffset, FOLLOW_DIST)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if (os.clock() - timeLastNonIdleAction) >= IDLE_THRESHOLD
                    and not group.isGroupEngaged() then
                c, r = doIdleTasks()
                if c then return c, r end
            end

            return false, "Walking with " .. LEADERNAME
        end,
        onExit = function()
            mq.cmd('/stand')
            combat.disengage()
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

            c, r = combat.assistLeader(LEADERNAME, false, true)
            if c then return c, r end

            combat.disengage()

            if campPoint then
                c, r = move.navToPoint(campPoint, CAMP_RADIUS)
                if c then return c, r end
            end

            return false, "Holding camp"
        end,
        onExit = function()
            combat.disengage()
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
