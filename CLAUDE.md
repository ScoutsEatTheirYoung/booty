# Booty — Claude Context

## Environment

- **Runtime:** LuaJIT (reports `_VERSION = "Lua 5.1"`) inside MQ2, which runs as a 32-bit Windows process under Wine
- **Bitwise ops:** Use `require('bit')` — `bit.band`, `bit.bor`, etc. NOT Lua 5.3 `&`/`|` operators
- **`io.popen` crashes EQ** under Wine — never use it. `io.open` is fine.
- **`PackageMan.Require` also crashes** — uses `io.popen` internally
- **`lfs`** is available via `require('lfs')`. Already on cpath.
- **`string.gsub`** returns two values. Wrap in parens: `(str:gsub(...))` when passing to `table.insert`
- **MQ2 paths** are Windows-style (`C:\MQ2\...`). Use backslashes for lfs/Windows APIs.
- **Type definitions** are in `/home/julian/wine-eq/drive_c/MQ2/mq-definitions/` — loaded via `.luarc.json`
- **`MQSpawn`** is aliased as `spawn | fun(): string|nil` — use `MQSpawn` (not `spawn`) as return type annotation when returning `mq.TLO.Spawn(...)` results

## Project Overview

Booty is a **loot/sell/bot automation framework** for EverQuest via MacroQuest2 Lua.

Two distinct halves:
1. **Standalone tools** (`init.lua` entry): loot corpses, sell to vendor, manage filters
2. **Bot system** (`bot/` folder): FSM-based multi-character boxing automation

## File Structure

```
booty/
├── init.lua              CLI dispatcher — /lua run booty [loot|sell|filter|config|...]
├── types.lua             LuaLS annotations: Point, TargetSpecifier, BuffEntry, ResolvedTarget
├── utils.lua             Logging (info/warn/error), string/table helpers, file I/O, MQ2 helpers
├── corpse.lua            get_all(radius, zradius) — find nearby corpses sorted by distance
├── loot.lua              Open corpses, extract items, apply filters, lore checks
├── sell.lua              Sell bag contents to open merchant window
├── config.lua            User config overrides (sparse table, merged over defaults)
├── config/
│   ├── init.lua          Loader: get(), set(), value(), reload(), save(), deep_merge()
│   └── defaults.lua      All config keys + default values
├── filter/
│   ├── init.lua          Filter object: load(), new(), matches(), getAllFilters()
│   └── parser.lua        DSL parser: Name/Pattern/Value/Flag/Slot/AugType rules, & for AND
├── filters/              .txt filter files (user data)
├── buff/
│   └── manager.lua       Standalone buff casting: swapAndCast(), needBuff(), acquireTarget()
├── hud/
│   └── init.lua          ImGui HUD: 60fps render callback + 10fps data gatherer (non-blocking)
├── bot/
│   ├── init.lua          Bot entry point — shared states (IDLE/JOINING/ESCORT/LEASH/PORTING), dispatches by name
│   ├── fsm.lua           FSM engine: changeState(), update(), /setstate slash command
│   ├── shaman.lua        Shaman class states (STARTUP/MELEE/ASSIST/CAMP/BUFFTEST)
│   ├── mage.lua          Mage class states (STARTUP/MELEE/ASSIST/CAMP/BUFFTEST)
│   ├── travel.lua        Guild hall port utility: ascendantGuildHallPort(porterName, location)
│   └── bricks/
│       ├── combatActions.lua    attackOn, disengage, sendPet, engageTarget, assistPC
│       ├── combatUtils.lua      isInCombat, hasLiveTarget, hasPet
│       ├── targetActions.lua    targetSpawn, targetByID, targetPCTarget
│       ├── targetUtils.lua      getPCTarget, resolveTargets
│       ├── meleeUtils.lua       getAssistTarget(pcName) — live NPC filter on PC's target
│       ├── movementActions.lua  navFanFollow, navToTarget, navToPC, navToPoint, navToSpawn, navToGuildhallPort
│       ├── movementUtils.lua    distanceTo, standIfNeeded
│       ├── spellActions.lua     memorizeSpell, castSpell, castSpellInGem, castSummonPet
│       ├── spellUtils.lua       findGemForSpell, isSpellMemmed, isOnBar, isSpellReady, hasManaForSpell
│       ├── buffActions.lua      castBuffList(BUFFS, gemSlot), cureGroup
│       ├── healActions.lua      healGroup(healName, healGem, healPct, emergencyPct, leader)
│       ├── idleActions.lua      medAndBuff(buffList, gemSlot) — sit/med + cast buff list
│       ├── groupActions.lua     navGroupInvite, resetInviteTimer
│       ├── groupUtils.lua       isGroupEngaged, isPCEngaged, getEngagedTarget, isGrouped, hasPendingInvite, minGroupHp
│       ├── altabilityActions.lua  castAA(aaName)
│       └── altabilityUtils.lua    hasAA, isAAReady
└── search/item/init.lua  ImGui inventory browser with item icons
```

