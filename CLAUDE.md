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
│   ├── init.lua          Bot entry point — shared states (IDLE/INIT/FOLLOW), dispatches by name
│   ├── fsm.lua           FSM engine: changeState(), update(), /setstate slash command
│   ├── shaman.lua        Shaman class states (SETUP/MELEE/FOLLOWANDEXP/MAKECAMPANDEXP)
│   ├── mage.lua          Mage class states (SETUP/MELEE/FOLLOWANDEXP/MAKECAMPANDEXP)
│   └── actions/
│       ├── combat.lua    isInCombat, hasLiveTarget, hasPet, attackOn/Off, disengage, sendPet, engageTarget
│       ├── melee.lua     getAssistTarget(pcName), targetPcTarget(pcName)
│       ├── movement.lua  navFanFollow, navToTarget, navToPC, navToPoint
│       ├── spell.lua     findGemForSpell, isSpellMemmed, isSpellReady, castSpell, castSummonPet, willLand
│       ├── buff.lua      castBuffList(BUFFS, gemSlotStart) — cast/rebuff cycle
│       ├── group.lua     isGroupEngaged, isPcEngaged, getEngagedTarget, isGrouped, navGroupInvite
│       └── util.lua      getPcTarget, resolveTargets, targetSpawn, targetByID
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

### combat.lua
```lua
combat.isInCombat()                              -- Me.Combat()
combat.hasLiveTarget()                            -- Target is live NPC
combat.hasPet()                                  -- Me.Pet.ID() > 0
combat.attackOn() / attackOff()
combat.disengage()                               -- attack off + pet back off (only if pet has target)
combat.sendPet(targetID)                         -- /pet attack if not already on target
combat.engageTarget(target, melee, pet)          -- target→sendPet→attackOn, one step per tick
combat.assistLeader(leaderName, melee, pet)      -- main combat entry point for states:
                                                 -- finds live NPC (leader target → XTargets),
                                                 -- stands if sitting, then engageTarget
```

### melee.lua
```lua
melee.getAssistTarget(pcName)   -- leader's target if live NPC, else nil
melee.targetPcTarget(pcName)    -- /tar id on leader's target
```

### group.lua
```lua
group.isGroupEngaged()          -- any XTarget entry exists
group.isPcEngaged(pcName)       -- spawn PlayerState & 12 (bits 4+8 = Aggressive/ForcedAggressive)
group.getEngagedTarget()        -- first live NPC from XTarget list, or nil
group.isGrouped()
group.navGroupInvite(leader, cooldown, dist)
```

### spell.lua
```lua
spell.willLand(spellName)           -- WillLand() > 0 (returns buff slot number, not bool!)
spell.castSpell(spellName)          -- mana+gem+ready checks, then /cast
spell.castSummonPet(name, gem, reagent)
spell.isSpellReady(spellName)
spell.findGemForSpell(spellName)
```

### buff.lua (actions)
```lua
-- BUFFS config format:
local BUFFS = {
    { spellName = "Inner Fire", refreshTime = 600, targets = { "self", "group" } },
}
buff.castBuffList(BUFFS, startGem)   -- iterates targets, checks willLand, casts if needed
```

`willLand` returns `false` when buff is already active (not expired) — this is correct, skip casting.

### util.lua
```lua
util.getPcTarget(pcName)        -- spawn.TargetOfTarget = what PC is currently targeting
util.resolveTargets(list)       -- "self"/"pet"/"group"/name → [{spawn, label}]
util.targetSpawn(spawn)         -- /tar id if not already targeted
util.targetByID(id)
```

### movement.lua
```lua
move.navFanFollow(leader, offset, dist)   -- fan formation follow
move.navToTarget(range)                   -- approach current target
move.navToPC(name, dist)
move.navToPoint(point, radius)            -- {x, y} point
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

## FOLLOWANDEXP Target Priority

```lua
-- 1. Leader has a live NPC target
local target = util.getPcTarget(LEADERNAME)
if target and target.ID() > 0 then
    return combat.engageTarget(target, false, true)
-- 2. No leader target, but group has XTargets
elseif group.isGroupEngaged() then
    local engTarget = group.getEngagedTarget()
    if engTarget then return combat.engageTarget(engTarget, false, true) end
-- 3. Nothing — disengage, follow, idle/med
else
    combat.disengage()
    -- navFanFollow, doIdleTasks...
end
```

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
