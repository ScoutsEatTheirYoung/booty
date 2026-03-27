local mq              = require('mq')
local fsm             = require('booty.bot.fsm')
local movementActions = require('booty.bot.bricks.movementActions')
local combatActions   = require('booty.bot.bricks.combatActions')
local combatUtils     = require('booty.bot.bricks.combatUtils')
local healActions     = require('booty.bot.bricks.healActions')
local idleActions     = require('booty.bot.bricks.idleActions')
local spellActions    = require('booty.bot.bricks.spellActions')
local groupUtils      = require('booty.bot.bricks.groupUtils')

-- ============================================================
-- Shaman config
-- Fill in spell names for your level / server.
-- ============================================================
local BUFFS = {
    { spellName = "Inner Fire",       refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Raging Strength",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Rising Dexterity", refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Nimble",           refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Health",           refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Shifting Shield",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Regeneration",     refreshTime = 60,  targets = { "self", "group" } },
    { spellName = "Quickness",        refreshTime = 60,  targets = { "self", "group" } },
    { spellName = "Talisman of Tnarg", refreshTime = 600, targets = { "self", "group" } },
}
local HEAL_NAME          = "Greater Healing"
local HEAL_PCT           = 80
local HEAL_EMERGENCY_PCT = 60

local NUKE_NAME = "Winter's Roar"

local CAST_RANGE  = 50
local LOS_RANGE   = 25
local PULL_RADIUS = 40  -- engage from camp when mob is within this distance

return function(cfg)
    local LEADER      = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    ---@type Point|nil
    local campPoint   = nil
    local CAMP_RADIUS = 15

    local timeLastNonIdleAction = os.clock()
    local IDLE_THRESHOLD        = 5

    local function leaderID()
        local s = mq.TLO.Spawn('pc =' .. LEADER)
        return (s and s() and s.ID()) or 0
    end

    -- ============================================================
    -- State: STARTUP
    -- Cast initial buffs, then transition to ESCORT.
    -- ============================================================
    fsm.states["STARTUP"] = {
        onEnter = function()
            mq.cmd('/attack off')
        end,
        execute = function()
            local c, r
            c, r = spellActions.guardCasting(nil)
            if c then return c, r end
            c, r = idleActions.medAndBuff(BUFFS)
            if c then return c, r end
            fsm.changeState("ESCORT")
            return false, "Setup complete"
        end,
    }

    -- ============================================================
    -- State: MELEE
    -- Assist leader, approach target, cast when opportunities arise.
    -- ============================================================
    fsm.states["MELEE"] = {
        execute = function()
            local c, r

            c, r = combatActions.assistPC(leaderID(), false, false)
            if c then return c, r end

            if combatUtils.hasLiveTarget() then
                c, r = movementActions.navToTarget(CAST_RANGE)
                if c then return c, r end
                return false, "In combat — waiting for spell opportunities"
            end

            local count = mq.TLO.Group.Members() or 0
            for i = 1, count do
                local m = mq.TLO.Group.Member(i)
                if m and m.Name() and (m.PctHPs() or 100) < HEAL_PCT then
                    return false, string.format("Waiting to heal %s (%d%%)", m.Name(), m.PctHPs())
                end
            end

            combatActions.disengage()
            c, r = movementActions.navFanFollow(leaderID(), myOffset, FOLLOW_DIST)
            if c then return c, r end
            return false, "Holding position near leader"
        end,
        onExit = function()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: ASSIST
    -- Follow leader, assist on everything leader engages.
    -- Heal/cure between and during fights. Med and buff when idle.
    -- ============================================================
    fsm.states["ASSIST"] = {
        onEnter = function()
            mq.cmd('/attack off')
            timeLastNonIdleAction = os.clock()
        end,
        execute = function()
            local c, r

            -- Guard: keep casting unless someone needs an emergency heal
            c, r = spellActions.guardCasting(HEAL_EMERGENCY_PCT)
            if c then return c, r end

            -- Priority 1: heal
            c, r = healActions.healGroup(HEAL_NAME, HEAL_PCT, HEAL_EMERGENCY_PCT, leaderID())
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            -- Priority 2: cure disease / poison (full group + pets)
            -- c, r = buffActions.cureGroupDebuffs(CURE_DISEASE, CURE_POISON, CURE_GEM)
            -- if c then timeLastNonIdleAction = os.clock(); return c, r end

            -- Priority 3: assist leader
            c, r = combatActions.assistPC(leaderID(), false, false)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if combatUtils.hasLiveTarget() then
                c, r = movementActions.navForLoS(LOS_RANGE)
                if c then timeLastNonIdleAction = os.clock(); return c, r end

                -- Priority 4: nuke
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

            return false, "Walking with " .. LEADER
        end,
        onExit = function()
            mq.cmd('/stand')
            mq.cmd('/squelch /nav stop')
            mq.cmd('/attack off')
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
            local alpha = mq.TLO.Spawn('pc =' .. LEADER)
            if alpha() then
                campPoint = { y = alpha.Y(), x = alpha.X() }
            end
        end,
        execute = function()
            local c, r

            -- Guard: keep casting unless someone needs an emergency heal
            c, r = spellActions.guardCasting(HEAL_EMERGENCY_PCT)
            if c then return c, r end

            -- Heals and cures always run regardless of combat state
            c, r = healActions.healGroup(HEAL_NAME, HEAL_PCT, HEAL_EMERGENCY_PCT, leaderID())
            if c then return c, r end

            -- c, r = buffActions.cureGroupDebuffs(CURE_DISEASE, CURE_POISON, CURE_GEM)
            -- if c then return c, r end

            if groupUtils.isCampEngaged(leaderID(), campPoint, PULL_RADIUS) then
                c, r = combatActions.assistPC(leaderID(), false, false)
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
            mq.cmd('/squelch /nav stop')
            mq.cmd('/attack off')
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
