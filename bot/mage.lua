local mq    = require('mq')
local fsm   = require('booty.bot.fsm')
local move  = require('booty.bot.actions.movement')
local melee = require('booty.bot.actions.melee')
local buff  = require('booty.bot.actions.buff')
local util  = require('booty.bot.actions.util')
local spell = require('booty.bot.actions.spell')

-- ============================================================
-- Mage config
-- Fill in spell names for your level / server.
-- ============================================================
local PET_SPELL   = "Summon Companion"
local PET_REAGENT = "Malachite"
local PET_GEM     = 1

local BUFFS = {
    { spellName = "Minor Shielding", refreshTime = 1800, targets = { "self" } },
}

local CAST_RANGE = 50

return function(cfg)
    local LEADER      = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    local lastLeaderTargetID = 0

    -- ============================================================
    -- State: SETUP
    -- ============================================================
    fsm.states["SETUP"] = {
        onEnter = function()
            mq.cmd('/attack off')
        end,
        execute = function()
            local c, r

            if not melee.hasPet() then
                c, r = spell.castSummonPet(PET_SPELL, PET_GEM, PET_REAGENT)
                if c then return c, r end
                return false, "Waiting to summon pet"
            end

            c, r = buff.castBuffList(BUFFS, 8)
            if c then return c, r end

            fsm.changeState("FOLLOW")
            return false, "Setup complete"
        end,
    }

    -- ============================================================
    -- State: MELEE
    -- ============================================================
    fsm.states["MELEE"] = {
        onEnter = function()
            lastLeaderTargetID = 0
        end,
        execute = function()
            local c, r

            local leaderTarget   = util.getPcTarget(LEADER)
            local leaderTargetID = leaderTarget and leaderTarget.ID() or 0
            if leaderTargetID ~= lastLeaderTargetID then
                lastLeaderTargetID = leaderTargetID
                if leaderTargetID > 0 then
                    c, r = util.targetSpawn(leaderTarget)
                    if c then return c, r end
                end
            end

            if melee.hasLiveTarget() then
                local target = mq.TLO.Target
                melee.sendPet(target.ID())

                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end

                -- TODO: c, r = spell.castSpell("Shock of Spikes"); if c then return c, r end
                return false, "In combat — pet attacking"

            else
                melee.combatOff()
                c, r = move.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
                if c then return c, r end
                return false, "Holding position near leader"
            end
        end,
        onExit = function()
            melee.combatOff()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: BUFFTEST
    -- ============================================================
    fsm.states["BUFFTEST"] = {
        execute = function()
            local c, r = buff.castBuffList(BUFFS, 8)
            if c then return c, r end
            return false, "All self buffs current"
        end,
    }
end
