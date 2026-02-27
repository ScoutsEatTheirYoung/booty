# MacroQuest Lua API Reference

All base-install MQ Lua bindings in one place. No plugins required beyond what ships with MQ.

> **Sources:** `mq-definitions/` (lua type stubs), `lua_MQBindings.cpp`, `lua_EQBindings.cpp`, `lua_Globals.cpp`, `lua_ImGuiCore.cpp`, `lua_ImGuiWidgets.cpp`, `lua_ImGuiCustom.cpp`

**Calling convention reminder:** TLO members are *accessor objects* — append `()` to read the value.
```lua
mq.TLO.Me.Level     -- TLO object (not the number)
mq.TLO.Me.Level()   -- returns 50  ← you almost always want this
```

---

## Table of Contents

1. [The `mq` Module](#1-the-mq-module)
2. [Global Functions & Constants](#2-global-functions--constants)
3. [Top-Level Objects (TLOs)](#3-top-level-objects-tlos)
4. [Data Types](#4-data-types)
   - [spawn](#spawn)
   - [character (Me)](#character-extends-spawn)
   - [item](#item)
   - [spell](#spell)
   - [buff (extends spell)](#buff-extends-spell)
   - [altability](#altability)
   - [group](#group)
   - [groupmember (extends spawn)](#groupmember-extends-spawn)
   - [raid](#raid)
   - [raidmember (extends spawn)](#raidmember-extends-spawn)
   - [pet (extends spawn)](#pet-extends-spawn)
   - [corpse (extends spawn)](#corpse-extends-spawn)
   - [ground](#ground)
   - [currentzone / zone](#currentzone--zone)
   - [window](#window)
   - [fellowship](#fellowship)
   - [fellowshipmember](#fellowshipmember)
   - [mercenary (extends spawn)](#mercenary-extends-spawn)
   - [dynamiczone](#dynamiczone)
   - [xtarget (extends spawn)](#xtarget-extends-spawn)
   - [task](#task)
   - [bandolier](#bandolier)
   - [heading](#heading)
   - [achievement / achievementmgr](#achievementmgr)
   - [merchant](#merchant)
5. [ImGui Module](#imgui-module)
   - [Registration](#registration)
   - [Window Functions](#window-functions)
   - [Widgets](#widgets-all-return-statevalue)
   - [Layout](#layout)
   - [Tables](#tables)
   - [Trees, Tabs, Popups](#trees-tabs-popups)
   - [Styling](#styling)
   - [Tooltips](#tooltips)
   - [Menu Bar](#menu-bar)
   - [Draw Lists](#draw-lists)
   - [Textures in ImGui](#textures-in-imgui)
   - [Value Types (ImVec2, ImVec4, ImU32)](#value-types)
   - [Not Bound](#not-bound-c-exists-but-unavailable-in-lua)

---

## 1. The `mq` Module

```lua
local mq = require('mq')
```

### Core Functions

#### `mq.cmd(...)`
**Params:** `...string` — slash command parts, joined with spaces
**Returns:** nothing
Sends a slash command to EverQuest as if typed in chat.
```lua
mq.cmd('/sit')
mq.cmd('/target', 'id', '12345')  -- parts are joined: "/target id 12345"
```

#### `mq.cmdf(command, ...)`
**Params:** `command: string`, `...: any` — C-style format args
**Returns:** nothing
Like `mq.cmd()` with `string.format`-style interpolation.
```lua
mq.cmdf('/target id %d', spawnId)
mq.cmdf('/say HP is %d%%', mq.TLO.Me.PctHPs())
```

#### `mq.delay(value [, condition])`
**Params:** `value: number|string`, `condition?: () → boolean`
**Returns:** nothing
Yields execution for `value` ms (or `"2s"`, `"1m"`, `"500ms"`). If `condition` is provided, returns early when it returns `true`. **Required in every loop.**
```lua
mq.delay(100)
mq.delay('2s')
mq.delay(5000, function() return mq.TLO.Me.Casting() == nil end)
```

#### `mq.exit()`
**Returns:** nothing (script terminates)
Immediately terminates the running script.

#### `mq.gettime()`
**Returns:** `number` — milliseconds since epoch
Current time in milliseconds. Use for elapsed-time measurements.

#### `mq.join(delim, ...)`
**Params:** `delim: string`, `...: number|string`
**Returns:** `string`
Joins arguments into one string, inserting `delim` between non-empty values.

#### `mq.parse(macrostring)`
**Params:** `macrostring: string` — MQ2 `${}` expression
**Returns:** `string`
Evaluates an MQ2 macro expression and returns the result as a string.
```lua
local name = mq.parse('${Me.Name}')
```

#### `mq.pickle(filepath, table)`
**Params:** `filepath: string`, `table: table`
**Returns:** nothing
Serializes a Lua table to a file (MQ config format).

#### `mq.unpickle(filepath)`
**Params:** `filepath: string`
**Returns:** `table`
Deserializes a file written by `mq.pickle` back into a table.

#### `mq.gettype(value)`
**Params:** `value: any` — any TLO or type variable
**Returns:** `string` — MQ type name, e.g. `"character"`, `"spawn"`, or `nil`

#### `mq.NumericLimits_Float()`
**Returns:** `number FLT_MIN, number FLT_MAX`
Returns the minimum and maximum float values for use with ImGui drag/slider widgets.

---

### Slash Command Bindings

#### `mq.bind(command, callback)`
**Params:** `command: string` (e.g. `"/myscript"`), `callback: function`
**Returns:** nothing
Registers a custom slash command. Arguments typed after the command are passed as separate strings to `callback`.

#### `mq.unbind(command)`
**Params:** `command: string`
**Returns:** nothing
Removes a previously registered slash command binding.

---

### Events

#### `mq.event(name, matcherText, callback [, options])`
**Params:**
- `name: string` — unique event identifier
- `matcherText: string` — pattern; `#*#` = ignored wildcard, `#1#`/`#2#`/… = captured args
- `callback: function(line, cap1, cap2, ...)` — called on match
- `options?: EventOptions` — `{ keepLinks: boolean }`

**Returns:** nothing
Registers a chat event listener. **Requires `mq.doevents()` in the main loop.**

#### `mq.unevent(name)`
**Params:** `name: string`
Removes a registered event.

#### `mq.doevents([name])`
**Params:** `name?: string` — if given, process only that event
Dispatches all queued events to their callbacks. Call once per loop iteration.

#### `mq.flushevents([...])`
**Params:** zero or more event name strings
Discards queued events without processing. No args = flush all.

---

### Spawn / Ground Item Utilities

#### `mq.getAllSpawns()`
**Returns:** `spawn[]`
All spawns currently in the zone.

#### `mq.getFilteredSpawns(predicate)`
**Params:** `predicate: (spawn) → boolean`
**Returns:** `spawn[]`
Spawns for which `predicate` returns `true`.

#### `mq.getAllGroundItems()`
**Returns:** `ground[]`
All ground items currently in the zone.

#### `mq.getFilteredGroundItems(predicate)`
**Params:** `predicate: (ground) → boolean`
**Returns:** `ground[]`
Ground items for which `predicate` returns `true`.

---

### Textures

#### `mq.CreateTexture(fileName)`
**Params:** `fileName: string` — path to a `.dds` file
**Returns:** `MQTexture`
Loads a DDS texture from disk. Call once at startup, not inside a draw callback.

**`MQTexture` fields:**
| Field | Type | Description |
|-------|------|-------------|
| `size` | `ImVec2` | Texture pixel dimensions |
| `fileName` | `string` | Path used to load |

**`MQTexture` methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `tex:GetTextureID()` | `ImTextureID` | Handle for use with `ImGui.Image` |

#### `mq.FindTextureAnimation(name)`
**Params:** `name: string` — EQ UI animation name (e.g. `"A_DragItem"`)
**Returns:** `CTextureAnimation`
Finds a named EQ sprite-sheet animation. Use `"A_DragItem"` for item icons.

**`CTextureAnimation` methods:**
| Method | Description |
|--------|-------------|
| `anim:SetTextureCell(iconId)` | Select which cell (icon ID) to display |

---

### Text Link Utilities

#### `mq.StripTextLinks(text)`
**Params:** `text: string`
**Returns:** `string`
Removes all EQ chat link codes from a string.

#### `mq.FormatItemLink(item)`
**Params:** `item: MQItem`
**Returns:** `string`
Builds a clickable EQ item link string.

#### `mq.FormatSpellLink(spell)`
**Params:** `spell: MQSpell`
**Returns:** `string`
Builds a clickable EQ spell link string.

#### `mq.ExtractLinks(chatLine)`
**Params:** `chatLine: string`
**Returns:** `table` of link info objects
Extracts all embedded links from a chat line.

#### `mq.ParseItemLink(linkStr)`
**Params:** `linkStr: string`
**Returns:** `table` or `nil`
Parses a raw item link string into its components.

#### `mq.ExecuteTextLink(link)`
**Params:** `link: string`
Clicks/executes a text link (as if the player clicked it).

---

### TLO Management

#### `mq.GetDataTypeNames()`
**Returns:** `string[]`
Returns a list of all registered MQ data type names.

#### `mq.AddTopLevelObject(name, callback)`
**Params:** `name: string`, `callback: (index: string) → (typeName, typeValue)`
**Returns:** nothing
Registers a custom TLO accessible as `mq.TLO.<name>`.

#### `mq.RemoveTopLevelObject(name)`
**Params:** `name: string`
Unregisters a custom TLO.

---

### ImGui Registration (`mq.imgui`)

Legacy API — prefer `ImGui.Register` for new scripts.

| Function | Description |
|----------|-------------|
| `mq.imgui.init(name, callback)` | Register a draw callback (fires every frame) |
| `mq.imgui.destroy(name)` | Unregister a draw callback |
| `mq.imgui.exists(name) → boolean` | Check if a callback is registered |

---

### Path Constants

| Constant | Type | Example |
|----------|------|---------|
| `mq.configDir` | `string` | `"C:/MQ2/config"` |
| `mq.luaDir` | `string` | `"C:/MQ2/lua"` |
| `mq.moduleDir` | `string` | `"C:/MQ2/modules"` |

---

## 2. Global Functions & Constants

These are available without any `require` or prefix.

#### `printf(format, ...)`
**Params:** `format: string`, `...: any`
Equivalent to `print(string.format(format, ...))`. Outputs to EQ chat.

#### `print(...)`
Standard Lua `print`, outputs to EQ chat window.

#### `bit32` library
Available globally. See [bit32 Operations](#bit32-operations) below.

### Chat Color Codes

Embed in any string sent to `print()` or `/echo`:

| Code | Color |
|------|-------|
| `\ag` | Green |
| `\ar` | Red |
| `\ay` | Yellow |
| `\ab` | Blue (dark) |
| `\at` | Teal |
| `\am` | Magenta/Purple |
| `\aw` | White |
| `\ao` | Orange |
| `\ax` | Reset to default |

### `bit32` Operations

```lua
bit32.bor(a, b, ...)   -- bitwise OR  (combine flags)
bit32.band(a, b, ...)  -- bitwise AND (test flags)
bit32.bxor(a, b, ...)  -- bitwise XOR (toggle flags)
bit32.bnot(a)          -- bitwise NOT (invert)
bit32.lshift(a, n)     -- left shift by n bits
bit32.rshift(a, n)     -- right shift by n bits
```

---

## 3. Top-Level Objects (TLOs)

All TLOs live under `mq.TLO`. Call members as functions to get values.

### Me
```lua
mq.TLO.Me  → character
```
Your own character. See [character](#character-extends-spawn) type.

---

### Target
```lua
mq.TLO.Target  → target (extends spawn)
```
Your current target. Returns `nil` (calling `()` returns falsy) when nothing is targeted. Has all [spawn](#spawn) fields plus target-specific ones.

---

### Spawn
```lua
mq.TLO.Spawn(id: integer)         → spawn
mq.TLO.Spawn(filter: string)      → spawn
```
Finds a spawn by numeric ID or [spawn search filter](#spawn-search-filters). Returns `nil` if not found.

---

### NearestSpawn
```lua
mq.TLO.NearestSpawn(n: integer, filter: string)  → spawn
mq.TLO.NearestSpawn(filter: string)              → spawn  -- nearest = #1
```
Returns the Nth nearest spawn matching `filter`.

---

### SpawnCount
```lua
mq.TLO.SpawnCount(filter: string)  → integer
```
Count of spawns matching the filter string. Call `()` to get the number.

---

### Zone
```lua
mq.TLO.Zone              → currentzone   (current zone)
mq.TLO.Zone()            → currentzone
mq.TLO.Zone(id: integer) → zone          (any zone by ID)
mq.TLO.Zone(name: string)→ zone          (any zone by short name)
```
See [currentzone / zone](#currentzone--zone) type.

---

### FindItem
```lua
mq.TLO.FindItem(name: string)  → item   -- partial match; prefix '=' for exact
mq.TLO.FindItem(id: integer)   → item
```
Searches all bags and worn slots. Returns `nil` if not found.

### FindItemCount
```lua
mq.TLO.FindItemCount(name: string)  → integer
mq.TLO.FindItemCount(id: integer)   → integer
```
Total count of matching items across all stacks in bags/worn slots.

### FindItemBank
```lua
mq.TLO.FindItemBank(name: string)  → item
mq.TLO.FindItemBank(id: integer)   → item
```
Like `FindItem` but searches the bank instead.

### FindItemBankCount
```lua
mq.TLO.FindItemBankCount(name: string)  → integer
mq.TLO.FindItemBankCount(id: integer)   → integer
```

---

### Cursor
```lua
mq.TLO.Cursor  → item
```
The item currently on your cursor (held from inventory). `nil` / falsy when empty. See [item](#item) type.

---

### Corpse
```lua
mq.TLO.Corpse  → corpse
```
Only valid when a loot window is open. See [corpse](#corpse-extends-spawn) type.

---

### Group
```lua
mq.TLO.Group  → group
```
Your current group. See [group](#group) type.

---

### Raid
```lua
mq.TLO.Raid  → raid
```
Your current raid. See [raid](#raid) type.

---

### Pet
```lua
mq.TLO.Pet  → pet
```
Your current pet. See [pet](#pet-extends-spawn) type.

---

### Ground
```lua
mq.TLO.Ground  → ground
```
The ground item you currently have targeted (via `/itemtarget`). See [ground](#ground) type.

### GroundItemCount
```lua
mq.TLO.GroundItemCount(filter?: string)  → integer
```
Number of ground items in the zone matching the optional filter.

---

### MacroQuest
```lua
mq.TLO.MacroQuest  → macroquest
```

| Field | Type | Description |
|-------|------|-------------|
| `BuildDate` | `string` | Date MQ2Main.dll was built |
| `BuildName` | `string` | Build name: `"Live"`, `"Test"`, `"Emu"` |
| `Error` | `string` | Last normal error message |
| `GameState` | `string` | `"INGAME"`, `"CHARSELECT"`, `"PRECHARSELECT"`, `"UNKNOWN"` |
| `LastCommand` | `string` | Last command entered |
| `LastTell` | `string` | Name of last person to tell you |
| `LoginName` | `string` | Your station/login name |
| `MouseX` | `number` | Mouse X screen position |
| `MouseY` | `number` | Mouse Y screen position |
| `Path(relativePath?)` | `string` | MQ directory path; pass relative path to append |
| `Ping` | `number` | Current ping in ms |
| `Running` | `number` | MQ session uptime in ms |
| `Server` | `string` | Full server name |
| `SyntaxError` | `string` | Last syntax error message |
| `Version` | `string` | MQ version string |
| `ViewportX` | `number` | EQ viewport upper-left X |
| `ViewportY` | `number` | EQ viewport upper-left Y |
| `ViewportXMax` | `number` | EQ viewport lower-right X |
| `ViewportYMax` | `number` | EQ viewport lower-right Y |
| `ViewportXCenter` | `number` | EQ viewport center X |
| `ViewportYCenter` | `number` | EQ viewport center Y |

---

### EverQuest
```lua
mq.TLO.EverQuest  → everquest
```

| Field | Type | Description |
|-------|------|-------------|
| `CharSelectList(n)` | `charselectlist` | Character at index n on the char select screen |
| `ChatChannel(n)` | `string` | Name of joined channel at index n |
| `ChatChannels` | `number` | Number of currently joined channels |
| `CurrentUI` | `string` | Currently loaded UI skin name |
| `Foreground` | `boolean` | Is EQ in the foreground? |
| `GameState` | `string` | `"INGAME"`, `"CHARSELECT"`, `"PRECHARSELECT"`, `"UNKNOWN"` |
| `HWND` | `number` | Window handle |
| `IsDefaultUILoaded` | `boolean` | Is the default UI skin loaded? |
| `LastCommand` | `string` | Last command entered |
| `LastMouseOver()` | `window` | Last window the mouse was over |
| `LastTell` | `string` | Last person who sent you a tell |
| `LayoutCopyInProgress` | `boolean` | Is a layout copy in progress? |
| `LoginName` | `string` | Station name |
| `MouseX` | `number` | Mouse X |
| `MouseY` | `number` | Mouse Y |
| `Path` | `string` | Path to EverQuest folder |
| `PID` | `number` | Process ID |
| `Ping` | `number` | Current ping |
| `PPriority` | `number` | Processor priority |
| `Running` | `number` | Session uptime in ms |
| `ScreenMode` | `number` | Screen mode (2=Normal, 3=No Windows) |
| `Server` | `string` | Full server name |
| `ValidLoc(coords)` | `boolean` | Are the given coordinates valid? |
| `ViewportX/Y/XMax/YMax/XCenter/YCenter` | `number` | Viewport dimensions |
| `WinTitle` | `string` | EverQuest window title bar text |

---

### Window
```lua
mq.TLO.Window(name: string)  → window
```
Access any EQ UI window by name (e.g. `"InventoryWnd"`, `"SpellBookWnd"`). See [window](#window) type.

---

### Navigation
```lua
mq.TLO.Navigation  → Navigation
```
Requires MQ2Nav to be loaded (included in base MQ).

| Field/Method | Type | Description |
|---|---|---|
| `Active` | `boolean` | Navigation is currently active |
| `Paused` | `boolean` | Navigation is paused |
| `MeshLoaded` | `boolean` | A navmesh is loaded for the current zone |
| `Velocity` | `number` | Current movement velocity |
| `PathExists(params: string)` | `boolean` | Can navigate to the given target? |
| `PathExists(target: spawn)` | `boolean` | Can navigate to this spawn? |
| `PathLength(params: string)` | `number` | Length of path if one exists |
| `PathLength(target: spawn)` | `number` | Length of path to this spawn |

---

### Achievement
```lua
mq.TLO.Achievement  → achievementmgr
```
See [achievementmgr](#achievementmgr) type.

---

### Task
```lua
mq.TLO.Task              → task   (first task / shared task)
mq.TLO.Task(n: integer)  → task
mq.TLO.Task(name: string)→ task
```
See [task](#task) type.

---

### Mercenary
```lua
mq.TLO.Me.Mercenary  → mercenary
```
Your active mercenary. See [mercenary](#mercenary-extends-spawn) type.

---

### DynamicZone
```lua
mq.TLO.DynamicZone  → dynamiczone
```
See [dynamiczone](#dynamiczone) type.

---

### Merchant
```lua
mq.TLO.Merchant  → merchant
```
The currently open merchant. See [merchant](#merchant) type.

---

### AltAbility
```lua
mq.TLO.AltAbility(name: string)  → altability
mq.TLO.AltAbility(id: integer)   → altability
```
Look up any AA ability. See [altability](#altability) type.

---

### Spell
```lua
mq.TLO.Spell(name: string)  → spell
mq.TLO.Spell(id: integer)   → spell
```
Look up any spell by name or ID. See [spell](#spell) type.

---

### Skill
```lua
mq.TLO.Skill(name: string)   → skill
mq.TLO.Skill(id: integer)    → skill
```

| Field | Type | Description |
|-------|------|-------------|
| `ID` | `number` | Skill ID |
| `Name` | `string` | Skill name |

---

### Plugin
```lua
mq.TLO.Plugin(name: string)   → plugin
mq.TLO.Plugin(index: integer) → plugin
```

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Plugin name |
| `Version` | `string` | Plugin version |

---

### Heading
```lua
mq.TLO.Heading(degrees: number)         → heading
mq.TLO.Heading(y: number, x: number)    → heading
```
Creates a heading object. See [heading](#heading) type.

---

### InvSlot
```lua
mq.TLO.InvSlot(name: string)  → invslot
mq.TLO.InvSlot(id: number)    → invslot
```
Looks up an inventory slot by name or number.

---

### Alert
```lua
mq.TLO.Alert()              → string   (pipe-separated list of alert IDs)
mq.TLO.Alert(id: integer)   → alert
```

---

### Social
```lua
mq.TLO.Social(index: integer)  → social
```
Returns the social button at `index` (0–119).

---

### Mount / Illusion / Familiar (Keyring)
```lua
mq.TLO.Mount(index: integer)  → keyringitem
mq.TLO.Mount(name: string)    → keyringitem   -- prefix '=' for exact match
```

| Field | Type | Description |
|-------|------|-------------|
| `Index` | `number` | Keyring slot index |
| `Name` | `string` | Item name |
| `ItemID` | `number` | Item ID |

---

### Spawn Search Filters

Used with `Spawn()`, `NearestSpawn()`, `SpawnCount()`. Combine multiple keywords in one string.

| Token | Matches |
|-------|---------|
| `npc` | Any NPC |
| `pc` | Any player character |
| `corpse` | Any corpse |
| `pet` | Any pet |
| `mercenary` | Any mercenary |
| `id <n>` | Spawn with ID n |
| `name <text>` | Name contains text |
| `radius <n>` | Within n units |
| `zradius <n>` | Within n units vertically |
| `los` | Line of sight |
| `noalert` | Not on any alert list |
| `alert <id>` | On alert list with given ID |
| `class <name>` | Specific class |
| `race <name>` | Specific race |
| `guild <name>` | Specific guild |
| `level <n>` | Exact level |
| `minlevel <n>` | At least level n |
| `maxlevel <n>` | At most level n |

---

## 4. Data Types

### `spawn`

Base type for all in-game entities (players, NPCs, pets, etc.). Accessed via `mq.TLO.Target`, `mq.TLO.Spawn()`, group members, etc.

#### Identity & Classification

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Spawn name |
| `CleanName` | `string` | Name without guild tag, rank suffix, etc. |
| `DisplayName` | `string` | Name as displayed in-game (same as EQ's `%T`) |
| `Surname` | `string` | Last name |
| `Title` | `string` | Prefix/title before the name |
| `Suffix` | `string` | Suffix, e.g. `"of <servername>"` |
| `ID` | `number` | Unique spawn ID |
| `Level` | `number` | Level |
| `Class` | `class` | Class object |
| `Race` | `race` | Race object |
| `Body` | `body` | Body type object |
| `Deity` | `deity` | Deity object |
| `Type` | `string` | `"PC"`, `"NPC"`, `"Corpse"`, `"Pet"`, `"Mercenary"`, `"Mount"`, `"Chest"`, `"Trigger"`, `"Trap"`, `"Timer"`, `"Item"`, `"Aura"`, `"Object"`, `"Banner"`, `"Campfire"`, `"Flyer"`, `"Untargetable"` |
| `Guild` | `string` | Guild name |
| `GuildStatus` | `string` | Guild rank (`"Leader"`, `"Officer"`, `"Member"`) |
| `GM` | `boolean` | Is a GM or Guide? |
| `GMRank` | `number` | GM rank |

#### Health & Resources

| Field | Type | Description |
|-------|------|-------------|
| `CurrentHPs` | `number` | Current hit points |
| `MaxHPs` | `number` | Maximum hit points |
| `PctHPs` | `number` | HP as a percentage (0–100) |
| `CurrentMana` | `number` | Current mana (updates when targeted/grouped) |
| `MaxMana` | `number` | Maximum mana |
| `PctMana` | `number` | Mana as a percentage |
| `CurrentEndurance` | `number` | Current endurance |
| `MaxEndurance` | `number` | Maximum endurance |
| `PctEndurance` | `number` | Endurance as a percentage |

#### Position & Movement

| Field | Type | Description |
|-------|------|-------------|
| `X` | `number` | X coordinate (East/West) |
| `Y` | `number` | Y coordinate (North/South) |
| `Z` | `number` | Z coordinate (height) |
| `N` | `number` | Alias for Y (Northward-positive) |
| `W` | `number` | Alias for X (Westward-positive) |
| `U` | `number` | Alias for Z (Upward-positive) |
| `E` | `number` | Shortcut for -X (Eastward-positive) |
| `S` | `number` | Shortcut for -Y (Southward-positive) |
| `D` | `number` | Shortcut for -Z (Downward-positive) |
| `Heading` | `heading` | Direction the spawn is facing |
| `HeadingTo` | `heading` | Heading the player must travel to reach this spawn |
| `Distance` | `number` | 2D distance (X,Y) from player |
| `Distance3D` | `number` | 3D distance (X,Y,Z) from player |
| `DistanceN` | `number` | Distance in the Y (North/South) axis |
| `DistanceW` | `number` | Distance in the X (East/West) axis |
| `DistanceU` | `number` | Distance in the Z (Up/Down) axis |
| `DistanceX` | `number` | Distance in X plane |
| `DistanceY` | `number` | Distance in Y plane |
| `DistanceZ` | `number` | Distance in Z plane |
| `DistancePredict` | `number` | Estimated distance accounting for spawn movement |
| `Speed` | `number` | Movement speed |
| `Moving` | `boolean` | Is moving? |
| `Loc` | `string` | Location string (MQ format) |
| `LocYX` | `string` | Location string (Y,X) |
| `LocYXZ` | `string` | Location string (Y,X,Z) |
| `EQLoc` | `string` | Location string (EQ format) |
| `MQLoc` | `string` | Location string (MQ format) |
| `FloorZ` | `number` | Z coordinate of the floor at current location |
| `Height` | `number` | Spawn height (model height) |
| `Levitating` | `boolean` | Is levitating? |

#### State & Status

| Field | Type | Description |
|-------|------|-------------|
| `Standing` | `boolean` | Standing? |
| `Sitting` | `boolean` | Sitting? |
| `Ducking` | `boolean` | Ducking? |
| `Feigning` | `boolean` | Feigning death? |
| `Hovering` | `boolean` | Hovering (corpse state)? |
| `Dead` | `boolean` | Dead? |
| `Stunned` | `boolean` | Stunned? |
| `Stuck` | `boolean` | Stuck? |
| `Sneaking` | `boolean` | Sneaking? |
| `IsBerserk` | `boolean` | Berserk? |
| `Underwater` | `boolean` | Underwater? |
| `FeetWet` | `boolean` | Feet wet / swimming? |
| `HeadWet` | `boolean` | Head submerged? |
| `AFK` | `boolean` | AFK? |
| `Anonymous` | `boolean` | Anonymous? |
| `Roleplaying` | `boolean` | Roleplaying flag? |
| `LFG` | `boolean` | Looking for group? |
| `Linkdead` | `boolean` | Linkdead? |
| `Invited` | `boolean` | Invited to group? |
| `Inviter` | `string` | Name of person who invited |
| `Trader` | `boolean` | Is a trader? |
| `Buyer` | `boolean` | Is a buyer (bazaar)? |
| `Binding` | `boolean` | Binding wounds? |
| `DraggingPlayer` | `boolean` | Currently dragging someone? |
| `DragNames` | `string` | Names of players being dragged |
| `Aggressive` | `boolean` | Is aggressive towards you? |
| `State` | `string` | `"STAND"`, `"SIT"`, `"DUCK"`, `"BIND"`, `"FEIGN"`, `"DEAD"`, `"STUN"`, `"HOVER"`, `"MOUNT"`, `"UNKNOWN"` |
| `StandState` | `number` | Stand state ID |
| `PlayerState` | `number` | Bitmask: 0=Idle, 1=Open, 2=Sheathed, 4=Aggressive, 8=ForcedAggressive, 0x10=Instrument, 0x20=Stunned, 0x40=PrimaryWeapon, 0x80=SecondaryWeapon |
| `ConColor` | `string` | Con color: `"GREY"`, `"GREEN"`, `"LIGHT BLUE"`, `"BLUE"`, `"WHITE"`, `"YELLOW"`, `"RED"` |
| `Named` | `boolean` | Is a "named" NPC (name doesn't start with "a"/"an")? |
| `Animation` | `number` | Current animation ID |

#### Group & Raid

| Field | Type | Description |
|-------|------|-------------|
| `GroupLeader` | `boolean` | Is a group leader? |
| `Assist` | `boolean` | Is the current raid/group assist target? |
| `AssistName` | `string` | Name of the assist target |
| `Mark` | `number` | Raid/group mark number |
| `LineOfSight` | `boolean` | Is this spawn in line of sight? |
| `CanSplashLand` | `boolean` | Can a splash spell land on this target? |

#### Relations

| Field | Type | Description |
|-------|------|-------------|
| `Master` | `spawn` | Master (if charmed or a pet) |
| `Owner` | `spawn` | Owner (if a mercenary) |
| `Pet` | `pet` | The spawn's pet |
| `Mount` | `spawn` | The spawn's mount |
| `Following` | `spawn` | Who this spawn is /following |
| `TargetOfTarget` | `spawn` | This spawn's current target |
| `Next` | `spawn` | Next spawn in the linked list |
| `Prev` | `spawn` | Previous spawn in the linked list |

#### Equipment

| Field | Type | Description |
|-------|------|-------------|
| `Primary` | `number` | Item ID in primary slot |
| `Secondary` | `number` | Item ID in secondary slot |
| `Equipment(slot)` | `number` | Item ID for slot 0–8 or named slot |
| `Holding` | `number` | Item being held |

#### Buffs (on targeted/grouped spawns)

| Method | Returns | Description |
|--------|---------|-------------|
| `Buff(index?)` | `CachedBuff` | Buff at slot index |
| `Buff(name)` | `CachedBuff` | First buff matching name |
| `BuffCount()` | `number` | Number of cached buffs |
| `CachedBuff(id)` | `CachedBuff` | Cached buff by spell ID or predicate |
| `MyBuff(index?)` | `CachedBuff` | Buff you cast on this spawn |
| `MyBuff(name)` | `CachedBuff` | Your buff by name |
| `MyBuffDuration(index?)` | `ticks` | Remaining duration of your buff |
| `MyBuffDuration(name)` | `ticks` | Remaining duration of your named buff |
| `FindBuff(predicate)` | `buff` | Find buff matching predicate string |

#### Actions (callable as methods, no `()` needed)

| Field | Description |
|-------|-------------|
| `DoTarget` | Targets this spawn |
| `DoFace` | Faces this spawn |
| `DoAssist` | Assists this spawn |
| `LeftClick` | Left-clicks the spawn |
| `RightClick` | Right-clicks the spawn |

#### Other

| Field/Method | Type | Description |
|---|---|---|
| `Casting` | `spell` | Currently casting spell (accurate only on yourself) |
| `Invis(option?)` | `boolean` | Is invisible? Options: `"ANY"`, `"NORMAL"`, `"UNDEAD"`, `"ANIMAL"`, `"SOS"` |
| `NearestSpawn` | `spawn` | Nearest spawn matching a search filter, relative to this spawn |
| `CeilingHeightAtCurrLocation` | `number` | Ceiling height at current position |
| `MaxRange` | `number` | Max distance from this spawn to hit you |
| `MaxRangeTo` | `number` | Max distance from this spawn for you to hit it |

---

### `character` (extends spawn)

Accessed via `mq.TLO.Me`. Inherits all `spawn` fields.

#### Stats

| Field | Type | Description |
|-------|------|-------------|
| `STR` | `number` | Strength (with gear/spells) |
| `STA` | `number` | Stamina |
| `AGI` | `number` | Agility |
| `DEX` | `number` | Dexterity |
| `INT` | `number` | Intelligence |
| `WIS` | `number` | Wisdom |
| `CHA` | `number` | Charisma |
| `BaseSTR/STA/CHA/DEX/INT/AGI/WIS` | `number` | Base stats (no gear/buffs) |
| `HeroicSTRBonus` / `HeroicSTABonus` / etc. | `number` | Heroic stat bonuses from gear |
| `svFire/svCold/svMagic/svPoison/svDisease/svCorruption` | `number` | Resist values |
| `svChromatic` | `number` | Lowest resist |
| `svPrismatic` | `number` | Average of all resists |
| `AttackBonus` | `number` | Attack bonus from gear/spells |
| `AccuracyBonus` | `number` | Accuracy bonus |
| `AvoidanceBonus` | `number` | Avoidance bonus |
| `CombatEffectsBonus` | `number` | Combat effects bonus |
| `DamageShieldBonus` | `number` | Damage shield bonus |
| `DamageShieldMitigationBonus` | `number` | DS mitigation bonus |
| `DoTShieldBonus` | `number` | DoT shield bonus |
| `ShieldingBonus` | `number` | Shielding bonus |
| `SpellDamageBonus` | `number` | Spell damage bonus |
| `SpellShieldBonus` | `number` | Spell shield bonus |
| `HealAmountBonus` | `number` | Heal amount bonus |
| `ClairvoyanceBonus` | `number` | Clairvoyance bonus |
| `StrikeThroughBonus` | `number` | Strikethrough bonus |
| `StunResistBonus` | `number` | Stun resist bonus |
| `Haste` | `number` | Total haste (worn + spell) |
| `AttackSpeed` | `number` | Attack speed (100 = base, 141 = 41% haste item) |

#### Resources

| Field | Type | Description |
|-------|------|-------------|
| `CurrentHPs` | `number` | Current HP |
| `MaxHPs` | `number` | Max HP |
| `PctHPs` | `number` | HP % |
| `CurrentMana` | `number` | Current mana |
| `MaxMana` | `number` | Max mana |
| `PctMana` | `number` | Mana % |
| `CurrentEndurance` | `number` | Current endurance |
| `MaxEndurance` | `number` | Max endurance |
| `PctEndurance` | `number` | Endurance % |
| `HPRegen` | `number` | HP regen from last tick |
| `HPRegenBonus` | `number` | HP regen bonus from gear/spells |
| `ManaRegen` | `number` | Mana regen from last tick |
| `ManaRegenBonus` | `number` | Mana regen bonus |
| `EnduranceRegen` | `number` | Endurance regen from last tick |
| `EnduranceRegenBonus` | `number` | Endurance regen bonus |
| `HPBonus` | `number` | HP bonus from gear/spells |
| `ManaBonus` | `number` | Mana bonus from gear/spells |
| `EnduranceBonus` | `number` | Endurance bonus from gear/spells |
| `Dar` | `number` | Damage absorption remaining (Rune-type spells) |
| `Counters` | `number` | Damage absorption counters remaining |
| `TotalCounters` | `number` | Total spell counters |
| `CountersPoison` | `number` | Poison counters |
| `CountersDisease` | `number` | Disease counters |
| `CountersCurse` | `number` | Curse counters |
| `CountersCorruption` | `number` | Corruption counters |

#### Identity & Progression

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | First name |
| `Surname` | `string` | Last name |
| `Level` | `number` | Character level |
| `Exp` | `number` | Experience (0–10,000) |
| `PctExp` | `number` | Experience as % |
| `AAExp` | `number` | AA exp (0–10,000) |
| `PctAAExp` | `number` | AA exp as % |
| `AAPoints` | `number` | Unspent AA points |
| `AAPointsSpent` | `number` | AA points spent |
| `AAPointsTotal` | `number` | Total AA points earned |
| `AAVitality` | `number` | Total AA vitality |
| `PctAAVitality` | `number` | AA vitality % |
| `Vitality` | `number` | Total vitality |
| `PctVitality` | `number` | Vitality % |
| `ExpansionFlags` | `number` | Bitmask of owned expansions |
| `HaveExpansion(n)` | `boolean` | Do you own expansion number n? |
| `Subscription` | `string` | `"GOLD"`, `"SILVER"`, `"FREE"`, `"UNKNOWN"` |
| `SubscriptionDays` | `number` | Days until All Access expires |
| `Shrouded` | `boolean` | Currently shrouded? |
| `InInstance` | `boolean` | In an instance? |
| `Instance` | `number` | Instance ID (0 if not in one) |
| `SpellRankCap` | `number` | 1=Rk.I, 2=Rk.II, 3=Rk.III |

#### Combat & State

| Field | Type | Description |
|-------|------|-------------|
| `Combat` | `boolean` | In combat? |
| `CombatState` | `string` | `"COMBAT"`, `"DEBUFFED"`, `"COOLDOWN"`, `"ACTIVE"`, `"RESTING"`, `"UNKNOWN"` |
| `SpellInCooldown` | `boolean` | Is any spell on global cooldown? |
| `ActiveDisc` | `spell` | Active melee discipline spell |
| `AltTimerReady` | `boolean` | Alternate timer ready (Bash/Slam/Frenzy/Backstab)? |
| `AutoFire` | `boolean` | Auto-fire enabled? |
| `BardSongPlaying` | `boolean` | Is a bard song playing? |
| `RangedReady` | `boolean` | Ranged attack ready? |
| `Running` | `boolean` | Auto-run enabled? |
| `Moving` | `boolean` | Moving (including strafe)? |
| `Zoning` | `boolean` | Currently zoning? |
| `PctAggro` | `number` | Your aggro % |
| `SecondaryPctAggro` | `number` | Secondary aggro % |
| `SecondaryAggroPlayer` | `spawn` | Secondary aggro player spawn info |
| `AggroLock` | `spawn` | Aggro lock player spawn info |
| `AssistComplete` | `boolean` | Assist action complete? |
| `Stunned` | `boolean` | Stunned? |
| `Downtime` | `ticks` | Ticks until combat timer ends |
| `TributeActive` | `boolean` | Tribute active? |
| `TributeTimer` | `ticks` | Ticks until next tribute cost |
| `ActiveFavorCost` | `number` | Tribute cost per 10 min (nil if inactive) |
| `CareerFavor` | `number` | Career tribute earned |
| `CurrentFavor` | `number` | Current tribute points |

#### Debuff Detection

| Field | Type | Description |
|-------|------|-------------|
| `Charmed` | `string` | Name of active charm spell |
| `Corrupted` | `spell` | Active corruption debuff |
| `Cursed` | `spell` | Active curse debuff |
| `Diseased` | `buff` | Active disease effect |
| `Dotted` | `string` | Name of first DoT on character |
| `Feared` | `buff` | Active fear effect |
| `Mezzed` | `buff` | First mez effect |
| `Poisoned` | `buff` | Active poison effect |
| `Rooted` | `buff` | Active root effect |
| `Silenced` | `buff` | Active silence effect |
| `Snared` | `buff` | Active snare effect |
| `Tashed` | `buff` | Active tash effect |
| `Invulnerable` | `string` | Name of active invulnerability effect |

#### Currency

| Field | Type | Description |
|-------|------|-------------|
| `Platinum` | `number` | Platinum on person |
| `Gold` | `number` | Gold on person |
| `Silver` | `number` | Silver on person |
| `Copper` | `number` | Copper on person |
| `PlatinumBank` | `number` | Platinum in bank |
| `GoldBank` | `number` | Gold in bank |
| `SilverBank` | `number` | Silver in bank |
| `CopperBank` | `number` | Copper in bank |
| `PlatinumShared` | `number` | Platinum in shared bank |
| `Cash` | `number` | Total cash on person in coppers |
| `CashBank` | `number` | Total bank cash in coppers |
| `Chronobines` | `number` | Chronobines |
| `Doubloons` | `number` | Doubloons |
| `Orux` | `number` | Orux |
| `Phosphenes` | `number` | Phosphenes |
| `Phosphites` | `number` | Phosphites |
| `Faycites` | `number` | Faycites |
| `EbonCrystals` | `number` | Ebon Crystals |
| `RadiantCrystals` | `number` | Radiant Crystals |
| `LDoNPoints` | `number` | Available LDoN points |
| `GukEarned` | `number` | LDoN points earned in Deepest Guk |
| `MirEarned` | `number` | LDoN points earned in Miragul's |
| `MMEarned` | `number` | LDoN points earned in Mistmoore |
| `RujEarned` | `number` | LDoN points earned in Rujarkian |
| `TakEarned` | `number` | LDoN points earned in Takish |
| `AltCurrency(name)` | `number` | Amount of any named alternate currency |

#### Group & Social

| Field | Type | Description |
|-------|------|-------------|
| `Grouped` | `boolean` | In a group? |
| `GroupSize` | `number` | Group size including yourself |
| `AmIGroupLeader` | `boolean` | Are you the group leader? |
| `GroupList` | `string` | Comma-separated list of group members (not you) |
| `GroupLeaderExp` | `number` | Group leadership exp (0–330) |
| `PctGroupLeaderExp` | `number` | Group leadership exp % |
| `GroupLeaderPoints` | `number` | Group leadership points |
| `RaidLeaderExp` | `number` | Raid leadership exp (0–330) |
| `PctRaidLeaderExp` | `number` | Raid leadership exp % |
| `RaidLeaderPoints` | `number` | Raid leadership points |
| `Trader` | `boolean` | Currently a trader? |
| `Buyer` | `boolean` | Currently a buyer? |
| `Fellowship` | `fellowship` | Fellowship info |
| `GuildID` | `number` | Your guild ID |
| `UseAdvancedLooting` | `boolean` | Using advanced looting? |
| `CanMount` | `boolean` | Can mount in current zone? |
| `TargetOfTarget` | `target` | Target of Target (requires ToT window active) |
| `GroupAssistTarget` | `target` | Target of Group Main Assist |
| `Mercenary` | `mercenary` | Your active mercenary |
| `MercenaryStance` | `string` | Active mercenary stance string |

#### Inventory

| Method | Returns | Description |
|--------|---------|-------------|
| `Inventory(name)` | `item` | Item in named slot (see slot table below) |
| `Inventory(n)` | `item` | Item in slot number n |
| `Bank(n)` | `item` | Item in bank slot n |
| `SharedBank(n)` | `item` | Item in shared bank slot n |
| `FreeInventory(minSize?)` | `number` | Free inventory spaces (optionally of at least `minSize`) |
| `NumBagSlots` | `number` | Total bag slots |
| `LargestFreeInventory` | `number` | Largest free inventory size |
| `CurrentWeight` | `number` | Current carried weight |

**Worn Slot Names:**

| # | Name | # | Name |
|---|------|---|------|
| 0 | `charm` | 12 | `hands` |
| 1 | `leftear` | 13 | `primary` |
| 2 | `head` | 14 | `secondary` |
| 3 | `face` | 15 | `leftfinger` |
| 4 | `rightear` | 16 | `rightfinger` |
| 5 | `neck` | 17 | `chest` |
| 6 | `shoulder` | 18 | `legs` |
| 7 | `arms` | 19 | `feet` |
| 8 | `back` | 20 | `waist` |
| 9 | `leftwrist` | 21 | `powersource` |
| 10 | `rightwrist` | 22 | `ammo` |
| 11 | `range` | 22+ | `pack1`–`pack10` |

#### Buffs & Songs

| Method | Returns | Description |
|--------|---------|-------------|
| `Buff(name)` | `buff` | Buff by name |
| `Buff(n)` | `buff` | Buff in slot n |
| `Song(name)` | `buff` | Short-duration buff (song) by name |
| `Song(n)` | `buff` | Song in slot n |
| `PetBuff(name)` | `buff` | Your pet's buff by name |
| `PetBuff(n)` | `buff` | Your pet's buff in slot n |
| `CountBuffs` | `number` | Number of long-duration buffs active |
| `CountSongs` | `number` | Number of songs active |
| `FreeBuffSlots` | `number` | Open long-duration buff slots |
| `MaxBuffSlots` | `number` | Maximum total buff slots |
| `SPA(spaId)` | `number` | Buff slot ID of the buff providing the given SPA |
| `BlockedBuff(name\|id)` | `spell` | A blocked buff by name or spell ID |
| `BlockedPetBuff(name\|n)` | `spell` | A blocked pet buff |

#### Spells & Casting

| Method | Returns | Description |
|--------|---------|-------------|
| `Gem(n)` | `spell` | Spell memorized in gem slot n |
| `Gem(name)` | `number` | Gem slot number where this spell is memorized |
| `GemTimer(n)` | `ticks` | Ticks until gem n is ready (0 = ready) |
| `GemTimer(name)` | `ticks` | Timer for named spell gem |
| `NumGems` | `number` | Number of spell gem slots your class has |
| `SpellReady(name)` | `boolean` | Is named spell ready to cast? |
| `SpellReady(n)` | `boolean` | Is gem n ready to cast? |
| `ItemReady(name)` | `boolean` | Is the named clickable item ready? |
| `Book(name)` | `number` | Spellbook slot number for this spell name |
| `Book(n)` | `spell` | Spell in spellbook slot n |
| `Spell(name)` | `spell` | Ranked version of a scribed spell |
| `Casting` | `spell` | Currently casting spell |
| `CastTimeLeft` | `timestamp` | Remaining cast time on current cast |

#### Abilities & AAs

| Method | Returns | Description |
|--------|---------|-------------|
| `Ability(name)` | `number` | Doability button number for this skill name |
| `Ability(n)` | `string` | Skill name assigned to doability button n |
| `AbilityReady(name\|n)` | `boolean` | Is this ability ready? |
| `AbilityTimer(name\|n)` | `timestamp` | Recast timer for ability |
| `AbilityTimerTotal(name\|n)` | `timestamp` | Total recast time for ability |
| `AltAbility(name\|n)` | `altability` | AA ability by name or index |
| `AltAbilityReady(name\|n)` | `boolean` | Is this AA ready? |
| `AltAbilityTimer(name\|n)` | `timestamp` | AA recast timer |
| `CombatAbility(name)` | `number` | Your combat ability list number for this name |
| `CombatAbility(n)` | `spell` | Combat ability at position n in your list |
| `CombatAbilityReady(name\|n)` | `boolean` | Is this combat ability ready? |
| `CombatAbilityTimer(name\|n)` | `ticks` | Ticks until combat ability is ready |
| `Aura(name\|n)` | `auratype` | Active aura by name or index |

#### Skills & Language

| Method | Returns | Description |
|--------|---------|-------------|
| `Skill(name\|id)` | `number` | Current skill level |
| `SkillCap(name\|id)` | `number` | Max skill cap for your class/level |
| `Language(name)` | `number` | Language number for this language name |
| `Language(n)` | `string` | Name of language n |
| `LanguageSkill(n\|name)` | `number` | Your skill in this language |

#### Extended Targets

| Method | Returns | Description |
|--------|---------|-------------|
| `XTarget()` | `number` | Number of current extended targets |
| `XTarget(n)` | `xtarget` | Extended target data for slot n |
| `XTAggroCount(n?)` | `number` | Number of auto-hater XTargets where your aggro < n% (default 100) |
| `XTargetSlots` | `number` | Total XTarget slots |

#### Bandolier

| Method | Returns | Description |
|--------|---------|-------------|
| `Bandolier(name)` | `bandolier` | Bandolier set by name |
| `Bandolier(n)` | `bandolier` | Bandolier set by index (1–20) |

#### Miscellaneous

| Field/Method | Type | Description |
|---|---|---|
| `LastZoned` | `timestamp` | Timestamp of last zone |
| `ZoneBound` | `zone` | Zone you are bound at |
| `ZoneBoundX/Y/Z()` | `number` | Bind point coordinates |
| `Origin` | `zone` | Character home city zone |
| `BoundLocation(n)` | `worldlocation` | Bind point n (0–4) |
| `GroupMarkNPC(n)` | `spawn` | Current group marked NPC (1–3) |
| `RaidAssistTarget(n)` | `spawn` | Current raid assist target (1–3) |
| `RaidMarkNPC(n)` | `spawn` | Current raid marked NPC (1–3) |
| `Hunger` | `number` | Hunger level |
| `Thirst` | `number` | Thirst level |
| `Drunk` | `number` | Drunkenness level |
| `Sit()` | — | Causes the character to sit |
| `Stand()` | — | Causes the character to stand |
| `StopCast()` | — | Stops current cast |

---

### `item`

Returned by `Me.Inventory()`, `FindItem()`, `Corpse.Item()`, `Cursor`, etc.

#### Identity

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Item name |
| `ID` | `number` | Item ID |
| `Icon` | `number` | Icon ID (use with `A_DragItem` animation) |
| `Type` | `string` | `"Armor"`, `"Weapon"`, `"Misc"`, `"Food"`, `"Drink"`, etc. |
| `Size` | `number` | 1=SMALL, 2=MEDIUM, 3=LARGE, 4=GIANT |
| `Weight` | `number` | Item weight |
| `ItemSlot` | `number` | Top-level slot (0–22 worn, 22+ bags) |
| `ItemSlot2` | `number` | Sub-slot within a bag (1–10) |
| `ItemLink(clickable?)` | `string` | EQ item link string; pass `"CLICKABLE"` for clickable version |

#### Flags

| Field | Type | Description |
|-------|------|-------------|
| `NoDrop` | `boolean` | No Trade? |
| `NoRent` | `boolean` | Temporary (drops on logout)? |
| `Lore` | `boolean` | Lore (unique — can only carry one)? |
| `Magic` | `boolean` | Magic item? |
| `Stackable` | `boolean` | Does it stack? |
| `Attuneable` | `boolean` | Attuneable? |
| `Tradeskills` | `boolean` | Tradeskill item? |

#### Stacking

| Field | Type | Description |
|-------|------|-------------|
| `Stack` | `number` | Items in this stack |
| `StackSize` | `number` | Maximum stack size |
| `StackCount` | `number` | Total of this item across all your stacks |
| `Stacks` | `number` | Number of stacks of this item in your inventory |
| `FreeStack` | `number` | Room remaining across all stacks before all are full |

#### Value & Trade

| Field | Type | Description |
|-------|------|-------------|
| `Value` | `number` | Vendor sell value in coppers |
| `BuyPrice` | `number` | Cost to buy from active merchant |
| `SellPrice` | `number` | What active merchant pays you |
| `MerchQuantity` | `number` | Quantity merchant has in stock |
| `Tribute` | `number` | Tribute value |

#### Stats (Bonuses the Item Provides)

| Field | Type | Description |
|-------|------|-------------|
| `AC` | `number` | Armor class |
| `HP` | `number` | HP bonus |
| `Mana` | `number` | Mana bonus |
| `Endurance` | `number` | Endurance bonus |
| `HPRegen` | `number` | HP regen bonus |
| `ManaRegen` | `number` | Mana regen bonus |
| `EnduranceRegen` | `number` | Endurance regen bonus |
| `STR/STA/AGI/DEX/INT/WIS/CHA` | `number` | Stat bonuses |
| `HeroicSTR/STA/AGI/DEX/INT/WIS/CHA` | `number` | Heroic stat bonuses |
| `svFire/svCold/svMagic/svPoison/svDisease/svCorruption` | `number` | Resist bonuses |
| `HeroicSvFire/svCold` / etc. | `number` | Heroic resist bonuses |
| `Attack` | `number` | Attack bonus |
| `Accuracy` | `number` | Accuracy bonus |
| `Avoidance` | `number` | Avoidance bonus |
| `Shielding` | `number` | Shielding bonus |
| `SpellShield` | `number` | Spell shield bonus |
| `DoTShielding` | `number` | DoT shielding bonus |
| `StrikeThrough` | `number` | Strikethrough bonus |
| `StunResist` | `number` | Stun resist bonus |
| `DamShield` | `number` | Damage shield value |
| `DamageShieldMitigation` | `number` | Damage shield mitigation |
| `CombatEffects` | `number` | Combat effects bonus |
| `SpellDamage` | `number` | Spell damage bonus |
| `HealAmount` | `number` | Heal amount bonus |
| `Clairvoyance` | `number` | Clairvoyance bonus |
| `Haste` | `number` | Haste % |
| `InstrumentMod` | `number` | Bard instrument modifier |
| `Purity` | `number` | Purity |

#### Weapon Stats

| Field | Type | Description |
|-------|------|-------------|
| `Damage` | `number` | Base weapon damage |
| `ItemDelay` | `number` | Weapon delay |
| `Range` | `number` | Item range |
| `DMGBonusType` | `string` | `"None"`, `"Magic"`, `"Fire"`, `"Cold"`, `"Poison"`, `"Disease"` |

#### Spell Effects

| Field | Type | Description |
|-------|------|-------------|
| `Spell` | `spell` | The spell on this item |
| `EffectType` | `string` | Effect type |
| `Clicky` | `itemspell` | Activatable (right-click) spell effect |
| `Worn` | `itemspell` | Passive worn effect |
| `Focus` | `itemspell` | First focus effect |
| `Focus2` | `itemspell` | Second focus effect |
| `Charges` | `number` | Charges remaining (−1 = unlimited) |
| `TimerReady` | `number` | Seconds until click ready (0 = ready) |
| `Timer` | `ticks` | Ticks remaining on recast timer |
| `CastTime` | `number` | Spell effect cast time in seconds |

#### Containers

| Field/Method | Type | Description |
|---|---|---|
| `Container` | `number` | Number of slots if this is a bag; 0 otherwise |
| `Items` | `number` | Current number of items inside (if a bag) |
| `Item(n)` | `item` | Item in bag slot n |
| `SizeCapacity` | `number` | Max item size this bag holds (1–4) |

#### Augments

| Field/Method | Type | Description |
|---|---|---|
| `AugType` | `number` | Augment type (0 if not an aug) |
| `AugRestrictions` | `number` | Augment restriction flags |
| `Augs` | `number` | Number of augments in this item |
| `AugSlot(n)` | `augtype` | Augment in slot n |
| `AugSlot1–6` | `number` | Augment type for each slot |

#### Requirements

| Field/Method | Type | Description |
|---|---|---|
| `RequiredLevel` | `number` | Required level (0 = none) |
| `Class(n\|name)` | `string` | Nth class that can use this item |
| `Classes` | `number` | Number of classes that can use it |
| `Race(n\|name)` | `string` | Nth race that can use this item |
| `Races` | `number` | Number of races that can use it |
| `Deity` | `string` | Deity restriction |
| `Deities` | `number` | Number of deity restrictions |
| `WornSlot(name)` | `boolean` | Can item be worn in slot with this name? |
| `WornSlot(n)` | `invslot` | The nth invslot this item can be worn in |
| `WornSlots` | `number` | Number of invslots this item can be worn in |
| `LDoNTheme` | `string` | LDoN theme name |

#### Power Source

| Field | Type | Description |
|-------|------|-------------|
| `Power` | `number` | Power remaining on a power source |
| `MaxPower` | `number` | Maximum power |

#### Evolving Items

| Field | Type | Description |
|-------|------|-------------|
| `Evolving` | `evolving` | Evolving item data (if applicable) |

#### Methods

| Method | Description |
|--------|-------------|
| `Inspect()` | Opens the in-game item display window |

---

### `spell`

Returned by `mq.TLO.Spell()`, `Me.Gem()`, `Me.Book()`, etc.

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Spell name |
| `BaseName` | `string` | Base name without rank |
| `ID` | `number` | Spell ID |
| `Level` | `number` | Spell level |
| `Mana` | `number` | Mana cost (unadjusted) |
| `EnduranceCost` | `number` | Endurance cost (unadjusted) |
| `CastTime` | `timestamp` | Cast time (unadjusted) |
| `MyCastTime` | `timestamp` | Adjusted cast time (with focus effects) |
| `Duration` | `ticks` | Spell duration |
| `MyDuration` | `ticks` | Adjusted spell duration |
| `RecastTime` | `number` | Recast time in seconds after successful cast |
| `FizzleTime` | `timestamp` | Recovery time after fizzle |
| `RecoveryTime` | `timestamp` | Alias for FizzleTime |
| `Range` | `number` | Max range to target |
| `AERange` | `number` | AE range (also used for group spell range) |
| `MyRange` | `number` | Adjusted range (with focus effects) |
| `PushBack` | `number` | Push back amount |
| `ResistType` | `string` | Resist type |
| `ResistAdj` | `number` | Resist adjustment |
| `SpellType` | `string` | `"Beneficial(Group)"`, `"Beneficial"`, `"Detrimental"`, `"Unknown"` |
| `TargetType` | `string` | Target type string |
| `Skill` | `string` | Casting skill |
| `Beneficial` | `boolean` | Is this a beneficial spell? |
| `IsSkill` | `boolean` | Is this a skill? |
| `IsSwarmSpell` | `boolean` | Is this a swarm (pet) spell? |
| `NumEffects` | `number` | Number of spell effects |
| `Rank` | `number` | Spell rank (1–3 for spells, 4–30 for items) |
| `RankName` | `spell` | Returns the ranked spell/ability name |
| `Category` | `string` | Spell category name |
| `CategoryID` | `number` | Spell category ID |
| `Subcategory` | `string` | Spell subcategory name |
| `SubcategoryID` | `number` | Spell subcategory ID |
| `CounterType` | `string` | `"Disease"`, `"Poison"`, `"Curse"`, `"Corruption"` |
| `CounterNumber` | `number` | Number of counters added |
| `HastePct` | `number` | Haste % (for haste spells) |
| `SlowPct` | `number` | Slow % (for slow spells) |
| `DurationWindow` | `number` | 0=long buff window, 1=short buff window |
| `GemIcon` | `number` | Gem icon number |
| `SpellIcon` | `number` | Spell icon number |
| `Description` | `string` | Spell description |
| `Extra` | `string` | Extra spell info |
| `CastOnYou` | `string` | Message when cast on yourself |
| `CastOnAnother` | `string` | Message when cast on others |
| `WearOff` | `string` | Wear-off message |
| `Link` | `string` | Spell link string |
| `Location` | `number` | Appears to be max distance |
| `Stacks` | `boolean` | Does this stack with your current buffs? |
| `StacksPet` | `boolean` | Does this stack with your pet's buffs? |
| `StacksTarget` | `boolean` | Does this stack with your target's buffs? |
| `StacksWithDiscs` | `boolean` | Will this stack with active disciplines? |
| `NewStacks` | `boolean` | Stacks check (alternate logic) |
| `WillLand` | `number` | Buff slot it will land in on yourself (0 if it won't) |

| Method | Params | Returns | Description |
|--------|--------|---------|-------------|
| `WillStack(name)` | `string` | `boolean` | Does this spell stack with a named spell? |
| `StacksSpawn(id)` | `integer\|string` | `boolean` | Does this stack with a spawn's buffs? |
| `Attrib(n)` | `integer` | `number` | Spell attribute value at index n |
| `Base(n)` | `integer` | `number` | Base value at effect index n |
| `Base2(n)` | `integer` | `number` | Base2 value at effect index n |
| `Max(n)` | `integer` | `number` | Max value at effect index n |
| `Trigger(n)` | `integer` | `spell` | Triggered spell at index n |
| `ReagentID(n)` | `integer` | `number` | Reagent item ID at index n (1–4) |
| `ReagentCount(n)` | `integer` | `number` | Reagent count at index n |
| `NoExpendReagentID(n)` | `integer` | `number` | Non-expended reagent ID at index n |
| `HasSPA(spaId)` | `integer` | `boolean` | Does the spell contain this Spell Attribute? |
| `Inspect()` | — | — | Opens the in-game spell inspect window |

---

### `buff` (extends spell)

Inherits all `spell` fields. Accessed via `Me.Buff()`, `Me.Song()`, `spawn.Buff()`.

| Field | Type | Description |
|-------|------|-------------|
| `ID` | `number` | Buff slot ID |
| `Duration` | `timestamp` | Time remaining before buff fades |
| `Level` | `number` | Level of the caster who cast this buff |
| `Caster` | `string` | Name of the caster |
| `Spell` | `spell` | The spell object for this buff |
| `Counters` | `number` | Total counters on this buff |
| `CountersPoison` | `number` | Poison counters |
| `CountersDisease` | `number` | Disease counters |
| `CountersCurse` | `number` | Curse counters |
| `CountersCorruption` | `number` | Corruption counters |
| `TotalCounters` | `number` | Total all counters |
| `Dar` | `number` | Remaining damage absorption on this buff |
| `HitCount` | `number` | Remaining hit count |
| `Mod` | `number` | Modifier (for bard songs) |
| `Remove()` | — | Removes this buff |

---

### `altability`

Accessed via `Me.AltAbility()` or `mq.TLO.AltAbility()`.

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Ability name |
| `ShortName` | `string` | Short name |
| `ID` | `number` | Ability ID |
| `Index` | `number` | Index in AA list |
| `NextIndex` | `number` | Next AA index |
| `Type` | `number` | Type (1–6) |
| `MaxRank` | `number` | Maximum trainable rank |
| `Rank` | `number` | Your current rank |
| `AARankRequired` | `number` | AA rank required to train |
| `Cost` | `number` | Base cost to train |
| `PointsSpent` | `number` | Points you've spent on this AA |
| `MinLevel` | `number` | Minimum level to train |
| `Passive` | `boolean` | Is this a passive AA? |
| `CanTrain` | `boolean` | Can you currently train this? |
| `RequiresAbility` | `altability` | Required prerequisite ability |
| `RequiresAbilityPoints` | `number` | Points required in prerequisite |
| `Spell` | `spell` | Spell this AA activates (if any) |
| `ReuseTime` | `number` | Reuse time in seconds |
| `MyReuseTime` | `number` | Adjusted reuse time (with hastened AAs) |
| `Description` | `string` | Description text |

---

### `group`

Accessed via `mq.TLO.Group`.

| Field/Method | Type | Description |
|---|---|---|
| `Members` | `number` | Total group members, **not** including yourself |
| `GroupSize` | `number` | Total group members, **including** yourself |
| `Leader` | `groupmember` | Group leader |
| `MainAssist` | `groupmember` | Main assist |
| `MainTank` | `groupmember` | Main tank |
| `Puller` | `groupmember` | Puller |
| `MarkNpc` | `groupmember` | Mark NPC member |
| `MasterLooter` | `groupmember` | Master looter |
| `AnyoneMissing` | `boolean` | Is anyone offline, dead, or in another zone? |
| `Offline` | `boolean` | Is anyone offline? |
| `OtherZone` | `boolean` | Is anyone online but in another zone? |
| `Present` | `number` | Members present in your zone (not including you) |
| `Cleric` | `string` | Name of cleric in group (if one exists) |
| `MouseOver` | `string` | Name of group member mouse is hovering |
| `MercenaryCount` | `number` | Number of mercenaries in group |
| `TankMercCount` | `number` | Tank mercenary count |
| `HealerMercCount` | `number` | Healer mercenary count |
| `MeleeMercCount` | `number` | Melee DPS mercenary count |
| `CasterMercCount` | `number` | Caster DPS mercenary count |
| `Injured(n)` | `number` | Members with HP% below n |
| `LowMana(n)` | `number` | Members with mana% below n |
| `Member(n)` | `groupmember` | Member at index n (0=you, 1=first group member) |
| `Member(name)` | `number` | Group index of the member with this name |

---

### `groupmember` (extends spawn)

Has all `spawn` fields plus:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Member name |
| `Level` | `number` | Level |
| `Class` | `class` | Class |
| `Offline` | `boolean` | Is offline? |
| `OtherZone` | `boolean` | In a different zone? |
| `Present` | `boolean` | Present in current zone? |
| `Mercenary` | `boolean` | Is a mercenary? |
| `Leader` | `boolean` | Is the group leader? |
| `MainAssist` | `boolean` | Is main assist? |
| `MainTank` | `boolean` | Is main tank? |
| `Puller` | `boolean` | Is the puller? |

---

### `raid`

Accessed via `mq.TLO.Raid`.

| Field/Method | Type | Description |
|---|---|---|
| `Members` | `number` | Total raid members |
| `AverageLevel` | `number` | Average level of raid members |
| `TotalLevels` | `number` | Sum of all member levels |
| `Locked` | `boolean` | Is the raid locked? |
| `Invited` | `boolean` | Have you been invited to the raid? |
| `Leader` | `raidmember` | Raid leader |
| `MasterLooter` | `raidmember` | Master looter |
| `Target` | `raidmember` | Raid window target (who you clicked) |
| `LootType` | `number` | 1=Leader, 2=Leader+GroupLeader, 3=Leader+Specified |
| `Looter` | `number` | Number of specified looters |
| `Member(name)` | `raidmember` | Member by name |
| `Member(n)` | `raidmember` | Member by index |
| `Looter(name)` | `string` | Specified looter by name |
| `Looter(n)` | `string` | Specified looter by index |
| `MainAssist(n)` | `raidmember` | Raid main assist at index n |

---

### `raidmember` (extends spawn)

Has all `spawn` fields plus:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Member name |
| `Level` | `number` | Level |
| `Class` | `class` | Class |
| `Group` | `number` | Group number within the raid |
| `GroupLeader` | `boolean` | Is a group leader within the raid? |
| `RaidLeader` | `boolean` | Is the raid leader? |
| `Looter` | `boolean` | Is a specified looter? |

---

### `pet` (extends spawn)

Accessed via `mq.TLO.Pet` or `spawn.Pet`.

| Field/Method | Type | Description |
|---|---|---|
| `Combat` | `boolean` | Is the pet in combat? |
| `Hold` | `boolean` | Hold stance active? |
| `GHold` | `boolean` | GHold stance active? |
| `Stop` | `boolean` | Stop stance active? |
| `Taunt` | `boolean` | Taunt stance active? |
| `ReGroup` | `boolean` | ReGroup stance active? |
| `Focus` | `boolean` | Focus stance active? |
| `Stance` | `string` | Current pet stance string (e.g. `"FOLLOW"`, `"GUARD"`) |
| `Target` | `spawn` | Pet's current target |
| `ID` | `number` | Pet spawn ID |
| `Buff(name)` | `number` | Buff slot for the named buff |
| `Buff(n)` | `string` | Buff name in slot n |
| `BuffDuration(name)` | `number` | Buff time remaining in ms (by name) |
| `BuffDuration(n)` | `number` | Buff time remaining in ms (by slot) |

---

### `corpse` (extends spawn)

Only valid when a loot window is open. Accessed via `mq.TLO.Corpse`.

| Field/Method | Type | Description |
|---|---|---|
| `Items` | `number` | Number of items on the corpse |
| `Open` | `boolean` | Is the corpse loot window open? |
| `Item(n)` | `item` | Item at index n |
| `Item(name)` | `item` | Item by partial name (prefix `=` for exact) |

---

### `ground`

A ground item (dropped loot, tradeskill objects on the ground). Accessed via `mq.TLO.Ground` or from `getAllGroundItems()`.

| Field/Method | Type | Description |
|---|---|---|
| `ID` | `number` | Ground item spawn ID |
| `Name` | `string` | Internal name |
| `DisplayName` | `string` | Display name |
| `Distance` | `number` | Distance from player (2D) |
| `Distance3D` | `number` | Distance from player (3D) |
| `X` | `number` | X coordinate |
| `Y` | `number` | Y coordinate |
| `Z` | `number` | Z coordinate |
| `W` | `number` | Westward-positive X |
| `N` | `number` | Northward-positive Y |
| `U` | `number` | Upward-positive Z |
| `Heading` | `heading` | Ground item facing direction |
| `HeadingTo` | `heading` | Direction player must move to reach it |
| `LineOfSight` | `boolean` | Is it in line of sight? |
| `SubID` | `number` | Sub-ID |
| `ZoneID` | `number` | Zone ID |
| `First` | `ground` | First ground item in list |
| `Last` | `ground` | Last ground item in list |
| `Next` | `ground` | Next in list |
| `Prev` | `ground` | Previous in list |
| `DoFace()` | — | Face toward this item |
| `DoTarget()` | — | Target this item |
| `Grab()` | — | Pick up this item |

---

### `currentzone` / `zone`

`currentzone` is returned by `mq.TLO.Zone` (no argument). `zone` is returned by `mq.TLO.Zone(id|name)`.

**`currentzone` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Full zone name (e.g. `"East Commonlands"`) |
| `ShortName` | `string` | Short name (e.g. `"ecommons"`) |
| `ID` | `number` | Zone ID |
| `Type` | `number` | 0=Indoor Dungeon, 1=Outdoor, 2=Outdoor City, 3=Dungeon City, 4=Indoor City, 5=Outdoor Dungeon |
| `Indoor` | `boolean` | Is indoors? |
| `Outdoor` | `boolean` | Is outdoors? |
| `Dungeon` | `boolean` | Is a dungeon? |
| `NoBind` | `boolean` | Binding not allowed? |
| `SkyType` | `number` | Sky type ID |
| `Gravity` | `number` | Zone gravity |
| `MaxClip` | `number` | Maximum clip plane |
| `MinClip` | `number` | Minimum clip plane |
| `FogOnOff` | `number` | Fog state |

**`zone` fields** (any zone, not just current):

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Full zone name |
| `ShortName` | `string` | Short name |
| `ID` | `number` | Zone ID |

---

### `window`

Accessed via `mq.TLO.Window("WindowName")`.

#### Properties

| Field | Type | Description |
|-------|------|-------------|
| `Open` | `boolean` | Is the window open/visible? |
| `Minimized` | `boolean` | Is it minimized? |
| `Enabled` | `boolean` | Is it enabled? |
| `Highlighted` | `boolean` | Is it the focused window? |
| `MouseOver` | `boolean` | Is the mouse over this window? |
| `Name` | `string` | Window piece name (Custom UI dependent) |
| `ScreenID` | `string` | Screen ID (not Custom UI dependent) |
| `Type` | `string` | Window type: `"Screen"`, `"Listbox"`, `"Gauge"`, `"SpellGem"`, `"InvSlot"`, `"Editbox"`, `"Slider"`, `"Label"`, `"STMLbox"`, `"TreeView"`, `"Combobox"`, `"Page"`, `"TabBox"`, `"LayoutBox"`, `"HorizontalLayoutBox"`, `"VerticalLayoutBox"`, `"FinderBox"`, `"TileLayoutBox"`, `"HotButton"` |
| `Text` | `string` | Window text content |
| `Tooltip` | `string` | Tooltip text |
| `Value` | `number` | Window value |
| `Checked` | `boolean` | Is a checkable button checked? |
| `X` | `number` | X position in pixels |
| `Y` | `number` | Y position in pixels |
| `Width` | `number` | Width in pixels |
| `Height` | `number` | Height in pixels |
| `Size` | `string` | `"width,height"` |
| `Style` | `number` | Style bitmask |
| `BGColor` | `argb` | Background color |
| `Children` | `boolean` | Has child windows? |
| `Siblings` | `boolean` | Has sibling windows? |
| `FirstChild` | `window` | First child in hierarchy |
| `Next` | `window` | Next sibling in hierarchy |
| `Parent` | `window` | Parent window |
| `HScrollPos` | `number` | Horizontal scroll position |
| `HScrollMax` | `number` | Horizontal scroll maximum |
| `HScrollPct` | `number` | Horizontal scroll % |
| `VScrollPos` | `number` | Vertical scroll position |
| `VScrollMax` | `number` | Vertical scroll maximum |
| `VScrollPct` | `number` | Vertical scroll % |
| `Items` | `number` | `[Listbox/Combobox/TreeView]` Number of items |
| `SelectedIndex` | `number` | `[Listbox/Combobox/TreeView]` Selected item index |
| `CurrentTab` | `window` | `[TabBox]` Current tab's Page window |
| `CurrentTabIndex` | `number` | `[TabBox]` Current tab index |
| `TabCount` | `number` | `[TabBox]` Number of tabs |
| `HisTradeReady` | `boolean` | Has the other trader clicked Trade? |
| `MyTradeReady` | `boolean` | Have you clicked Trade? |

#### Methods

| Method | Params | Description |
|--------|--------|-------------|
| `Child(name)` | `string` | Find a child window by name |
| `DoOpen()` | — | Open/show the window |
| `DoClose()` | — | Close/hide the window |
| `LeftMouseDown()` | — | Send left mouse down event |
| `LeftMouseUp()` | — | Send left mouse up event |
| `LeftMouseHeld()` | — | Send left mouse held event |
| `LeftMouseHeldUp()` | — | Send left mouse held up event |
| `RightMouseDown()` | — | Send right mouse down event |
| `RightMouseUp()` | — | Send right mouse up event |
| `RightMouseHeld()` | — | Send right mouse held event |
| `RightMouseHeldUp()` | — | Send right mouse held up event |
| `Move(x, y, w, h)` | `number×4` | Move and/or resize the window |
| `Select(n)` | `number` | `[Listbox/Combobox/TreeView]` Select item at index n |
| `SetAlpha(a)` | `number` | Set window alpha (0–255) |
| `SetFadeAlpha(a)` | `number` | Set faded alpha (0–255) |
| `SetBGColor(hex)` | `string` | Set background color (e.g. `"AARRGGBB"`) |
| `SetText(text)` | `string` | `[Editbox]` Set the text content |
| `SetCurrentTab(n\|text)` | `number\|string` | `[TabBox]` Change current tab |
| `Tab(n)` | `number` | `[TabBox]` Page window for tab at index n |
| `Tab(text)` | `string` | `[TabBox]` Page window for tab with this text |
| `List(row, col?)` | `number, number?` | `[Listbox/Combobox/TreeView]` Text at row/col |
| `List(text, col?)` | `string, number?` | `[Listbox/Combobox/TreeView]` Find item by text, return index |

---

### `fellowship`

Accessed via `Me.Fellowship`.

| Field/Method | Type | Description |
|---|---|---|
| `ID` | `number` | Fellowship ID |
| `Leader` | `string` | Fellowship leader's name |
| `Members` | `number` | Number of fellowship members |
| `MotD` | `string` | Message of the Day |
| `Campfire` | `boolean` | Is a campfire active? |
| `CampfireDuration` | `ticks` | Time left on campfire |
| `CampfireX/Y/Z` | `number` | Campfire coordinates |
| `CampfireZone` | `zone` | Zone containing the campfire |
| `Member(name)` | `fellowshipmember` | Member by name |
| `Member(n)` | `fellowshipmember` | Member by index |

---

### `fellowshipmember`

| Field | Type | Description |
|-------|------|-------------|
| `Name` | `string` | Member name |
| `Zone` | `zone` | Zone member is in |
| `Level` | `number` | Level |
| `Class` | `class` | Class |
| `Sharing` | `boolean` | Is this member sharing experience? |
| `LastOn` | `timestamp` | Last time this member was online |

---

### `mercenary` (extends spawn)

Accessed via `Me.Mercenary`. Has all `spawn` fields plus:

| Field | Type | Description |
|-------|------|-------------|
| `State` | `string` | `"DEAD"`, `"SUSPENDED"`, `"ACTIVE"`, `"UNKNOWN"` |
| `StateID` | `number` | Numeric state ID |
| `Stance` | `string` | Current stance |
| `AAPoints` | `number` | AA points spent on mercenary abilities |
| `Index` | `string` | Mercenary index |

---

### `dynamiczone`

Accessed via `mq.TLO.DynamicZone`.

| Field/Method | Type | Description |
|---|---|---|
| `Name` | `string` | Full name of the dynamic zone |
| `Members` | `number` | Current number of characters in the DZ |
| `MaxMembers` | `number` | Maximum allowed characters |
| `MinMembers` | `number` | Minimum required characters |
| `Leader()` | `dzmember` | DZ leader |
| `LeaderFlagged` | `boolean` | Can the DZ leader enter? (also indicates DZ is loaded) |
| `InRaid()` | `boolean` | Is the DZ associated with a raid? |
| `Member(id)` | `dzmember` | DZ member by ID |
| `Member(name)` | `dzmember` | DZ member by name |
| `Timer(id)` | `dztimer` | DZ timer by ID |
| `Timer(name)` | `dztimer` | DZ timer by name |

---

### `xtarget` (extends spawn)

Accessed via `Me.XTarget(n)`. Has all `spawn` fields plus:

| Field | Type | Description |
|-------|------|-------------|
| `ID` | `number` | Spawn ID |
| `Name` | `string` | Name |
| `PctAggro` | `number` | Aggro percentage on this XTarget |
| `TargetType` | `string` | Extended target type string |

---

### `task`

Accessed via `mq.TLO.Task`.

| Field | Type | Description |
|-------|------|-------------|
| `ID` | `number` | Task ID |
| `Title` | `string` | Task name |
| `Type` | `string` | `"Unknown"`, `"None"`, `"Deliver"`, `"Kill"`, `"Loot"`, `"Hail"`, `"Explore"`, `"Tradeskill"`, `"Fishing"`, `"Foraging"`, `"Cast"`, `"UseSkill"`, `"DZSwitch"`, `"DestroyObject"`, `"Collect"`, `"Dialogue"` |
| `Index` | `string` | Task's position on the task list |
| `Timer` | `ticks` | Ticks until task expires |
| `Members` | `number` | Number of members in the task |
| `Leader` | `string` | Task leader's name |
| `Member` | `taskmember` | Task member by name or index |
| `Step` | `taskobjective` | Current step/objective |
| `WindowIndex` | `number` | Quest Window list index |
| `Select` | `string` | Selects the task |
| `CurrentCount` | `number` | Current count toward objective completion |
| `RequiredCount` | `number` | Required count for completion |
| `Optional` | `boolean` | Is the objective optional? |
| `RequiredItem` | `string` | Required item for this objective |
| `RequiredSkill` | `string` | Required skill for this objective |
| `RequiredSpell` | `string` | Required spell for this objective |
| `DZSwitchID` | `number` | Switch ID used in this objective |

---

### `bandolier`

Accessed via `Me.Bandolier()`.

| Field/Method | Type | Description |
|---|---|---|
| `Name` | `string` | Bandolier set name |
| `Index` | `number` | Index (1–20) |
| `Active` | `boolean` | Is this the active bandolier set? |
| `Item(n)` | `bandolieritem` | Item at position n (1=Primary, 2=Secondary, 3=Ranged, 4=Ammo) |
| `Activate()` | — | Activates this bandolier profile |

---

### `heading`

Created via `mq.TLO.Heading()` or accessed from spawn fields.

| Field | Type | Description |
|-------|------|-------------|
| `Degrees` | `number` | Heading in degrees (clockwise; 0=North) |
| `Clock` | `number` | Heading as a clock position (3=East, 6=South, etc.) |
| `ShortName` | `string` | Short compass name: `"N"`, `"NE"`, `"E"`, etc. |
| `Name` | `string` | Long compass name: `"North"`, `"NorthEast"`, etc. |

---

### `achievementmgr`

Accessed via `mq.TLO.Achievement`.

| Field/Method | Type | Description |
|---|---|---|
| `Ready` | `boolean` | Achievement data is loaded and ready |
| `Points` | `number` | Total accumulated achievement points |
| `CompletedAchievements` | `number` | Number of completed achievements |
| `TotalAchievements` | `number` | Number of available achievements |
| `AchievementCount` | `number` | Total achievements in the manager |
| `CategoryCount` | `number` | Total categories in the manager |
| `Achievement(id)` | `achievement` | Achievement by ID |
| `Achievement(name)` | `achievement` | Achievement by name |
| `AchievementByIndex(n)` | `achievement` | Achievement by index |
| `Category(id)` | `achievementcat` | Category by ID |
| `Category(name)` | `achievementcat` | Category by name (top-level only) |
| `CategoryByIndex(n)` | `achievementcat` | Category by index |

---

### `merchant`

Accessed via `mq.TLO.Merchant`.

| Field/Method | Type | Description |
|---|---|---|
| `Open` | `boolean` | Is a merchant window open? |
| `Full` | `boolean` | Is the merchant's inventory full? |
| `Items` | `number` | Number of items the merchant has |
| `ItemsReceived` | `boolean` | Has the merchant item list loaded? |
| `Markup` | `number` | Price multiplier (charisma-adjusted) |
| `Item` | `item` | The selected item on the merchant's list |
| `SelectedItem` | `item` | Currently selected item in merchant window |
| `OpenWindow()` | — | Opens the nearest merchant (or targeted merchant) |
| `SelectItem(name)` | — | Selects a merchant item by name (prefix `=` for exact) |
| `Buy(n)` | — | Buys n of the currently selected item |
| `Sell(n)` | — | Sells n of the currently selected item |

---

## ImGui Module

```lua
local ImGui = require('ImGui')
```

Full ImGui reference is in **GETTING_STARTED.md** (Section 6 and Section 11). Quick-reference of what's available:

### Registration
```lua
ImGui.Register(name, callback)    -- register a draw callback (modern, preferred)
ImGui.Unregister(name)            -- unregister
```

### Window Functions
```lua
ImGui.Begin(title [, open [, flags]])     → isOpen, shouldDraw
ImGui.End()
ImGui.BeginChild(id, size [, flags])      → boolean
ImGui.EndChild()
ImGui.SetNextWindowPos(ImVec2)
ImGui.SetNextWindowSize(ImVec2)
ImGui.SetNextWindowBgAlpha(alpha)
ImGui.GetWindowPos()                      → ImVec2
ImGui.GetWindowSize()                     → ImVec2
ImGui.GetDisplaySize()                    → ImVec2
ImGui.GetCursorScreenPos()               → ImVec2
```

### Widgets (all return state/value)
```lua
ImGui.Text(fmt, ...)
ImGui.TextColored(ImVec4, fmt, ...)
ImGui.TextWrapped(fmt, ...)
ImGui.TextDisabled(fmt, ...)
ImGui.LabelText(label, text)
ImGui.BulletText(fmt, ...)
ImGui.SeparatorText(text)

ImGui.Button(label [, size])              → clicked: boolean
ImGui.Checkbox(label, value)              → newValue, changed
ImGui.RadioButton(label, active)          → clicked: boolean
ImGui.ProgressBar(fraction [, size [, overlay]])

ImGui.InputText(label, text)              → text, changed
ImGui.InputInt(label, value)              → value, changed
ImGui.InputFloat(label, value)            → value, changed
ImGui.SliderInt(label, value, min, max)   → value, changed
ImGui.SliderFloat(label, value, min, max) → value, changed
ImGui.Combo(label, current, items, count) → current, changed
ImGui.Selectable(label, selected)         → clicked: boolean
```

### Layout
```lua
ImGui.Separator()
ImGui.SameLine([offset])
ImGui.Spacing()
ImGui.NewLine()
ImGui.Indent() / ImGui.Unindent()
ImGui.Dummy(ImVec2)
ImGui.BeginGroup() / ImGui.EndGroup()
ImGui.PushID(id) / ImGui.PopID()
```

### Tables
```lua
ImGui.BeginTable(id, cols [, flags [, size]])  → boolean
ImGui.EndTable()
ImGui.TableSetupColumn(label [, flags [, width]])
ImGui.TableSetupScrollFreeze(cols, rows)
ImGui.TableHeadersRow()
ImGui.TableNextRow()
ImGui.TableSetColumnIndex(n)
```

### Trees, Tabs, Popups
```lua
ImGui.CollapsingHeader(label)         → expanded: boolean
ImGui.TreeNode(label)                 → expanded: boolean
ImGui.TreePop()

ImGui.BeginTabBar(id)                 → boolean
ImGui.EndTabBar()
ImGui.BeginTabItem(label)             → selected: boolean
ImGui.EndTabItem()

ImGui.OpenPopup(id)
ImGui.BeginPopup(id)                  → boolean
ImGui.BeginPopupModal(id)             → boolean
ImGui.EndPopup()
ImGui.CloseCurrentPopup()
```

### Styling
```lua
ImGui.PushStyleColor(ImGuiCol.X, ImVec4)
ImGui.PopStyleColor([count])
ImGui.PushStyleVar(ImGuiStyleVar.X, value)
ImGui.PopStyleVar([count])
```

### Tooltips
```lua
ImGui.SetTooltip(text)
ImGui.BeginTooltip()
ImGui.EndTooltip()
ImGui.IsItemHovered()   → boolean
ImGui.IsItemClicked()   → boolean
ImGui.IsItemActive()    → boolean
ImGui.IsItemVisible()   → boolean
ImGui.GetItemRectSize() → ImVec2
```

### Menu Bar
```lua
ImGui.BeginMenuBar() / ImGui.EndMenuBar()
ImGui.BeginMenu(label)        → boolean
ImGui.EndMenu()
ImGui.MenuItem(label)         → boolean
```

### Draw Lists
```lua
ImGui.GetForegroundDrawList()   → ImDrawList
ImGui.GetBackgroundDrawList()   → ImDrawList
ImGui.GetWindowDrawList()       → ImDrawList

-- ImDrawList methods (colon syntax):
dl:AddLine(p1, p2, color [, thickness])
dl:AddRect(min, max, color [, rounding [, flags [, thickness]]])
dl:AddRectFilled(min, max, color [, rounding])
dl:AddRectFilledMultiColor(min, max, colTL, colTR, colBR, colBL)
dl:AddCircle(center, radius, color [, segs [, thickness]])
dl:AddCircleFilled(center, radius, color [, segs])
dl:AddTriangle(p1, p2, p3, color [, thickness])
dl:AddTriangleFilled(p1, p2, p3, color)
dl:AddQuad(p1, p2, p3, p4, color [, thickness])
dl:AddQuadFilled(p1, p2, p3, p4, color)
dl:AddNgon(center, radius, color, segs [, thickness])
dl:AddNgonFilled(center, radius, color, segs)
dl:AddText(pos, color, text)
dl:AddText(font, size, pos, color, text)
dl:AddBezierCubic(p1, p2, p3, p4, color, thickness [, segs])
dl:AddBezierQuadratic(p1, p2, p3, color, thickness [, segs])
dl:AddPolyline(points, color, flags, thickness)
dl:AddConvexPolyFilled(points, color)
dl:AddConcavePolyFilled(points, color)
dl:AddTextureAnimation(anim, pos [, size])  -- MQ extension
dl:PushClipRect(min, max [, intersect])
dl:PushClipRectFullScreen()
dl:PopClipRect()
dl:GetClipRectMin()  → ImVec2
dl:GetClipRectMax()  → ImVec2
dl:PathClear()
dl:PathLineTo(pos)
dl:PathArcTo(center, radius, a_min, a_max [, segs])
dl:PathArcToFast(center, radius, a_min12, a_max12)
dl:PathBezierCubicCurveTo(p2, p3, p4 [, segs])
dl:PathRect(min, max [, rounding])
dl:PathStroke(color [, flags [, thickness]])
dl:PathFillConvex(color)
dl:ChannelsSplit(count)
dl:ChannelsSetCurrent(n)
dl:ChannelsMerge()
```

### Textures in ImGui
```lua
ImGui.Image(textureId, size [, uv0 [, uv1]])
ImGui.DrawTextureAnimation(anim, width, height)
ImGui.ColorConvertFloat4ToU32(ImVec4)   → ImU32
ImGui.GetEQImFont(style)                → ImFont
```

### Value Types
```lua
ImVec2(x, y)              -- 2D vector (position, size)
ImVec4(r, g, b, a)        -- 4D vector (color; each channel 0.0–1.0)
-- ImU32 colors for draw lists: 0xAABBGGRR format
```

### Not Bound (C++ exists but unavailable in Lua)
- `AddEllipse` / `AddEllipseFilled`
- `PathFillConcave`
- `PathEllipticalArcTo`
- Vertex-level primitives (`PrimReserve`, `PrimWriteVtx`, etc.)