## Bot Architecture

### FSM Pattern

Each state is a table with optional `onEnter`, `execute`, `onExit`:

```lua
fsm.states["MYSTATE"] = {
    onEnter = function() ... end,
    execute = function()
        -- Return (true, reason) if an action was taken this tick
        -- Return (false, reason) if idle/waiting
        return false, "Nothing to do"
    end,
    onExit = function() ... end,
}
```

`fsm.update()` calls `execute()` every tick and only prints the reason when it changes (no spam).

### `c, r` Return Convention

`c` = **consumed** (boolean), `r` = **reason** (string).

```lua
local c, r = someAction(...)
if c then return c, r end  -- stop — tick consumed
```

**`c = true`** — A game command was issued, or we're waiting on one.
The reason describes **what is actively happening**. Stop processing this tick.

**`c = false`** — No command issued. All checks were pure client-side reads.
The reason is **purely informational** — for status display only. The caller never
acts on it. Continue evaluating other actions.

Rules:
- Pure checks (`hasPet`, `hasLiveTarget`, `isGroupEngaged`) never return `c, r` — they return plain values
- Actors always return `c, r`
- `c = false` reasons should be present-tense status: `"Walking with Alpha"`, `"Medding (87% mana)"` — not `"Nothing to do"`
- The FSM only prints reason when it changes — clean output, no spam

### Non-Blocking Rule

**No `mq.delay()` inside action modules.** Actions issue one command and return immediately. The FSM loop handles timing between ticks.

### Tick Loop (bot/init.lua)

```lua
while true do
    mq.doevents()
    fsm.update()
    mq.delay(50)  -- ~20 ticks/sec
end
```

## Key Modules Reference

### combatUtils.lua (pure checks)
```lua
combatUtils.isInCombat()        -- Me.Combat()
combatUtils.hasLiveTarget()     -- target is live NPC
combatUtils.hasPet()            -- Me.Pet.ID() > 0
```

### combatActions.lua
```lua
combatActions.attackOn()                          -- /attack on if not already in combat
combatActions.disengage()                         -- attack off → pet back off, one step per tick
combatActions.sendPet(targetID)                   -- /pet attack if not already on target
combatActions.engageTarget(target, melee, pet)    -- target→sendPet→attackOn, one step per tick
combatActions.assistPC(pcName, melee, pet)        -- main combat entry point for states:
                                                  -- finds live NPC (PC's target → XTargets),
                                                  -- stands if sitting, then engageTarget
```

### targetUtils.lua (pure checks)
```lua
targetUtils.getPCTarget(pcName)     -- spawn.TargetOfTarget = what that PC is targeting, or nil
targetUtils.resolveTargets(list)    -- "self"/"pet"/"group"/name → [{spawn, label}]
```

### targetActions.lua
```lua
targetActions.targetSpawn(spawn)        -- /tar id if not already targeted
targetActions.targetByID(id)
targetActions.targetPCTarget(pcName)    -- /tar id on leader's target
```

### meleeUtils.lua (pure checks)
```lua
meleeUtils.getAssistTarget(pcName)  -- leader's target if live NPC, else nil
```

### groupUtils.lua (pure checks)
```lua
groupUtils.isGroupEngaged()         -- any XTarget entry exists
groupUtils.isPCEngaged(pcName)      -- spawn PlayerState & 12 (bits 4+8 = Aggressive/ForcedAggressive)
groupUtils.getEngagedTarget()       -- first live NPC from XTarget list, or nil
groupUtils.isGrouped()
groupUtils.hasPendingInvite()       -- Me.Invited()
groupUtils.minGroupHp()             -- lowest PctHPs across all group members
groupUtils.isEngagementNearPoint(campPoint, radius)  -- any engaged NPC within radius of a world point
groupUtils.isCampEngaged(leaderName, campPoint, pullRadius)
-- true when non-leader is engaged (mob at camp) OR leader engaged and mob within pullRadius of camp
```

