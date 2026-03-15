local mq      = require('mq')
local fsm     = require('booty.bot.fsm')
local actions = require('booty.bot.actions')

-- ============================================================
-- Config
-- ============================================================
local LEADER          = "Alpha"
local FOLLOW_DIST     = 15   -- start navigating when we're this far from leader
local MELEE_RANGE     = 12   -- engage target when inside this distance

-- Per-character positional offsets for fan formation behind leader.
-- Add entries here for each bot by name.
local OFFSETS = {
    Beta  = { x =  8, y =  8 },
    Gamma = { x = -8, y = -8 },
}
local myOffset = OFFSETS[mq.TLO.Me.Name()] or { x = 0, y = 0 }

-- ============================================================
-- MELEE state internal tracking
-- ============================================================
-- We store the last known target ID so we only send /tar when it changes,
-- instead of running /assist every tick (which blocks and hammers the server).
local lastAlphaTargetID = 0

-- ============================================================
-- State: IDLE
-- Stop everything. Bot waits for a /setstate command.
-- ============================================================
fsm.states["IDLE"] = {
    onEnter = function()
        mq.cmd('/squelch /nav stop')
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
    end,
    execute = function()
        -- Intentionally empty. Waiting for orders via /setstate.
    end,
}

-- ============================================================
-- State: FOLLOW
-- Fan-follow the leader. No combat engagement.
-- ============================================================
fsm.states["FOLLOW"] = {
    onEnter = function()
        mq.cmd('/attack off')
        mq.cmd('/squelch /pet back off')
    end,
    execute = function()
        actions.fanFollow(LEADER, myOffset, FOLLOW_DIST)
    end,
    onExit = function()
        mq.cmd('/squelch /nav stop')
    end,
}

-- ============================================================
-- State: MELEE
-- Watch the leader's target. Engage live NPCs, fan-follow between pulls.
--
-- Tick flow (no blocking delays):
--   1. Read leader's TargetID (no /assist, no delay)
--   2. If it changed, send /tar — return, let it land next tick
--   3. If we have a live NPC targeted: approach + attack on + pet
--   4. If no live target: attack off + fan-follow
-- ============================================================
fsm.states["MELEE"] = {
    onEnter = function()
        lastAlphaTargetID = 0   -- Force re-check on entry
    end,
    execute = function()
        -- Step 1: Check if leader's target changed
        local alphaTargetID = actions.getLeaderTargetID(LEADER)

        if alphaTargetID ~= lastAlphaTargetID then
            lastAlphaTargetID = alphaTargetID
            if alphaTargetID > 0 then
                -- Step 2: Acquire target — return so it lands before we read it
                actions.targetID(alphaTargetID)
                return
            end
        end

        -- Step 3: Evaluate current target
        local target = mq.TLO.Target
        local hasLiveTarget = target()
            and target.Type() == "NPC"
            and (target.PctHPs() or 0) > 0

        if hasLiveTarget then
            actions.approachTarget(MELEE_RANGE)
            actions.attackOn()
            actions.sendPet(target.ID())
        else
            -- Dead mob, no target, or leader cleared — stand down and follow
            actions.combatOff()
            actions.fanFollow(LEADER, myOffset, FOLLOW_DIST)
        end
    end,
    onExit = function()
        actions.combatOff()
        mq.cmd('/squelch /nav stop')
    end,
}

-- ============================================================
-- Main Loop
-- ============================================================
print("\ag[Bot]\aw Online. State: \ayIDLE\aw — use /setstate <IDLE|FOLLOW|MELEE>")
fsm.changeState("FOLLOW")

while true do
    fsm.update()
    mq.delay(50)
end
