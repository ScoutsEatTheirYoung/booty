local mq      = require('mq')
local fsm     = require('booty.bot.fsm')
local actions = require('booty.bot.actions')
local buffActions = require('booty.bot.actions.buff')

-- ============================================================
-- Shaman bot module
-- Called by bot.lua with shared config. Registers MELEE state.
-- ============================================================

local CAST_RANGE  = 50   -- stay this far back from the mob
local HEAL_PCT    = 60   -- heal a group member below this HP %

return function(cfg)
    local LEADER      = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    local lastLeaderTargetID = 0

    -- ============================================================
    -- State: MELEE
    -- Shaman role: stay at cast range, slow target, heal group.
    -- Tick flow:
    --   1. Sync to leader's target (one /tar per change, return)
    --   2. Live target → approach to cast range, cast slow / DoT
    --   3. No live target → check group HP, fan-follow
    -- ============================================================
    fsm.states["MELEE"] = {
        onEnter = function()
            lastLeaderTargetID = 0
        end,
        execute = function()
            -- Step 1: Track leader's target
            local leaderTargetID = actions.getLeaderTargetID(LEADER)
            if leaderTargetID ~= lastLeaderTargetID then
                lastLeaderTargetID = leaderTargetID
                if leaderTargetID > 0 then
                    actions.targetID(leaderTargetID)
                    return
                end
            end

            local target = mq.TLO.Target
            local hasLiveTarget = target()
                and target.Type() == "NPC"
                and (target.PctHPs() or 0) > 0

            if hasLiveTarget then
                -- Step 2: Move into casting range
                actions.approachTarget(CAST_RANGE)

                -- TODO: cast slow if target is not slowed
                --   actions.castBuffs({ name = "Malo", ... }, gem)
                -- TODO: cast DoT / nuke
                --   actions.castBuffs({ name = "Turgur's Insects", ... }, gem)

            else
                -- Step 3: No live target — heal check then follow
                local count = mq.TLO.Group.Members() or 0
                for i = 1, count do
                    local m = mq.TLO.Group.Member(i)
                    if m and m.Name() and (m.PctHPs() or 100) < HEAL_PCT then
                        -- TODO: target and cast heal
                        --   actions.targetID(m.Spawn.ID())
                        --   then cast heal spell next tick
                        print(string.format('\ay[Shaman]\aw %s needs heals (%d%%)', m.Name(), m.PctHPs()))
                        return
                    end
                end

                actions.fanFollow(LEADER, myOffset, FOLLOW_DIST)
            end
        end,
        onExit = function()
            mq.cmd('/squelch /nav stop')
        end,
    }

    fsm.states['BUFFTEST'] = {
        execute = function()
            local testbuffs = {
                { spellName = "Inner Fire", refreshTime = 600, targets = { "self", "group"}},
                { spellName = "Strengthen", refreshTime = 600, targets = { "self", "group"}}
            }

            buffActions.checkAndBuff(testbuffs, 3)

        end,
    }
end
