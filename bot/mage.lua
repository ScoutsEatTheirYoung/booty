local mq    = require('mq')
local fsm   = require('booty.bot.fsm')
local move  = require('booty.bot.actions.movement')
local melee = require('booty.bot.actions.melee')
local buff  = require('booty.bot.actions.buff')
local util  = require('booty.bot.actions.util')
local spell = require('booty.bot.actions.spell')
local group = require('booty.bot.actions.group')

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

local NUKE_NAME = ""

local CAST_RANGE = 50

return function(cfg)
    local LEADERNAME  = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    local lastLeaderTargetID = 0
    ---@type Point|nil
    local campPoint = nil
    local CAMP_RADIUS = 15

    local timeLastNonIdleAction = os.clock()
    local IDLE_THRESHOLD        = 5  -- seconds before sitting to med

    -- Sit/med and check buff uptimes. Call when the group is idle.
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

            local leaderTarget   = util.getPcTarget(LEADERNAME)
            local leaderTargetID = leaderTarget and leaderTarget.ID() or 0
            if leaderTargetID ~= lastLeaderTargetID then
                lastLeaderTargetID = leaderTargetID
                if leaderTargetID > 0 then
                    c, r = util.targetByID(leaderTargetID)
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
                c, r = move.navFanFollow(LEADERNAME, myOffset, FOLLOW_DIST)
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
    -- State: FOLLOWANDEXP
    -- Follow Alpha and assist on everything Alpha attacks.
    -- ============================================================
    fsm.states["FOLLOWANDEXP"] = {
        onEnter = function()
            lastLeaderTargetID = 0
            timeLastNonIdleAction     = os.clock()
        end,
        execute = function()
            local c, r

            local assistTarget = melee.getAssistTarget(LEADERNAME)
            local assistID     = assistTarget and assistTarget.ID() or 0
            if assistID ~= lastLeaderTargetID then
                lastLeaderTargetID = assistID
                if assistID > 0 then
                    timeLastNonIdleAction = os.clock()
                    c, r = util.targetByID(assistID)
                    if c then return c, r end
                end
            end

            if melee.hasLiveTarget() then
                timeLastNonIdleAction = os.clock()

                if mq.TLO.Me.Sitting() then
                    mq.cmd('/stand')
                    return true, 'Standing up'
                end

                melee.sendPet(mq.TLO.Target.ID())

                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end

                -- TODO: c, r = spell.castSpell(NUKE_NAME); if c then return c, r end
                return false, "In combat — pet attacking"

            else
                melee.combatOff()

                c, r = move.navFanFollow(LEADERNAME, myOffset, FOLLOW_DIST)
                if c then
                    timeLastNonIdleAction = os.clock()
                    if mq.TLO.Me.Sitting() then
                        mq.cmd('/stand')
                        return true, 'Standing up to follow'
                    end
                    return c, r
                end

                -- In range and not moving — check if idle long enough to med
                if (os.clock() - timeLastNonIdleAction) >= IDLE_THRESHOLD
                        and not group.isGroupEngaged() then
                    c, r = doIdleTasks()
                    if c then return c, r end
                end

                if mq.TLO.Me.Sitting() then
                    mq.cmd('/stand')
                    return true, 'Standing up'
                end

                return false, "Walking with " .. LEADERNAME
            end
        end,
        onExit = function()
            mq.cmd('/stand')
            melee.combatOff()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: MAKECAMPANDEXP
    -- Snap camp position on enter, hold it, assist when Alpha pulls,
    -- return to camp after each kill.
    -- ============================================================
    fsm.states["MAKECAMPANDEXP"] = {
        onEnter = function()
            lastLeaderTargetID = 0
            local alpha = mq.TLO.Spawn('pc =' .. LEADERNAME)
            if alpha() then
                campPoint = { y = alpha.Y(), x = alpha.X() }
            end
        end,
        execute = function()
            local c, r

            local assistTarget = melee.getAssistTarget(LEADERNAME)
            local assistID     = assistTarget and assistTarget.ID() or 0
            if assistID ~= lastLeaderTargetID then
                lastLeaderTargetID = assistID
                if assistID > 0 then
                    c, r = util.targetByID(assistID)
                    if c then return c, r end
                end
            end

            if melee.hasLiveTarget() then
                melee.sendPet(mq.TLO.Target.ID())

                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end

                -- TODO: c, r = spell.castSpell(NUKE_NAME); if c then return c, r end
                return false, "In combat — pet attacking"

            else
                melee.combatOff()

                if campPoint then
                    c, r = move.navToPoint(campPoint, CAMP_RADIUS)
                    if c then return c, r end
                end

                return false, "Holding camp"
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
            local c, r = doIdleTasks()
            if c then return c, r end
            return false, "All buffs current"
        end,
    }
end
