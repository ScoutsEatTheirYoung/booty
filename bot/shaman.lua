local mq    = require('mq')
local fsm   = require('booty.bot.fsm')
local move  = require('booty.bot.actions.movement')
local melee = require('booty.bot.actions.melee')
local buff  = require('booty.bot.actions.buff')
local util  = require('booty.bot.actions.util')

-- ============================================================
-- Shaman config
-- Fill in spell names for your level / server.
-- ============================================================
local BUFFS = {
    { spellName = "Inner Fire",     refreshTime = 1800, targets = { "self" } },
    { spellName = "Spirit of Wolf", refreshTime = 1800, targets = { "group" } },
    { spellName = "Strengthen",     refreshTime = 1800, targets = { "self", "group" } },
}

local CAST_RANGE = 50
local HEAL_PCT   = 60

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
                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end

                -- TODO: cast slow
                -- TODO: cast DoT
                return false, "In combat — waiting for spell opportunities"

            else
                local count = mq.TLO.Group.Members() or 0
                for i = 1, count do
                    local m = mq.TLO.Group.Member(i)
                    if m and m.Name() and (m.PctHPs() or 100) < HEAL_PCT then
                        -- TODO: c, r = castHeal(healSpell, gem, m.Spawn); if c then return c, r end
                        return false, string.format("Waiting to heal %s (%d%%)", m.Name(), m.PctHPs())
                    end
                end

                c, r = move.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
                if c then return c, r end
                return false, "Holding position near leader"
            end
        end,
        onExit = function()
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
            return false, "All buffs current"
        end,
    }
end
