local mq      = require('mq')
local fsm     = require('booty.bot.fsm')
local actions = require('booty.bot.actions')
local buffActions = require('booty.bot.actions.buff')

-- ============================================================
-- Mage bot module
-- Called by bot.lua with shared config. Registers MELEE state.
-- ============================================================

local CAST_RANGE = 50   -- stay this far back, let the pet do the work

return function(cfg)
    local LEADER      = cfg.leader
    local myOffset    = cfg.offset
    local FOLLOW_DIST = cfg.followDist

    local lastLeaderTargetID = 0

    -- ============================================================
    -- State: MELEE
    -- Mage role: pet is primary DPS, caster stays at range.
    -- Tick flow:
    --   1. Sync to leader's target (one /tar per change, return)
    --   2. Live target → send pet, approach to cast range, nuke
    --   3. No live target → pet back off, fan-follow
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
                -- Step 2: Pet on target, move to cast range
                actions.sendPet(target.ID())
                actions.approachTarget(CAST_RANGE)

                -- TODO: nuke if in range and spell ready
                --   actions.castBuffs({ name = "Shock of Spikes", ... }, gem)

            else
                -- Step 3: Stand down, follow
                actions.combatOff()
                actions.fanFollow(LEADER, myOffset, FOLLOW_DIST)
            end
        end,
        onExit = function()
            actions.combatOff()
            mq.cmd('/squelch /nav stop')
        end,
    }

    fsm.states['BUFFTEST'] = {
        execute = function()
            local testbuffs = {
                { spellName = "Minor Shielding", refreshTime = 600, targets = { "self"}},
            }

            buffActions.checkAndBuff(testbuffs, 3)

        end,
    }

    fsm.states['SETUP'] = {
        execute = function()
            -- try to get a pet out
            
        end

    }
end
