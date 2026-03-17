local mq     = require('mq')
local fsm    = require('booty.bot.fsm')
local move   = require('booty.bot.actions.movement')
local combat = require('booty.bot.actions.combat')
local buff   = require('booty.bot.actions.buff')
local spell  = require('booty.bot.actions.spell')
local tgt    = require('booty.bot.actions.target')
local group  = require('booty.bot.actions.group')

-- ============================================================
-- Shaman config
-- Fill in spell names for your level / server.
-- ============================================================
local BUFFS = {
    { spellName = "Inner Fire",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Strengthen",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Dexterous Aura",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Feet like Cat",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Spirit of Bear",  refreshTime = 600, targets = { "self", "group" } },
}

local HEAL_NAME          = "Light Healing"   -- e.g. "Minor Healing"
local HEAL_GEM           = 2    -- gem slot to hold the heal
local HEAL_PCT           = 80   -- heal when HP drops below this % (out of combat)
local HEAL_EMERGENCY_PCT = 60   -- heal when HP drops below this % (in combat)

local NUKE_NAME = "Frost Rift"   -- e.g. "Frost Rift"
local NUKE_GEM  = 3    -- gem slot to hold the nuke
local NUKE_MANA = 80   -- only nuke when above this % mana

local CAST_RANGE = 50

return function(cfg)
    local LEADER      = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    ---@type Point|nil
    local campPoint = nil
    local CAMP_RADIUS = 15

    local timeLastNonIdleAction = os.clock()
    local IDLE_THRESHOLD        = 5  -- seconds before sitting to med

    --- Check leader first, then group members, heal the first one below HEAL_PCT.
    --- Targets them if needed (one step), then casts.
    ---@return boolean, string
    local function doHealCheck()
        if not HEAL_NAME or HEAL_NAME == "" then return false, "No heal configured" end

        -- Always keep heal memmed — if not on bar, mem it now before anything else
        if not spell.isOnBar(HEAL_NAME) then
            return spell.memorizeSpell(HEAL_GEM, HEAL_NAME)
        end

        local threshold = group.isGroupEngaged() and HEAL_EMERGENCY_PCT or HEAL_PCT

        local function tryHeal(spawn, name)
            if not spawn or not spawn() then return false, "" end
            if (spawn.PctHPs() or 100) >= threshold then return false, "" end
            local c = tgt.targetSpawn(spawn)
            if c then return true, string.format("Targeting %s to heal", name) end
            c = spell.castSpellInGem(HEAL_NAME, HEAL_GEM)
            if c then return true, string.format("Healing %s (%d%%)", name, spawn.PctHPs() or 0) end
            return false, ""
        end

        -- Leader first
        local c, r = tryHeal(mq.TLO.Spawn('pc =' .. LEADER), LEADER)
        if c then return c, r end

        -- Then group members
        local count = mq.TLO.Group.Members() or 0
        for i = 1, count do
            local m = mq.TLO.Group.Member(i)
            if m and m.Name() and m.Name() ~= mq.TLO.Me.Name() then
                c, r = tryHeal(m.Spawn, m.Name())
                if c then return c, r end
            end
        end

        -- Self last
        c, r = tryHeal(mq.TLO.Me, mq.TLO.Me.Name() or 'self')
        if c then return c, r end

        return false, "No heal needed"
    end

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
    -- Cast initial buffs, then transition to FOLLOW.
    -- ============================================================
    fsm.states["SETUP"] = {
        onEnter = function()
            mq.cmd('/attack off')
        end,
        execute = function()
            local c, r

            c, r = buff.castBuffList(BUFFS, 8)
            if c then return c, r end

            fsm.changeState("FOLLOW")
            return false, "Setup complete"
        end,
    }

    -- ============================================================
    -- State: MELEE
    -- Assist leader, approach target, cast when opportunities arise.
    -- Heal between pulls.
    -- ============================================================
    fsm.states["MELEE"] = {
        execute = function()
            local c, r

            c, r = combat.assistPc(LEADER, false, false)
            if c then return c, r end

            if combat.hasLiveTarget() then
                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end
                -- TODO: c, r = spell.castSpell("slow"); if c then return c, r end
                -- TODO: c, r = spell.castSpell("DoT");  if c then return c, r end
                return false, "In combat — waiting for spell opportunities"
            end

            local count = mq.TLO.Group.Members() or 0
            for i = 1, count do
                local m = mq.TLO.Group.Member(i)
                if m and m.Name() and (m.PctHPs() or 100) < HEAL_PCT then
                    -- TODO: c, r = spell.castHeal(...); if c then return c, r end
                    return false, string.format("Waiting to heal %s (%d%%)", m.Name(), m.PctHPs())
                end
            end

            combat.disengage()
            c, r = move.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
            if c then return c, r end
            return false, "Holding position near leader"
        end,
        onExit = function()
            mq.cmd('/squelch /nav stop')
        end,
    }

    -- ============================================================
    -- State: FOLLOWANDEXP
    -- Follow leader, assist on everything leader engages.
    -- Med and buff when idle.
    -- ============================================================
    fsm.states["FOLLOWANDEXP"] = {
        onEnter = function()
            mq.cmd('/attack off')
            timeLastNonIdleAction = os.clock()
        end,
        execute = function()
            local c, r

            c, r = doHealCheck()
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            c, r = combat.assistPc(LEADER, false, false)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if combat.hasLiveTarget() then
                local pctMana = mq.TLO.Me.PctMana() or 0
                if pctMana >= NUKE_MANA then
                    c, r = spell.castSpellInGem(NUKE_NAME, NUKE_GEM)
                    if c then timeLastNonIdleAction = os.clock(); return c, r end
                end
            else
                combat.disengage()
            end

            c, r = move.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
            if c then timeLastNonIdleAction = os.clock(); return c, r end

            if (os.clock() - timeLastNonIdleAction) >= IDLE_THRESHOLD
                    and not group.isGroupEngaged() then
                c, r = doIdleTasks()
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
    -- State: MAKECAMPANDEXP
    -- Snap camp at leader's position, hold it, assist when leader pulls.
    -- ============================================================
    fsm.states["MAKECAMPANDEXP"] = {
        onEnter = function()
            mq.cmd('/attack off')
            local alpha = mq.TLO.Spawn('pc =' .. LEADER)
            if alpha() then
                campPoint = { y = alpha.Y(), x = alpha.X() }
            end
        end,
        execute = function()
            local c, r

            c, r = combat.assistPc(LEADER, false, false)
            if c then return c, r end

            if not combat.hasLiveTarget() then combat.disengage() end

            if campPoint then
                c, r = move.navToPoint(campPoint, CAMP_RADIUS)
                if c then return c, r end
            end

            return false, "Holding camp"
        end,
        onExit = function()
            mq.cmd('/squelch /nav stop')
            mq.cmd('/attack off')
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