### groupActions.lua
```lua
groupActions.navGroupInvite(leader, cooldown, dist)  -- run to leader, request invite, accept it
groupActions.resetInviteTimer()                       -- call from INIT onEnter
```

### spellUtils.lua (pure checks)
```lua
spellUtils.findGemForSpell(spellName)   -- gem slot number or nil
spellUtils.isSpellMemmed(spellName)     -- boolean
spellUtils.isOnBar(spellName)           -- boolean
spellUtils.isSpellReady(spellName)      -- boolean
spellUtils.hasManaForSpell(spellName)   -- boolean
```

### spellActions.lua
```lua
spellActions.memorizeSpell(gemNum, spellName)
spellActions.castSpell(spellName)
spellActions.castSpellInGem(spellName, gemNum)
spellActions.castSummonPet(spellName, gemNum, reagent)
spellActions.guardCasting(emergencyPct)
-- emergencyPct: allow cast interrupt if group member below this % HP
-- pass nil to never allow interrupt (mage, etc.)
```

### buffActions.lua
```lua
-- BUFFS config format:
local BUFFS = {
    { spellName = "Inner Fire", refreshTime = 600, targets = { "self", "group" } },
}
buffActions.castBuffList(BUFFS, gemSlot)   -- iterates targets, casts if needed
```

### healActions.lua
```lua
healActions.healGroup(healName, healGem, healPct, emergencyPct, leader)
-- Heals leader first, then group members, then self.
-- Uses emergencyPct threshold when group is engaged, healPct otherwise.
-- Skips targeting/consuming tick if spell is on cooldown.
```

### idleActions.lua
```lua
idleActions.medAndBuff(buffList, gemSlot)
-- Sits to med if mana < 100%, then casts any buffs from buffList that need refreshing.
-- Used in idle blocks and SETUP/BUFFTEST states.
```

### movementUtils.lua (pure checks)
```lua
movementUtils.distanceTo(point)     -- 2D distance to {x, y} point
movementUtils.standIfNeeded()       -- /stand if sitting, returns c, r
```

### movementActions.lua
```lua
movementActions.navFanFollow(leader, offset, dist)  -- fan formation follow (non-blocking)
movementActions.navToTarget(range)                  -- approach current target (non-blocking)
movementActions.navForLoS(losRange)                 -- face target, nav until LoS clear (blocking), stopNav when LoS gained
movementActions.navToPC(name, dist)
movementActions.navToPoint(point, radius)           -- navigate to {x, y} (blocking)
movementActions.navToSpawn(spawn, range)            -- navigate to spawn (blocking)
movementActions.navToGuildhallPort()                -- navigate to guild lobby portal (blocking)
movementActions.stopNav()                           -- /nav stop + clear owner
```

### altabilityUtils.lua (pure checks)
```lua
altabilityUtils.hasAA(aaName)      -- boolean: AA is purchased
altabilityUtils.isAAReady(aaName)  -- boolean: AA exists and is off cooldown
```

### altabilityActions.lua
```lua
altabilityActions.castAA(aaName)   -- /alt activate if owned and ready; returns false (no tick) if on cooldown
```

## Class Bot Config Pattern

Each class bot file (mage.lua, shaman.lua) has a config block at the top:

```lua
local PET_SPELL   = "Elementalkin: Water"
local PET_REAGENT = "Malachite"
local PET_GEM     = 1

local BUFFS = {
    { spellName = "Minor Shielding", refreshTime = 600, targets = { "self" } },
}
local CAST_RANGE = 50
```

## Bot Name → Class Dispatch (bot/init.lua)

```lua
local NAME_MODULES = {
    Beta  = 'booty.bot.shaman',
    Gamma = 'booty.bot.mage',
}
```

Leader is hardcoded as `"Alpha"`. Offsets are configured per-bot name.

## Bot Design Principles

### States Are Stories

A state's `execute()` function should read like a plain-English description of what the bot does.
It should contain **no raw `mq.TLO` calls** and **no direct game commands** — all decisions and
commands belong in action modules.

