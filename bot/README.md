# Bot System

A reactive finite state machine bot for EQ boxing. Each bot runs independently,
follows a leader, and executes class-specific logic based on character name.

---

## Core Design Principle: Yield Every Tick

The main loop ticks every 50ms. Every function must **do one thing and return immediately**.
No `mq.delay()` inside actions. No loops that issue multiple commands.

If something takes multiple ticks (memorizing a spell, waiting for nav to start, targeting),
model it as state — issue the command, return, and handle the result next tick.

```lua
while true do
    fsm.update()   -- executes current state's execute()
    mq.delay(50)   -- yields, processes events, moves to next tick
end
```

---

## Architecture

```
init.lua          Entry point. Shared states (IDLE, INIT, FOLLOW). Name-based dispatch.
fsm.lua           State machine engine. Tracks current state and last reason string.
shaman.lua        Shaman-specific states (SETUP, MELEE, BUFFTEST).
mage.lua          Mage-specific states (SETUP, MELEE, BUFFTEST).

actions/
  spell.lua       Spell mechanics: gem lookup, ready checks, casting, fizzle detection.
  buff.lua        Buff maintenance: cycles targets, checks durations, calls spell.lua.
  melee.lua       Combat: attack on/off, pet, target helpers, live target check.
  movement.lua    Navigation: nav to target, fan-follow.
  group.lua       Group management: invite flow, grouped check.
  util.lua        Shared helpers: resolveTargets, getPcTarget, targetSpawn.
```

---

## Naming Convention

The name tells you what a function does and how to use it.

| Prefix | Type | Returns | Example |
|--------|------|---------|---------|
| `is*` / `has*` | Pure check | bool | `melee.isInCombat()` |
| `get*` / `find*` | Pure check | data or nil | `util.getPcTarget(name)` |
| `nav*` | Actor | `true, reason` or `false` | `move.navToTarget(range)` |
| `cast*` | Actor | `true, reason` or `false` | `spell.castSpell(name)` |
| `attack*` / `combat*` | Actor | `true, reason` or `false` | `melee.attackOn()` |
| `target*` | Actor | `true, reason` or `false` | `util.targetSpawn(spawn)` |

**Pure checks** can be called freely — no side effects, no game commands.

**Actors** issue exactly one game command and return. They consume a tick when they act
(`true, reason`) and do nothing when conditions aren't met (`false`).

---

## Return Value Convention

Actors return `true, reason` when they act, `false` when they don't.

```lua
-- Actor: returns true + reason string, or false
function move.navToTarget(meleeRange)
    if mq.TLO.Navigation.Active() then return false end
    if target.Distance() <= meleeRange then return false end
    mq.cmdf('/squelch /nav target distance=%d', meleeRange - 2)
    return true, 'Navigating to target'
end
```

States propagate actor reasons up to the FSM using a `c, r` pattern:

```lua
execute = function()
    local c, r

    c, r = buff.castBuffList(BUFFS, 8)
    if c then return c, r end

    c, r = move.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
    if c then return c, r end

    return false, "Holding position"   -- idle reason
end
```

The FSM prints the reason only when it changes — no spam, clean status output:
```
[SETUP] Memorizing Spirit of Wolf into gem 7
[SETUP] Casting 'Spirit of Wolf' on Beta
[SETUP] Setup complete
[FOLLOW] Following Alpha
```

---

## State Lifecycle

Each state can define three functions:

```lua
fsm.states["MYSTATE"] = {
    onEnter  = function() ... end,   -- runs once on transition in
    execute  = function() ... end,   -- runs every tick, returns (consumed, reason)
    onExit   = function() ... end,   -- runs once on transition out
}
```

States transition by calling `fsm.changeState("NEWSTATE")`. `lastReason` is cleared
on transition so the new state's first reason always prints.

---

## Buff System

Buff lists are tables of entries with named fields:

```lua
local BUFFS = {
    { spellName = "Inner Fire",     refreshTime = 1800, targets = { "self" } },
    { spellName = "Spirit of Wolf", refreshTime = 1800, targets = { "group" } },
    { spellName = "Strengthen",     refreshTime = 1800, targets = { "self", "group" } },
}
```

`targets` supports: `"self"`, `"pet"`, `"group"` (all members + their pets), or any PC name.

`refreshTime` is in seconds — recast when remaining duration drops below this value.

`buff.castBuffList(BUFFS, gemSlot)` cycles through the list one action per tick:
target → check → mem if needed → wait for ready → check `willLand` → cast.

---

## Fizzle Detection

`spell.lua` registers an `mq.event()` at load time that fires during each `mq.delay()`.
When a fizzle is detected, `castSpell` backs off for 200ms and returns `false`,
letting the buff cycle move on naturally to the next target.

---

## Adding a New Bot

1. Create `booty/bot/yourname.lua` using the factory pattern:
```lua
return function(cfg)
    local LEADER, myOffset, FOLLOW_DIST = cfg.leader, cfg.offset, cfg.followDist
    fsm.states["SETUP"]  = { execute = function() ... end }
    fsm.states["MELEE"]  = { execute = function() ... end }
end
```

2. Register it in `init.lua`:
```lua
local NAME_MODULES = {
    Beta  = 'booty.bot.shaman',
    Gamma = 'booty.bot.mage',
    Delta = 'booty.bot.yourname',   -- add here
}
```

---

## Adding a New Action

- **Pure check**: return data, no `mq.cmd`. Can be called anywhere.
- **Actor**: issue exactly one `mq.cmd`, return `true, reason`. Add to appropriate module by domain.

Update `actions/ACTIONS.md` to track what's built and what's pending.

---

## Commands

| Command | Effect |
|---------|--------|
| `/setstate IDLE` | Stop everything, wait |
| `/setstate INIT` | Run to leader, request group invite |
| `/setstate FOLLOW` | Fan-follow leader |
| `/setstate SETUP` | Buff up, summon pet, then auto-FOLLOW |
| `/setstate MELEE` | Assist leader, fight, heal between pulls |
| `/setstate FOLLOWANDEXP` | Follow leader, assist on everything leader attacks |
| `/setstate MAKECAMPANDEXP` | Snap camp at leader's position, hold it, assist when leader pulls |
| `/setstate BUFFTEST` | Test buff cycle without combat |
