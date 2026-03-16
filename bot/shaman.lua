local mq    = require('mq')
local fsm   = require('booty.bot.fsm')
local move  = require('booty.bot.actions.movement')
local melee = require('booty.bot.actions.melee')
local buff  = require('booty.bot.actions.buff')
local util  = require('booty.bot.actions.util')
local group = require('booty.bot.actions.group')

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
    ---@type Point|nil
    local campPoint = nil
    local CAMP_RADIUS = 15

    local lastActionTime = os.clock()
    local IDLE_THRESHOLD = 5  -- seconds of no non-idle action before sitting to med


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
    -- State: FOLLOWANDEXP
    -- Follow Alpha and assist on everything Alpha attacks.
    -- ============================================================
    fsm.states["FOLLOWANDEXP"] = {
        onEnter = function()
            mq.cmd('/attack off')
            mq.cmd('/squelch /pet back off')
            lastLeaderTargetID = 0
            lastActionTime     = os.clock()
        end,
        execute = function()
            local c, r

            local assistTarget = melee.getAssistTarget(LEADER)
            local assistID     = assistTarget and assistTarget.ID() or 0
            if assistID ~= lastLeaderTargetID then
                lastLeaderTargetID = assistID
                if assistID > 0 then
                    lastActionTime = os.clock()
                    c, r = util.targetSpawn(assistTarget)
                    if c then return c, r end
                end
            end

            if melee.hasLiveTarget() then
                lastActionTime = os.clock()

                if mq.TLO.Me.Sitting() then
                    mq.cmd('/stand')
                    return true, 'Standing up'
                end

                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end

                -- TODO: cast slow
                -- TODO: cast DoT
                return false, "In combat"

            else
                c, r = melee.combatOff()
                if c then return c, r end

                c, r = move.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
                if c then
                    lastActionTime = os.clock()
                    if mq.TLO.Me.Sitting() then
                        mq.cmd('/stand')
                        return true, 'Standing up to follow'
                    end
                    return c, r
                end

                -- In range and not moving — check if idle long enough to med
                local pctMana = mq.TLO.Me.PctMana() or 100
                if (os.clock() - lastActionTime) >= IDLE_THRESHOLD
                        and not group.isGroupEngaged()
                        and pctMana < 100 then
                    if not mq.TLO.Me.Sitting() then
                        mq.cmd('/sit')
                        return true, 'Sitting to med'
                    end

                    c, r = buff.castBuffList(BUFFS, 8)
                    if c then return c, r end

                    return false, string.format('Medding (%d%% mana)', pctMana)
                end

                if mq.TLO.Me.Sitting() then
                    mq.cmd('/stand')
                    return true, 'Standing up'
                end

                return false, "Walking with " .. LEADER
            end
        end,
        onExit = function()
            mq.cmd('/stand')
            mq.cmd('/squelch /nav stop')
            mq.cmd('/attack off')
        end,
    }

    -- ============================================================
    -- State: MAKECAMPANDEXP
    -- Snap camp position on enter, hold it, assist when Alpha pulls,
    -- return to camp after each kill.
    -- ============================================================
    fsm.states["MAKECAMPANDEXP"] = {
        onEnter = function()
            mq.cmd('/attack off')
            mq.cmd('/squelch /pet back off')
            lastLeaderTargetID = 0
            local alpha = mq.TLO.Spawn('pc =' .. LEADER)
            if alpha() then
                campPoint = { y = alpha.Y(), x = alpha.X() }
            end
        end,
        execute = function()
            local c, r

            local assistTarget = melee.getAssistTarget(LEADER)
            local assistID     = assistTarget and assistTarget.ID() or 0
            if assistID ~= lastLeaderTargetID then
                lastLeaderTargetID = assistID
                if assistID > 0 then
                    c, r = util.targetSpawn(assistTarget)
                    if c then return c, r end
                end
            end

            if melee.hasLiveTarget() then
                c, r = move.navToTarget(CAST_RANGE)
                if c then return c, r end

                -- TODO: cast slow
                -- TODO: cast DoT
                return false, "In combat"

            else
                c, r = melee.combatOff()
                if c then return c, r end

                if campPoint then
                    c, r = move.navToPoint(campPoint, CAMP_RADIUS)
                    if c then return c, r end
                end

                return false, "Holding camp"
            end
        end,
        onExit = function()
            mq.cmd('/squelch /nav stop')
            mq.cmd('/attack off')
            mq.cmd('/squelch /pet back off')
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