```lua
-- Good — reads like a story
execute = function()
    local c, r
    c, r = combatActions.assistPC(LEADER, false, true)
    if c then timeLastNonIdleAction = os.clock(); return c, r end
    combatActions.disengage()
    c, r = movementActions.navFanFollow(LEADER, myOffset, FOLLOW_DIST)
    if c then timeLastNonIdleAction = os.clock(); return c, r end
    if idleEnough and not groupUtils.isGroupEngaged() then
        c, r = doIdleTasks()
        if c then return c, r end
    end
    return false, "Walking with " .. LEADER
end
```

### Action Modules Are Small, Testable Units

Each action module owns one domain. Functions are either **pure checks** or **actors**.

**Pure checks** — read client state, no side effects, return plain values (never `c, r`):
```lua
combatUtils.hasPet()           -- boolean
combatUtils.hasLiveTarget()    -- boolean
groupUtils.isGroupEngaged()    -- boolean
groupUtils.isPCEngaged(name)   -- boolean
```

**Actors** — issue exactly one game command, return `(c, r)`:
```lua
combatActions.assistPC(...)         -- targets + engages, one step per tick
movementActions.navFanFollow(...)   -- /nav or false if in range
spellActions.castSpell(name)        -- /cast or false if not ready
```

### Movement Handles Its Own Prerequisites

`navFanFollow` and `navToTarget` issue `/stand` if the bot is sitting and needs to move.
States do not manage standing before movement calls.

`combatActions.assistPC` issues `/stand` if sitting and combat is needed.
States do not manage standing before combat calls.

### `onEnter`/`onExit` May Use Raw Commands

Since they run once per transition (not every tick), `onEnter`/`onExit` may issue raw commands
directly: `/attack off`, `/squelch /nav stop`, `/stand`, etc.

## MQ2 Type Annotations

All MQ2 types are defined in `/home/julian/wine-eq/drive_c/MQ2/mq-definitions/mq/alias.lua`.

### Primitives — always call with `()` to get the value

| Annotation | Calling it returns |
|---|---|
| `MQBoolean` | `boolean` |
| `MQInt` | `integer` |
| `MQFloat` | `number` |
| `MQString` | `string` |

Example field on a `spawn`: `spawn.Level` is `MQFloat`, so `spawn.Level()` returns a `number`.

### Userdata types — `object | fun(): string|nil`

These are either the underlying class object **or** a callable that returns the string value (or nil if invalid). Call `spawn()` to check existence — nil means invalid.

| Annotation | Underlying class |
|---|---|
| `MQSpawn` | `spawn` |
| `MQTarget` | `target` |
| `MQSpell` | `spell` |
| `MQItem` | `item` |
| `MQBuff` | `buff` |
| `MQCharacter` | `character` |
| `MQGroupMember` | `groupmember` |
| `MQPet` | `pet` |
| `MQMercenary` | `mercenary` |
| `MQHeading` | `heading` |
| `MQZone` | `zone` |
| `MQWindow` | `window` — calls return `"TRUE"` or `"FALSE"` |

### When to use which annotation

- Returning `mq.TLO.Spawn(id)` → `---@return MQSpawn|nil`
- Returning `mq.TLO.Target` → `---@return MQTarget|nil`
- A spawn field like `spawn.TargetOfTarget` is typed `MQSpawn` in the definitions
- **Do NOT use `spawn` as a return type** when returning a TLO result — use `MQSpawn`
- **Do NOT use `--[[@as spawn]]` casts** — use the correct `MQ*` alias instead

### Checking validity

```lua
local s = mq.TLO.Spawn(id)
if s() then   -- calling with () checks if the TLO resolves to a valid object
    local name = s.Name()  -- MQString → string
end
```

## MQ2 TLO Notes

- `spawn.TargetOfTarget` = **what that spawn is currently targeting** (not target-of-their-target)
- `spawn.PlayerState` = bitmask: 0=Idle, 4=Aggressive, 8=ForcedAggressive, 2=Sheathed
- `Spell.WillLand()` = **number** (buff slot it will land in, 0 if it won't) — NOT a boolean
- `mq.TLO.Spawn(id)` returns `MQSpawn` — call `spawn()` to check if it exists
- For type annotations on returned TLO spawns: `---@return MQSpawn|nil`
