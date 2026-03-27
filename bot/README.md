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
[STARTUP] Memorizing Minor Shielding into gem 1
[STARTUP] Casting 'Minor Shielding' on self
[ASSIST] Walking with Alpha
[ASSIST] Standing up for combat
[ASSIST] Targeting Goblin Warrior
[ASSIST] Pet sent to attack
[ASSIST] In combat — pet attacking
[ASSIST] Disengaged
[ASSIST] Walking with Alpha
[ASSIST] Sitting to med
[ASSIST] Medding (72% mana)
```

---

## Where Logic Lives

### States (`mage.lua`, `shaman.lua`) — The Story

States describe **what the bot is doing at a high level**. They read like a story:

```lua
execute = function()
    local c, r

    -- Try to engage what the group is fighting
    c, r = combatActions.assistPC(LEADER, false, true)
    if c then timeLastNonIdleAction = os.clock(); return c, r end

    -- Nothing to fight — stand down and follow
    combatActions.disengage()

    c, r = movementActions.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
    if c then timeLastNonIdleAction = os.clock(); return c, r end

    -- In range and quiet — med and rebuff
    if idleLongEnough and not groupUtils.isGroupEngaged() then
        c, r = doIdleTasks()
        if c then return c, r end
    end

    return false, "Walking with " .. LEADER
end
```

States should contain **no raw `mq.TLO` calls** and **no game commands** beyond
the `onEnter`/`onExit` cleanup blocks. If you find yourself writing decision logic
inline in a state, it belongs in an action module.

### Bricks (`bricks/`) — The Logic

Bricks contain the actual decisions and commands. Each domain is split into a `*Utils.lua`
(pure checks, no side effects) and an `*Actions.lua` (actors that issue game commands).

| Module | Responsibility |
|--------|---------------|
| `combatUtils.lua` | Pure checks: `isInCombat`, `hasLiveTarget`, `hasPet` |
| `combatActions.lua` | Engagement: `assistPC`, `engageTarget`, `disengage`, `sendPet`, `attackOn` |
| `targetUtils.lua` | Pure checks: `getPCTarget`, `resolveTargets` (self/pet/group/name → spawn list) |
| `targetActions.lua` | Targeting: `targetSpawn`, `targetByID`, `targetPCTarget` |
| `meleeUtils.lua` | Pure check: `getAssistTarget` (live NPC filter on a PC's target) |
| `movementUtils.lua` | Pure checks: `distanceTo`, `standIfNeeded` |
| `movementActions.lua` | Navigation: `navFanFollow`, `navToTarget`, `navToPC`, `navToPoint`, `navToSpawn`, `navToGuildhallPort` |
| `spellUtils.lua` | Pure checks: `findGemForSpell`, `isSpellMemmed`, `isOnBar`, `isSpellReady`, `hasManaForSpell` |
| `spellActions.lua` | Spell casting: `memorizeSpell`, `castSpell`, `castSpellInGem`, `castSummonPet` |
| `buffActions.lua` | Buff cycling: `castBuffList` — one target/spell per tick |
| `groupUtils.lua` | Group state: `isGroupEngaged`, `isPCEngaged`, `getEngagedTarget`, `isGrouped`, `hasPendingInvite` |
| `groupActions.lua` | Group actions: `navGroupInvite`, `resetInviteTimer` |
| `altabilityUtils.lua` | Pure checks: `hasAA`, `isAAReady` |
| `altabilityActions.lua` | AA activation: `castAA` |

### Pure Checks vs Actors

**Pure checks** — read client state, no side effects, always return data (never `c, r`):
```lua
combatUtils.hasPet()              -- boolean
combatUtils.hasLiveTarget()       -- boolean
groupUtils.isGroupEngaged()       -- boolean
groupUtils.isPCEngaged(name)      -- boolean
```

**Actors** — issue exactly one game command, return `(c, r)`:
```lua
combatActions.assistPC(...)          -- targets + engages, one step per tick
movementActions.navFanFollow(...)    -- issues /nav or returns false if in range
spellActions.castSpell(name)         -- issues /cast or returns false if not ready
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
    fsm.states["STARTUP"] = { execute = function() ... end }
    fsm.states["MELEE"]   = { execute = function() ... end }
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
| `/setstate JOINING` | Run to leader, request group invite |
| `/setstate ESCORT` | Nav formation follow — non-blocking, allows casting while moving |
| `/setstate LEASH` | Strict EQ `/follow` — glued to leader, stops everything else |
| `/setstate STARTUP` | Buff up, summon pet, then auto-transition to ESCORT |
| `/setstate MELEE` | Assist leader, approach target, fight |
| `/setstate ASSIST` | Follow leader, assist on everything leader engages, med when idle |
| `/setstate CAMP` | Snap camp at leader's position, hold it, assist when leader pulls |
| `/setstate BUFFTEST` | Test buff cycle without combat |
| `/guildport <porter> <loc>` | Port via guild hall, transition to PORTING state |
