# Bot System

A reactive finite state machine bot for EQ boxing. Each bot runs independently,
follows a leader, and executes class-specific logic based on character name.

---

## Core Design: Yield Every Tick

The main loop ticks every 50ms. Every function must **do one thing and return immediately**.
No `mq.delay()` inside actions. No loops that issue multiple commands.

```lua
while true do
    mq.doevents()  -- process events (fizzle, etc.)
    fsm.update()   -- execute current state's execute()
    mq.delay(50)   -- yield, allow EQ to process
end
```

---

## The `c, r` Contract

Every actor returns two values: **`c` (consumed)** and **`r` (reason)**.

```lua
local c, r = someAction(...)
if c then return c, r end   -- stop — tick is consumed
```

### `c = true` — Tick Consumed

A game command was issued **or** we are actively waiting on the result of one.
The reason describes **what is actively happening**.

Examples: `/nav`, `/cast`, `/pet attack`, `/attack on`, `/tar id`, `/sit`, `/stand`, `/memspell`

> One command per tick. Once `c = true`, stop evaluating — come back next tick.

### `c = false` — Tick Free

No command was issued. All checks were pure reads of client state.
The reason is **purely informational** — it describes the current status, not an action.
It exists only for the status line display.

Examples: `"Walking with Alpha"`, `"Medding (87% mana)"`, `"Holding camp"`, `"No target to assist"`

> `c = false` reasons are never acted on by the caller. They are display-only.

### Why this matters

The FSM prints the reason only when it changes. This gives clean, readable status output
without spam — you see exactly what the bot is doing or waiting for, one line at a time.

```
[SETUP] Memorizing Minor Shielding into gem 1
[SETUP] Casting 'Minor Shielding' on self
[FOLLOWANDEXP] Walking with Alpha
[FOLLOWANDEXP] Standing up for combat
[FOLLOWANDEXP] Targeting Goblin Warrior
[FOLLOWANDEXP] Pet sent to attack
[FOLLOWANDEXP] In combat — pet attacking
[FOLLOWANDEXP] Disengaged
[FOLLOWANDEXP] Walking with Alpha
[FOLLOWANDEXP] Sitting to med
[FOLLOWANDEXP] Medding (72% mana)
```

---

## Where Logic Lives

### States (`mage.lua`, `shaman.lua`) — The Story

States describe **what the bot is doing at a high level**. They read like a story:

```lua
execute = function()
    local c, r

    -- Try to engage what the group is fighting
    c, r = combat.assistLeader(LEADER, false, true)
    if c then timeLastNonIdleAction = os.clock(); return c, r end

    -- Nothing to fight — stand down and follow
    combat.disengage()

    c, r = move.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
    if c then timeLastNonIdleAction = os.clock(); return c, r end

    -- In range and quiet — med and rebuff
    if idleLongEnough and not group.isGroupEngaged() then
        c, r = doIdleTasks()
        if c then return c, r end
    end

    return false, "Walking with " .. LEADER
end
```

States should contain **no raw `mq.TLO` calls** and **no game commands** beyond
the `onEnter`/`onExit` cleanup blocks. If you find yourself writing decision logic
inline in a state, it belongs in an action module.

### Action Modules (`actions/`) — The Logic

Action modules contain the actual decisions and commands. They are small, testable units.

| Module | Responsibility |
|--------|---------------|
| `combat.lua` | Engagement: `assistLeader`, `engageTarget`, `disengage`, `sendPet`, `hasPet`, `hasLiveTarget` |
| `target.lua` | Targeting: `getPcTarget`, `targetSpawn`, `targetByID`, `targetPcTarget` |
| `melee.lua` | Assist queries: `getAssistTarget` (live NPC filter on a PC's target) |
| `movement.lua` | Navigation: `navFanFollow`, `navToTarget`, `navToPoint`, `navToPC` |
| `spell.lua` | Spell casting: `castSpell`, `castSummonPet`, `isSpellReady`, `willLand` |
| `buff.lua` | Buff cycling: `castBuffList` — one target/spell per tick |
| `group.lua` | Group state: `isGroupEngaged`, `isPcEngaged`, `getEngagedTarget`, `navGroupInvite` |
| `util.lua` | Target resolution: `resolveTargets` (self/pet/group/name → spawn list) |

### Pure Checks vs Actors

**Pure checks** — read client state, no side effects, always return data (never `c, r`):
```lua
combat.hasPet()              -- boolean
combat.hasLiveTarget()       -- boolean
group.isGroupEngaged()       -- boolean
group.isPcEngaged(name)      -- boolean
```

**Actors** — issue exactly one game command, return `(c, r)`:
```lua
combat.assistLeader(...)     -- targets + engages, one step per tick
move.navFanFollow(...)       -- issues /nav or returns false if in range
spell.castSpell(name)        -- issues /cast or returns false if not ready
```

Movement actors (`navFanFollow`, `navToTarget`) handle their own prerequisites:
if the bot needs to move but is sitting, they issue `/stand` first and return `true`.
States do not manage standing.

---

## State Lifecycle

```lua
fsm.states["MYSTATE"] = {
    onEnter  = function() ... end,   -- runs once on transition in (cleanup, reset)
    execute  = function()            -- runs every tick
        return consumed, reason      -- c, r
    end,
    onExit   = function() ... end,   -- runs once on transition out (cleanup)
}
```

`onEnter`/`onExit` may issue raw commands (attack off, nav stop) since they run once.
`execute` should use action modules exclusively.

---

## Buff System

```lua
local BUFFS = {
    { spellName = "Inner Fire", refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Strengthen", refreshTime = 600, targets = { "self", "group" } },
}
```

`targets` supports: `"self"`, `"pet"`, `"group"` (all members + pets), or any PC name.
`refreshTime` is in seconds — recast when remaining duration drops below this.
`buff.castBuffList(BUFFS, gemSlot)` advances one action per tick.

---

## Fizzle Detection

`spell.lua` registers an `mq.event()` at load time. When a fizzle is detected,
`castSpell` backs off for 200ms and returns `false`, letting the buff cycle continue.

---

## Adding a New Bot

1. Create `booty/bot/yourname.lua`:
```lua
return function(cfg)
    local LEADER, myOffset, FOLLOW_DIST = cfg.leader, cfg.offset, cfg.followDist
    fsm.states["SETUP"]  = { execute = function() ... end }
    fsm.states["MELEE"]  = { execute = function() ... end }
end
```

2. Register in `init.lua`:
```lua
local NAME_MODULES = {
    Beta  = 'booty.bot.shaman',
    Gamma = 'booty.bot.mage',
    Delta = 'booty.bot.yourname',
}
```

---

## Commands

| Command | Effect |
|---------|--------|
| `/setstate IDLE` | Stop everything, wait |
| `/setstate INIT` | Run to leader, request group invite |
| `/setstate FOLLOW` | Fan-follow leader |
| `/setstate SETUP` | Buff up, summon pet, then auto-transition to FOLLOW |
| `/setstate MELEE` | Assist leader, approach target, fight |
| `/setstate FOLLOWANDEXP` | Follow leader, assist on everything leader engages, med when idle |
| `/setstate MAKECAMPANDEXP` | Snap camp at leader's position, hold it, assist when leader pulls |
| `/setstate BUFFTEST` | Test buff cycle without combat |
