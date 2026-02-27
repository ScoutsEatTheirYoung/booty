# MacroQuest Lua API Reference

A practical reference for writing MQ Lua scripts. This document covers the base MacroQuest API — no plugins or addons required beyond what ships with MQ itself.

> **Verified against C++ source** (`lua_MQBindings.cpp`, `lua_EQBindings.cpp`, `lua_Globals.cpp`, `lua_ImGuiCore.cpp`, `lua_ImGuiWidgets.cpp`, `lua_ImGuiCustom.cpp`, `MQ2ItemType.cpp`, `MQ2CharacterType.cpp`) as of 2026-02-26.

---

## Table of Contents

1. [How MQ Lua Scripts Work](#1-how-mq-lua-scripts-work)
2. [The `mq` Module — Full Reference](#2-the-mq-module--full-reference)
3. [Top Level Objects (TLOs)](#3-top-level-objects-tlos)
4. [The `item` Data Type](#4-the-item-data-type)
5. [Worn Slot Names & Numbers](#5-worn-slot-names--numbers)
6. [ImGui Reference](#6-imgui-reference)
7. [Common Patterns & Recipes](#7-common-patterns--recipes)
8. [MQ Chat Color Codes](#8-mq-chat-color-codes)
9. [ImGui ID Tips (the ## trick)](#9-imgui-id-tips-the--trick)
10. [Useful `bit32` Operations](#10-useful-bit32-operations)
11. [Draw Lists (ImDrawList)](#11-draw-lists-imdrawlist)

---

## 1. How MQ Lua Scripts Work

### Script Location

Lua scripts live in the `MQ2/lua/` directory. Each script is a `.lua` file. You can organize them in subfolders.

```
MQ2/lua/
    myscript.lua
    myfolder/
        myscript.lua
```

### Running and Stopping Scripts

From the EQ chat box:

```
/lua run myscript              -- runs MQ2/lua/myscript.lua
/lua run myfolder/myscript     -- runs MQ2/lua/myfolder/myscript.lua
/lua stop myscript             -- stops a running script by name
/lua list                      -- lists all running scripts
```

### The Two Main Requires

Almost every MQ script starts with these two lines:

```lua
local mq    = require('mq')      -- core MQ functions and TLOs
local ImGui = require('ImGui')   -- Dear ImGui UI library (optional, only if you need a window)
```

You only need `ImGui` if your script draws a UI window. Pure automation scripts only need `mq`.

### The Main Loop

Most scripts run a continuous loop that keeps the script alive and does periodic work. The `mq.delay()` call is what gives MQ time to process game events — without it, you'll lock up the game client.

```lua
local running = true

while running do
    -- do work here
    mq.delay(100)   -- yield for 100ms; NEVER omit this in a loop
end
```

### ImGui Callbacks

If you register an ImGui callback, it fires every rendered frame — roughly 60 times per second. Keep draw callbacks fast. Never call `mq.delay()` inside a draw callback. Use Lua variables to pass data between the draw callback and your main loop.

```lua
local myData = 'nothing yet'

local function draw()
    ImGui.Text(myData)   -- reads the Lua variable; fast, no blocking
end

ImGui.Register('MyWindow', draw)

while running do
    myData = 'updated: ' .. tostring(mq.gettime())  -- update in main loop
    mq.delay(500)
end
```

### Script Lifecycle Summary

```
/lua run myscript
    -> Lua environment initialized
    -> require('mq') and require('ImGui') load
    -> ImGui callbacks registered
    -> main loop runs
    -> mq.delay() yields to MQ on each iteration
    -> /lua stop OR mq.exit() terminates the script
```

---

## 2. The `mq` Module — Full Reference

### Core Functions

#### `mq.cmd(command)`

Sends any slash command to EverQuest, just as if you typed it in chat. This is the primary way to make your character do things.

```lua
mq.cmd('/say Hello everyone!')
mq.cmd('/cast 3')            -- cast spell gem 3
mq.cmd('/sit')
mq.cmd('/stand')
mq.cmd('/target name Fippy') -- target by name
```

#### `mq.cmdf(format, ...)`

Like `mq.cmd()` but with C-style `string.format` support. Use this when you need to build commands with variable data.

```lua
local targetId = 12345
mq.cmdf('/target id %d', targetId)
mq.cmdf('/say My HP is %d%%', mq.TLO.Me.PctHPs())
mq.cmdf('/tell %s I will be there soon', playerName)
```

#### `mq.delay(ms [, condition])`

Pauses the script. This is essential — it yields execution back to MQ so the game can process frames, events, and input. Never run a tight loop without a delay.

```lua
mq.delay(100)        -- pause 100 milliseconds
mq.delay(1000)       -- pause 1 second
mq.delay('2s')       -- string format: 's'=seconds, 'm'=minutes, 'ms'=milliseconds
mq.delay('500ms')
mq.delay('1m')

-- With a condition: waits UP TO 5 seconds, but stops early if condition returns true.
-- This is the right way to wait for something to happen without a fixed sleep.
mq.delay(5000, function()
    return mq.TLO.Me.Casting() == nil   -- stop waiting once casting finishes
end)
```

The condition function is polled repeatedly during the delay. As soon as it returns `true`, the delay ends early. If the timeout is reached first, execution continues regardless.

#### `mq.exit()`

Immediately terminates the currently running script. Useful for fatal error conditions or when the user closes your UI window.

```lua
if not mq.TLO.Me.Name() then
    print('Not in game, exiting.')
    mq.exit()
end
```

#### `mq.gettime()`

Returns the current time in milliseconds as a number. Useful for measuring elapsed time or timestamping events.

```lua
local start = mq.gettime()
-- do some work
local elapsed = mq.gettime() - start
print(string.format('Took %d ms', elapsed))
```

#### `printf(format, ...)`

A global convenience function equivalent to `print(string.format(...))`. Outputs a formatted string to the EQ chat window. Available as a global (no `mq.` prefix needed).

```lua
printf('My HP: %d / %d', mq.TLO.Me.CurrentHPs(), mq.TLO.Me.MaxHPs())
printf('Zone: %s  Level: %d', mq.TLO.Zone.ShortName(), mq.TLO.Me.Level())
```

---

#### `mq.parse(expression)`

Evaluates a MacroQuest macro expression string (the `${}` syntax from the old MQ2 macro language) and returns the result as a string. Useful for accessing TLO data that isn't wrapped in the Lua API yet.

```lua
local name = mq.parse('${Me.Name}')
local zone  = mq.parse('${Zone.Name}')
local hp    = mq.parse('${Me.PctHPs}')
```

#### `mq.join(delim, ...)`

Joins its arguments into a single string, inserting `delim` between each non-empty value. The **first argument is the delimiter**, followed by the values to join.

```lua
local msg = mq.join(' ', 'Hello', 'world')   -- "Hello world"
local csv = mq.join(', ', 'a', 'b', 'c')     -- "a, b, c"
local noSep = mq.join('', 'foo', 'bar')      -- "foobar"
```

Note: empty string arguments are skipped entirely (not joined with the delimiter).

---

### Binding Slash Commands

You can register your own `/commands` that players can type in chat. This is how you expose controls to your script from within EQ.

```lua
-- Register a command. Arguments after the command name are passed as separate strings.
mq.bind('/mycommand', function(arg1, arg2)
    print('arg1: ' .. (arg1 or 'none'))
    print('arg2: ' .. (arg2 or 'none'))
end)

-- In-game: /mycommand hello world
-- -> arg1: hello
-- -> arg2: world

-- Remove the binding when you no longer need it (e.g., on script shutdown):
mq.unbind('/mycommand')
```

---

### Events (Watching Chat for Patterns)

Events let you react to text that appears in the EQ chat window. The pattern syntax is similar to MQ2 macro events: `#*#` matches any text, `#1#` captures the first wildcard into the callback's first argument, etc.

The full signature is: `mq.event(name, matcherText, callback [, options])`
- `name` — unique string identifier for this event
- `matcherText` — pattern string; `#*#` = wildcard (ignored), `#1#`/`#2#`/... = numbered captures
- `callback(line, cap1, cap2, ...)` — called on match; first arg is the full chat line, rest are captures
- `options` — optional table (rarely needed; used for advanced event filtering)

```lua
-- Simple event: fires when this exact text appears in chat
mq.event('OnDeath', 'You have been slain by #*#', function()
    print('I died!')
end)

-- With capture: #1# captures the matched text as the first argument
mq.event('OnTell', '#*#tells you, \'#1#\'', function(line, message)
    -- line    = the full chat line
    -- message = the captured text (what #1# matched)
    print('Received tell: ' .. message)
end)

-- Remove an event listener:
mq.unevent('OnDeath')

-- IMPORTANT: You must call mq.doevents() in your main loop.
-- Without this, registered events will never fire.
while running do
    mq.doevents()    -- process any queued events
    mq.delay(100)
end

-- Discard all queued events without processing them:
-- mq.flushevents() with no args flushes all queued events.
-- You can also pass specific event names to flush only those:
mq.flushevents()                    -- flush everything
mq.flushevents('OnDeath')           -- flush only this event's queue
mq.flushevents('OnTell', 'OnDeath') -- flush multiple events
```

---

### Spawn Utility Functions

These helpers let you fetch lists of spawns or ground items directly into Lua tables, which is useful for searching, filtering, and displaying information about the world around you.

```lua
-- Get every spawn in the zone as a table of spawn TLOs:
local allSpawns = mq.getAllSpawns()

-- Get filtered spawns using a predicate function:
local npcs = mq.getFilteredSpawns(function(spawn)
    return spawn.Type() == 'NPC'
end)

-- Get all ground items (dropped loot, tradeskill items on the ground, etc.):
local allGround = mq.getAllGroundItems()

-- Get ground items that match a filter:
local nearby = mq.getFilteredGroundItems(function(item)
    return item.Distance() < 50   -- within 50 units
end)

-- Example: print names of all nearby NPCs
local nearbyNPCs = mq.getFilteredSpawns(function(s)
    return s.Type() == 'NPC' and s.Distance() < 100
end)
for _, npc in ipairs(nearbyNPCs) do
    print(npc.Name(), npc.Distance())
end
```

---

### Textures & Icons

MQ can load DDS texture files and EQ UI texture animations for display in ImGui windows. The most common use case is rendering EQ item icons.

```lua
-- Load a texture file from disk (do this once at script startup, not inside draw):
local tex = mq.CreateTexture('uifiles\\default\\dragitem1.dds')
-- tex.size     -> ImVec2 with the texture's pixel dimensions
-- tex.fileName -> the path string

-- Find a named EQ UI animation (the sprite sheet system EQ uses):
local drag_anim = mq.FindTextureAnimation('A_DragItem')
-- A_DragItem is the item icon sprite sheet; each cell is one item icon.

-- Inside draw callback:
drag_anim:SetTextureCell(item.Icon())            -- pick which icon (by icon ID)
ImGui.DrawTextureAnimation(drag_anim, 40, 40)    -- render it at 40x40 pixels

-- Render a raw texture in ImGui:
ImGui.Image(tex:GetTextureID(), tex.size)
-- With UV crop (show only the top-left quarter of the texture):
ImGui.Image(tex:GetTextureID(), ImVec2(40, 40), ImVec2(0, 0), ImVec2(0.5, 0.5))
```

---

### ImGui Registration

Two equivalent ways to attach a draw callback to the ImGui render loop. The modern `ImGui.Register` style is preferred for new scripts.

```lua
-- Modern (preferred):
ImGui.Register('MyWindowName', function()
    -- draw stuff here
end)
ImGui.Unregister('MyWindowName')

-- Legacy (still works):
mq.imgui.init('MyWindowName', function()
    -- draw stuff here
end)
mq.imgui.destroy('MyWindowName')
local exists = mq.imgui.exists('MyWindowName')  -- returns bool
```

The name string (`'MyWindowName'`) must be unique across all running scripts.

---

### Saving & Loading Data with Pickle

`mq.pickle` and `mq.unpickle` serialize/deserialize Lua tables to and from files. This is the standard way to persist configuration between sessions.

```lua
-- Save a table to file:
local config = { volume = 80, enabled = true, name = 'Bob' }
mq.pickle(mq.configDir .. '/myscript.lua', config)

-- Load it back. Use pcall for safety in case the file doesn't exist yet:
local ok, loaded = pcall(mq.unpickle, mq.configDir .. '/myscript.lua')
if ok and loaded then
    config = loaded
end
```

---

### Path Constants

```lua
mq.configDir    -- absolute path to MQ2/config/      e.g. "C:/MQ2/config"
mq.luaDir       -- absolute path to MQ2/lua/         e.g. "C:/MQ2/lua"
mq.moduleDir    -- absolute path to MQ2/modules/     e.g. "C:/MQ2/modules"

-- The EQ game directory via TLO:
mq.TLO.MacroQuest.Path()
```

---

### Advanced: Custom TLOs and Type Introspection

```lua
-- Get a list of all registered TLO (data type) names:
local names = mq.GetDataTypeNames()   -- returns a table of strings
for _, name in ipairs(names) do
    print(name)
end

-- Register a custom top-level object accessible via mq.TLO.MyTLO:
-- The function receives one argument (the index string) and must return
-- a (typeName, typeValue) pair.
mq.AddTopLevelObject('MyTLO', function(index)
    return 'string', 'hello from MyTLO'
end)

mq.RemoveTopLevelObject('MyTLO')

-- Get the MQ type name of a TLO or type variable (returns string or nil):
local typeName = mq.gettype(mq.TLO.Me)   -- e.g. "character"
```

---

### Text Link Utilities

MQ provides functions for working with EverQuest chat text links (item links, spell links, etc.).

```lua
-- Strip all EQ text links from a string (useful for clean display):
local clean = mq.StripTextLinks(rawText)

-- Build a clickable item link from an item TLO:
local link = mq.FormatItemLink(mq.TLO.FindItem('Bone Chips'))

-- Build a clickable spell link:
local link = mq.FormatSpellLink(mq.TLO.Spell('Fire Bolt'))

-- Extract all links embedded in a chat line:
local links = mq.ExtractLinks(chatLine)  -- returns a table of link info objects

-- Parse a raw item link string:
local info = mq.ParseItemLink(linkStr)   -- returns info table or nil

-- Execute (click) a text link:
mq.ExecuteTextLink(link)
```

---

## 3. Top Level Objects (TLOs)

### Understanding TLOs

TLOs are how you read game state in MQ. They live under `mq.TLO` and form a hierarchy of objects. The key thing to understand is:

- `mq.TLO.Me.Level` — this is a **TLO object** (not the level number)
- `mq.TLO.Me.Level()` — calling it **returns the actual value**

You almost always want to call it. The raw object is only useful if you're passing it around to call multiple members on it later.

```lua
local me = mq.TLO.Me      -- store the TLO object for convenience

-- Good: calling () gets the value
local myLevel = me.Level()       -- returns 50 (number)
local myName  = me.Name()        -- returns "Playername" (string)

-- This just holds a reference to the TLO, not the value:
local levelTLO = me.Level        -- not useful on its own
```

**Nil-checking:** If a TLO doesn't exist or isn't applicable (e.g., `Target` when nothing is targeted), calling it returns `nil`. Always check before using:

```lua
if mq.TLO.Target() then
    print('Target name: ' .. mq.TLO.Target.Name())
end
```

---

### Me — The Player Character

`mq.TLO.Me` is the most-used TLO. It gives you everything about your own character.

```lua
local me = mq.TLO.Me

-- Identity:
me.Name()           -- "Playername"
me.Level()          -- 50
me.Class.Name()     -- "Warrior"
me.Race.Name()      -- "Human"

-- Health, Mana, Endurance:
me.CurrentHPs()
me.MaxHPs()
me.PctHPs()         -- 0 to 100 (percent)
me.CurrentMana()
me.MaxMana()
me.PctMana()
me.CurrentEndurance()
me.MaxEndurance()
me.PctEndurance()

-- Position and movement:
me.X()              -- East/West coordinate
me.Y()              -- North/South coordinate
me.Z()              -- Height (altitude)
me.Heading()        -- degrees (0=North, 128=East, 256=South, 384=West in EQ's system)
me.Speed()          -- movement speed
me.Moving()         -- boolean: currently moving?

-- Combat state:
me.Combat()         -- boolean: in combat?
me.CombatState()    -- "COMBAT", "DEBUFFED", "COOLDOWN", "ACTIVE", "RESTING"
me.SpellInCooldown() -- boolean: any spell GCD active?

-- Posture:
me.Sitting()        -- boolean
me.Standing()       -- boolean
me.Stunned()        -- boolean
me.Zoning()         -- boolean: actively zoning?

-- Group:
me.Grouped()        -- boolean
me.GroupSize()      -- number of members including yourself
me.AmIGroupLeader() -- boolean

-- Stats:
me.STR()
me.STA()
me.AGI()
me.DEX()
me.INT()
me.WIS()
me.CHA()

-- Currency:
me.Platinum()       -- plat on person
me.Gold()
me.Silver()
me.Copper()
me.PlatinumBank()   -- plat in bank
me.Cash()           -- total cash in coppers (all denominations combined)

-- Experience:
me.Exp()            -- raw exp number (0 to 330)
me.PctExp()         -- as a percentage
me.AAPoints()       -- unspent AA points

-- Account:
me.Subscription()   -- "GOLD", "SILVER", "FREE", or "UNKNOWN"

-- Inventory space:
me.FreeInventory()  -- number of free top-level bag slots
me.NumBagSlots()    -- total number of bag slots
```

#### Inventory

Access worn items by slot name or number, and bags by name (`pack1` through `pack10`). See Section 5 for the full slot table.

```lua
-- Worn items by slot name:
local helm   = me.Inventory('head')
local chest  = me.Inventory('chest')
local weapon = me.Inventory('primary')

-- Worn items by slot number:
local charm  = me.Inventory(0)

-- Bags:
local pack1  = me.Inventory('pack1')   -- first bag slot
local pack10 = me.Inventory('pack10')  -- last bag slot

-- Check if something is there before using it:
if helm() then
    print('Wearing: ' .. helm.Name())
end
```

#### Buffs and Songs

```lua
-- Check for a buff by name (returns the buff TLO, call () to check existence):
if me.Buff('Spirit of Wolf')() then
    print('SoW is active')
end

-- Access a buff by slot number:
local firstBuff = me.Buff(1)
if firstBuff() then
    print('First buff: ' .. firstBuff.Name())
end

-- Songs (short-duration bard buffs):
me.Song('Selo\'s Accelerando')

-- Buff counts:
me.CountBuffs()      -- how many buffs you currently have
me.FreeBuffSlots()   -- how many buff slots remain
```

#### Spells and Skills

```lua
-- Memorized spells:
local gem1spell = me.Gem(1)    -- spell in gem slot 1
if gem1spell() then
    print('Gem 1: ' .. gem1spell.Name())
end

-- Check if a spell is ready to cast:
if me.SpellReady('Cure Poison')() then
    mq.cmd('/cast Cure Poison')
end

-- Gem timer (ticks remaining before gem is ready):
local timer = me.GemTimer(1)()  -- 0 means ready

-- Find a spell in your spellbook (returns slot number):
local bookSlot = me.Book('Fire Bolt')()
if bookSlot then
    print('Fire Bolt is in spellbook slot ' .. bookSlot)
end

-- Skills:
me.Skill('Abjuration')       -- your current skill level
me.SkillCap('Abjuration')    -- cap for your class/level
```

---

### Target

`mq.TLO.Target` represents whatever your character currently has targeted. Always nil-check it first since you may not have a target.

```lua
local t = mq.TLO.Target

if t() then   -- non-nil means something is targeted
    t.Name()        -- display name
    t.CleanName()   -- name without guild tag, rank, etc.
    t.ID()          -- unique spawn ID
    t.Level()
    t.Type()        -- "NPC", "PC", "Pet", "Corpse", "Untargetable", etc.

    -- Health:
    t.CurrentHPs()
    t.MaxHPs()
    t.PctHPs()

    -- Position:
    t.X()
    t.Y()
    t.Z()
    t.Distance()    -- flat 2D distance from you
    t.Distance3D()  -- true 3D distance (includes height difference)
    t.Heading()

    -- Classification:
    t.NPC()         -- boolean
    t.PC()          -- boolean
    t.Corpse()      -- boolean
    t.Dead()        -- boolean

    -- State:
    t.Standing()
    t.Sitting()
    t.Stunned()

    -- Identity:
    t.Race.Name()
    t.Class.Name()

    -- Check if target has a specific buff:
    if t.Buff('Snare')() then
        print('Target is snared')
    end
end
```

---

### Spawn — Searching for Any Spawn

`mq.TLO.Spawn()` lets you look up any spawn in the zone by ID or by a search string. This is more flexible than `Target` because you can find spawns that aren't targeted.

```lua
-- By spawn ID:
local s = mq.TLO.Spawn(12345)
if s() then
    print(s.Name(), s.Distance())
end

-- By search string (see filter syntax below):
local nearestGoblin = mq.TLO.Spawn('npc name goblin radius 200')

-- Nearest NPC (1 = nearest):
local nearest = mq.TLO.NearestSpawn(1, 'npc')
-- Second nearest:
local second  = mq.TLO.NearestSpawn(2, 'npc')

-- Count spawns matching a filter:
local count = mq.TLO.SpawnCount('npc radius 100')()
print(count .. ' NPCs within 100 units')
```

#### Spawn Search Filter Syntax

These filter strings are used with `Spawn()`, `NearestSpawn()`, and `SpawnCount()`. Filters can be combined in a single string.

```
'npc'                 -- any NPC
'pc'                  -- any player character
'corpse'              -- any corpse
'pet'                 -- any pet

'npc radius 50'       -- NPC within 50 units of you
'npc id 12345'        -- NPC with spawn ID 12345
'npc name goblin'     -- NPC whose name contains "goblin"
'npc noalert'         -- NPC not on an alert list

-- Combine filters:
'npc name orc radius 100'    -- orc NPC within 100 units
```

---

### Zone

```lua
mq.TLO.Zone.Name()       -- "East Commonlands" (long display name)
mq.TLO.Zone.ShortName()  -- "ecommons" (short name, used in commands)
mq.TLO.Zone.ID()         -- numeric zone ID

-- Look up any zone by ID or short name:
local zone = mq.TLO.Zone(12)           -- zone by ID
local zone2 = mq.TLO.Zone('ecommons')  -- zone by short name
if zone() then
    print(zone.Name())
end
```

---

### FindItem — Searching Your Inventory

`FindItem` searches all of your bags and worn slots for an item. The `=` prefix forces an exact name match; without it, any item whose name contains the search string will match.

```lua
-- Partial match (finds "Bone Chips", "Bone Chipset", etc.):
local item = mq.TLO.FindItem('Bone Chips')

-- Exact match (only finds an item named exactly "Bone Chips"):
local item = mq.TLO.FindItem('=Bone Chips')

-- By item ID:
local item = mq.TLO.FindItem(13073)

-- Always check if it was found:
if mq.TLO.FindItem('=Bone Chips')() then
    print('I have Bone Chips')
end

-- Count how many you have (across all stacks):
local count = mq.TLO.FindItemCount('Bone Chips')()
print('I have ' .. count .. ' bone chips')

-- Search your bank instead:
local bankItem = mq.TLO.FindItemBank('=Diamond')
local bankCount = mq.TLO.FindItemBankCount('Diamond')()
```

---

### Cursor

The cursor represents an item you're currently "holding" (picked up from inventory, for example).

```lua
if mq.TLO.Cursor() then   -- true if you're holding an item
    local c = mq.TLO.Cursor
    c.Name()
    c.ID()
    c.Value()       -- value in coppers
    c.NoDrop()      -- boolean: no trade?
    c.Lore()        -- boolean: lore/unique?
    c.Stackable()
end

-- Put the cursor item into your inventory automatically:
mq.cmd('/autoinventory')
```

---

### Corpse (Open Loot Window)

`mq.TLO.Corpse` is only valid when you have a corpse's loot window open.

```lua
local itemCount = mq.TLO.Corpse.Items()()   -- number of items on the corpse
if itemCount and itemCount > 0 then
    for i = 1, itemCount do
        local lootItem = mq.TLO.Corpse.Item(i)
        if lootItem() then
            print('Loot: ' .. lootItem.Name())
        end
    end
end
```

---

### Group

```lua
local members = mq.TLO.Group.Members()()   -- number of members NOT including you
local leader  = mq.TLO.Group.Leader()      -- leader's name (string)

-- Access individual members (1 = first member, not counting yourself):
local member1 = mq.TLO.Group.Member(1)
if member1() then
    print(member1.Name(), member1.PctHPs())
end
```

---

### MacroQuest Info

```lua
mq.TLO.MacroQuest.Path()     -- full path to the EQ directory
mq.TLO.MacroQuest.Version()  -- MQ version string
```

---

### Window — EQ UI Windows

You can check the state of any EQ UI window by name.

```lua
local invWnd = mq.TLO.Window('InventoryWnd')

if invWnd.Open() then
    print('Inventory is open')
end

-- Open/close windows:
mq.cmd('/inventory')   -- toggle inventory window

-- Send a UI notification to a window element (for clicking UI buttons):
mq.cmd('/notify InventoryWnd IW_Pickup leftmouseup')
```

---

## 4. The `item` Data Type

Any time you get an item from `Me.Inventory()`, `FindItem()`, `Corpse.Item()`, etc., you get back an item TLO. All fields are called as functions to get values. Always nil-check with `()` first.

```lua
local item = mq.TLO.Me.Inventory('pack1').Item(1)

if item() then   -- check that something is actually in that slot
    -- Basic info:
    item.Name()         -- "Bone Chips"
    item.ID()           -- numeric item ID (e.g. 13073)
    item.Icon()         -- icon ID, for use with A_DragItem texture animation
    item.Type()         -- "Armor", "Weapon", "Misc", "Food", "Drink", etc.

    -- Value and trading:
    item.Value()        -- vendor value in coppers (divide by 1000 for plat)
    item.NoDrop()       -- boolean: no trade?
    item.Lore()         -- boolean: lore (unique) — can only carry one
    item.Magic()        -- boolean

    -- Stacking:
    item.Stackable()    -- boolean: does it stack?
    item.Stack()        -- how many are in this stack
    item.StackSize()    -- max stack size
    item.StackCount()   -- total of this item across all your bags

    -- Containers (bags):
    item.Container()    -- number of bag slots; 0 if not a bag
    item.Items()        -- number of items currently inside (if a bag)
    item.Item(1)        -- access item inside bag slot 1

    -- Physical properties:
    item.Size()         -- 1=SMALL, 2=MEDIUM, 3=LARGE, 4=GIANT
    item.Weight()

    -- Stats (the bonuses the item provides):
    item.AC()
    item.HP()
    item.Mana()
    item.STR()
    item.STA()
    item.AGI()
    item.DEX()
    item.INT()
    item.WIS()
    item.CHA()

    -- Weapon stats:
    item.Damage()       -- base weapon damage
    item.Haste()        -- haste percentage

    -- Requirements:
    item.RequiredLevel()

    -- Augments:
    item.AugType()      -- augment type number (0 if not an aug)

    -- Clickable items:
    item.Charges()         -- charges remaining (-1 = unlimited)
    item.TimerReady()      -- milliseconds until you can click it again (0 = ready)

    -- Merchant prices:
    item.BuyPrice()        -- what merchant charges you (if a merchant is open)
    item.SellPrice()       -- what merchant pays you

    -- Slot compatibility:
    item.WornSlot('chest')  -- boolean: can it go in the chest slot?

    -- Location:
    item.ItemSlot()         -- which top-level slot it's in (0-22 for worn, 22+ for bags)
    item.ItemSlot2()        -- sub-slot within a bag (1-10)

    -- Links:
    item.ItemLink()         -- EQ item link string (clickable in chat)

    -- UI:
    item.Inspect()          -- opens the item display window
end
```

### Practical Item Examples

```lua
-- Show value in platinum:
local valuePP = (item.Value() or 0) / 1000
print(string.format('%s: %.1f pp', item.Name(), valuePP))

-- Check if item is in a bag and iterate the bag:
if (item.Container() or 0) > 0 then
    for slot = 1, item.Container() do
        local inner = item.Item(slot)
        if inner() then
            print('  -> ' .. inner.Name())
        end
    end
end
```

---

## 5. Worn Slot Names & Numbers

Use these with `mq.TLO.Me.Inventory(name_or_number)` to access specific worn equipment slots.

| Slot # | Slot Name    | Slot # | Slot Name    |
|--------|--------------|--------|--------------|
| 0      | charm        | 12     | hands        |
| 1      | leftear      | 13     | primary      |
| 2      | head         | 14     | secondary    |
| 3      | face         | 15     | leftfinger   |
| 4      | rightear     | 16     | rightfinger  |
| 5      | neck         | 17     | chest        |
| 6      | shoulder     | 18     | legs         |
| 7      | arms         | 19     | feet         |
| 8      | back         | 20     | waist        |
| 9      | leftwrist    | 21     | powersource  |
| 10     | rightwrist   | 22     | ammo         |
| 11     | range        |        |              |

**Bag slots:** `pack1` through `pack10`

```lua
-- Examples:
local weapon   = mq.TLO.Me.Inventory('primary')
local offhand  = mq.TLO.Me.Inventory('secondary')
local chest    = mq.TLO.Me.Inventory(17)      -- same as 'chest'
local bag1     = mq.TLO.Me.Inventory('pack1')
```

---

## 6. ImGui Reference

### What Is Immediate Mode GUI?

ImGui is an "immediate mode" GUI system, which works very differently from traditional GUI frameworks. There are no persistent widget objects — instead, you redraw the entire UI from scratch every frame (60+ times per second). Every call to `ImGui.Button()`, `ImGui.Text()`, etc. both draws the widget AND returns its current state.

This means:
- **You manage all state** in Lua variables between frames
- **No callbacks for widgets** — just check return values
- **Draw callbacks must be fast** — no `mq.delay()`, no heavy computation

```lua
-- This is the mental model:
--   Frame 1:  ImGui.Button('OK') -> false (not clicked)
--   Frame 2:  ImGui.Button('OK') -> false
--   Frame 3:  ImGui.Button('OK') -> true  (user clicked)
--   Frame 4:  ImGui.Button('OK') -> false
-- Each frame you redraw the button; ImGui handles hover/click detection.
```

---

### The Basic ImGui Script Pattern

```lua
local mq    = require('mq')
local ImGui = require('ImGui')

local open   = true    -- tracks whether our window should be shown
local clicks = 0       -- example state variable

local function draw()
    if not open then return end

    -- ImGui.Begin returns two values:
    --   isOpen:     false if the user clicked the X close button
    --   shouldDraw: false if the window is collapsed (minimized)
    local isOpen, shouldDraw = ImGui.Begin('My Window', open)

    if not isOpen then
        open = false   -- user closed the window
    end

    if shouldDraw then
        ImGui.Text('You have clicked ' .. clicks .. ' times.')
        if ImGui.Button('Click Me') then
            clicks = clicks + 1
        end
    end

    ImGui.End()   -- ALWAYS call End(), even if shouldDraw is false
end

ImGui.Register('MyScript', draw)

-- Main loop keeps the script alive. The draw callback fires independently.
while open do
    mq.delay(500)
end
```

---

### Window Functions

```lua
-- Begin a window. The second argument (open) is the close button state.
--
-- Three-argument form (name, open, flags): returns (isOpen, shouldDraw)
--   isOpen    = false if the user clicked the X close button; otherwise same as the open arg
--   shouldDraw = false if the window is collapsed/minimized
local isOpen, shouldDraw = ImGui.Begin('Window Title', open)
local isOpen, shouldDraw = ImGui.Begin('Window Title', open, flags)
--
-- One-argument form (name only, no close button): returns a single bool
--   The returned bool is true if the window is not collapsed
local shouldDraw = ImGui.Begin('Window Title')
--
ImGui.End()   -- MUST be called even if shouldDraw is false

-- Child window (embedded within a parent window):
if ImGui.BeginChild('child_id', ImVec2(width, height)) then
    ImGui.Text('Child content')
end
ImGui.EndChild()   -- always call this

-- Set properties BEFORE the corresponding Begin():
ImGui.SetNextWindowPos(ImVec2(100, 100))      -- set position
ImGui.SetNextWindowSize(ImVec2(400, 300))     -- set size
ImGui.SetNextWindowBgAlpha(0.85)              -- transparency: 0.0=invisible, 1.0=opaque
```

#### Window Flags

Combine flags with `bit32.bor()` (see Section 10):

```lua
local flags = bit32.bor(
    ImGuiWindowFlags.NoTitleBar,
    ImGuiWindowFlags.NoResize,
    ImGuiWindowFlags.NoMove
)
local _, show = ImGui.Begin('##overlay', true, flags)
```

| Flag | Effect |
|------|--------|
| `ImGuiWindowFlags.NoTitleBar` | Hide the title bar |
| `ImGuiWindowFlags.NoResize` | User cannot resize |
| `ImGuiWindowFlags.NoMove` | User cannot drag |
| `ImGuiWindowFlags.NoScrollbar` | Hide scrollbar |
| `ImGuiWindowFlags.NoCollapse` | Hide collapse button |
| `ImGuiWindowFlags.AlwaysAutoResize` | Resize to fit content each frame |
| `ImGuiWindowFlags.NoBackground` | Transparent background |
| `ImGuiWindowFlags.NoInputs` | Ignore all mouse/keyboard input |
| `ImGuiWindowFlags.NoDecoration` | NoTitleBar + NoScrollbar + NoCollapse + NoResize |
| `ImGuiWindowFlags.MenuBar` | Reserve space for a menu bar |

---

### Text

```lua
ImGui.Text('Simple text')
ImGui.Text('Formatted: %s = %d', 'value', 42)   -- printf-style formatting

ImGui.TextColored(ImVec4(1, 0, 0, 1), 'Red text')     -- RGBA, each 0.0-1.0
ImGui.TextColored(ImVec4(0, 1, 0, 1), 'Green text')
ImGui.TextColored(ImVec4(1, 1, 0, 1), 'Yellow text')

ImGui.TextWrapped('This is long text that will wrap when it reaches the window edge.')
ImGui.TextDisabled('Greyed out, non-interactive text')

ImGui.LabelText('Label', 'Value')       -- right-aligned label + value pair
ImGui.BulletText('Bullet point item')

ImGui.SeparatorText('Section Header')   -- horizontal line with centered label
```

---

### Buttons and Checkboxes

Buttons return `true` on the frame they are released. Checkboxes return two values: `(newValue, wasPressed)` — in most scripts you only need the first.

```lua
-- Basic button:
if ImGui.Button('Do Something') then
    mq.cmd('/say I was clicked!')
end

-- Sized button (width, height in pixels):
if ImGui.Button('Wide Button', ImVec2(200, 30)) then ... end

-- Checkbox: returns (newValue, wasPressed)
-- newValue  = the updated boolean state (true/false)
-- wasPressed = true on the frame the user clicked (rarely needed)
local myBool = false
myBool = ImGui.Checkbox('Enable Feature', myBool)
-- or capture both return values if you need click detection:
-- local myBool, clicked = ImGui.Checkbox('Enable Feature', myBool)

-- Radio buttons: only one in a group can be active at a time
local selected = 0   -- which option is chosen
if ImGui.RadioButton('Option A', selected == 0) then selected = 0 end
if ImGui.RadioButton('Option B', selected == 1) then selected = 1 end
if ImGui.RadioButton('Option C', selected == 2) then selected = 2 end
```

---

### Input Fields

Input widgets return **two values**: the current value and a boolean that is `true` on the frame the user changed it. In most cases you only need the first return value, but capturing both lets you trigger actions exactly when the user commits a change.

```lua
-- Text input: returns (string, changed)
local myText = ''
myText = ImGui.InputText('Your Name', myText)
-- or to detect when the user finishes editing:
-- local myText, textChanged = ImGui.InputText('Your Name', myText)
-- if textChanged then saveConfig() end

-- Number inputs: returns (value, changed)
local myInt   = 0
local myFloat = 0.0
myInt   = ImGui.InputInt('Count', myInt)
myFloat = ImGui.InputFloat('Scale', myFloat)

-- Sliders: returns (value, changed)
myInt   = ImGui.SliderInt('Speed', myInt, 0, 100)
myFloat = ImGui.SliderFloat('Volume', myFloat, 0.0, 1.0)

-- Dropdown/combo box: returns (selectedIndex, clicked)
-- selectedIndex is 1-based (matches Lua table indexing)
local options = {'Option A', 'Option B', 'Option C'}
local current = 1   -- index of selected item (1-based)
current = ImGui.Combo('Choose', current, options, #options)
-- options[current] gives you the selected string
```

---

### Layout

These functions control spacing and arrangement of widgets.

```lua
ImGui.Separator()        -- horizontal line (use between sections)
ImGui.Spacing()          -- small vertical gap
ImGui.NewLine()          -- blank line (larger gap)

-- Put the next widget on the same line as the previous one:
ImGui.Button('Save')
ImGui.SameLine()
ImGui.Button('Cancel')

-- SameLine with pixel offset from the left edge:
ImGui.SameLine(200)       -- next widget starts 200px from the left

-- Indentation:
ImGui.Indent()
ImGui.Text('Indented text')
ImGui.Unindent()

-- Group multiple widgets so SameLine treats them as a unit:
ImGui.BeginGroup()
    ImGui.Text('Label')
    ImGui.Button('Button')
ImGui.EndGroup()
ImGui.SameLine()
ImGui.Text('This is next to the group')

-- Invisible spacer of exact size:
ImGui.Dummy(ImVec2(0, 20))   -- 20px vertical gap
ImGui.Dummy(ImVec2(50, 0))   -- 50px horizontal gap
```

---

### Tables

Tables are the correct way to display data in a grid. Do not use `SameLine` tricks for columnar layouts — use `BeginTable`.

```lua
local tableFlags = bit32.bor(
    ImGuiTableFlags.Borders,    -- draw borders around all cells
    ImGuiTableFlags.RowBg,      -- alternate row background colors
    ImGuiTableFlags.ScrollY,    -- enable vertical scrolling
    ImGuiTableFlags.Resizable   -- user can drag column width dividers
)

-- BeginTable(id, numColumns, flags, outerSize)
-- outerSize: ImVec2(width, height) — 0 = auto, -1 = fill available
if ImGui.BeginTable('##mytable', 3, tableFlags, ImVec2(0, 300)) then

    -- Freeze the header row so it stays visible while scrolling:
    ImGui.TableSetupScrollFreeze(0, 1)  -- freeze 0 columns, 1 row

    -- Define columns BEFORE calling TableHeadersRow:
    ImGui.TableSetupColumn('Name',     ImGuiTableColumnFlags.WidthStretch)  -- fills remaining space
    ImGui.TableSetupColumn('Value',    ImGuiTableColumnFlags.WidthFixed, 80)   -- fixed 80px
    ImGui.TableSetupColumn('Location', ImGuiTableColumnFlags.WidthFixed, 120)  -- fixed 120px

    -- Render the header row using the column names defined above:
    ImGui.TableHeadersRow()

    -- Render data rows:
    for _, row in ipairs(myData) do
        ImGui.TableNextRow()

        ImGui.TableSetColumnIndex(0)      -- move to column 0
        ImGui.Text(row.name)

        ImGui.TableSetColumnIndex(1)      -- move to column 1
        ImGui.Text(tostring(row.value))

        ImGui.TableSetColumnIndex(2)      -- move to column 2
        ImGui.Text(row.location)
    end

    ImGui.EndTable()
end
```

#### Common Table Flags

| Flag | Effect |
|------|--------|
| `ImGuiTableFlags.None` | No flags |
| `ImGuiTableFlags.Borders` | All borders (inner + outer) |
| `ImGuiTableFlags.BordersInner` | Inner borders only |
| `ImGuiTableFlags.BordersOuter` | Outer border only |
| `ImGuiTableFlags.RowBg` | Alternating row background colors |
| `ImGuiTableFlags.ScrollX` | Horizontal scrolling |
| `ImGuiTableFlags.ScrollY` | Vertical scrolling |
| `ImGuiTableFlags.Resizable` | User can resize columns |
| `ImGuiTableFlags.Sortable` | Enable column sort headers |
| `ImGuiTableFlags.NoHostExtendX` | Table does not extend to fill available width |

---

### Progress Bars

Progress bars display a 0.0–1.0 fraction as a filled bar.

```lua
-- Auto-width bar at 75%:
ImGui.ProgressBar(0.75)

-- Specific size (width, height in pixels):
ImGui.ProgressBar(0.75, ImVec2(200, 20))

-- Full-width (-1 = fill available width), with custom label text:
ImGui.ProgressBar(0.75, ImVec2(-1, 20), '75%')

-- Example: HP bar that shows current/max:
local fraction = me.CurrentHPs() / me.MaxHPs()
local label    = string.format('%d / %d', me.CurrentHPs(), me.MaxHPs())
ImGui.ProgressBar(fraction, ImVec2(-1, 18), label)
```

---

### Tooltips

Tooltips appear when the user hovers over an item. Always check `IsItemHovered()` first.

```lua
ImGui.Text('Hover over me')
if ImGui.IsItemHovered() then
    ImGui.SetTooltip('This is a simple one-line tooltip')
end

-- Rich tooltip with multiple widgets inside:
ImGui.Button('Hover for details')
if ImGui.IsItemHovered() then
    ImGui.BeginTooltip()
    ImGui.Text('Item Name: Bone Chips')
    ImGui.TextDisabled('Value: 0.1 pp')
    ImGui.EndTooltip()
end
```

---

### Colors and Styling

You can override colors and spacing for individual widgets by pushing style changes, drawing, then popping them back.

#### Color Values

`ImVec4(r, g, b, a)` — each channel is a float from 0.0 to 1.0.

```lua
ImVec4(1, 0, 0, 1)      -- red
ImVec4(0, 1, 0, 1)      -- green
ImVec4(0, 0, 1, 1)      -- blue
ImVec4(1, 1, 0, 1)      -- yellow
ImVec4(0, 0.5, 1, 1)    -- sky blue
ImVec4(1, 0.5, 0, 1)    -- orange
ImVec4(0.5, 0, 1, 1)    -- purple
ImVec4(1, 1, 1, 1)      -- white
ImVec4(0.5, 0.5, 0.5, 1) -- grey
ImVec4(1, 1, 1, 0.5)    -- semi-transparent white
```

#### Pushing Style Colors

Every `PushStyleColor` call must be balanced with a `PopStyleColor` call. You can batch multiple pushes and pop them all at once.

```lua
-- Make a button green:
ImGui.PushStyleColor(ImGuiCol.Button,        ImVec4(0,   0.5, 0,   1))
ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0,   0.7, 0,   1))
ImGui.PushStyleColor(ImGuiCol.ButtonActive,  ImVec4(0,   0.9, 0,   1))
if ImGui.Button('Go!') then ... end
ImGui.PopStyleColor(3)   -- must match the number of Push calls
```

#### Common Color Targets

| Target | What it affects |
|--------|----------------|
| `ImGuiCol.Text` | All text |
| `ImGuiCol.WindowBg` | Window background |
| `ImGuiCol.ChildBg` | Child window background |
| `ImGuiCol.Button` | Button background (normal) |
| `ImGuiCol.ButtonHovered` | Button background when hovered |
| `ImGuiCol.ButtonActive` | Button background when held |
| `ImGuiCol.FrameBg` | Input field background |
| `ImGuiCol.Header` | Selected item in tree/list |
| `ImGuiCol.PlotHistogram` | Progress bar fill color |

#### Style Variables

```lua
-- Rounded corners on buttons and input fields:
ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 6.0)
ImGui.Button('Rounded Button')
ImGui.PopStyleVar()

-- Adjust spacing between items:
ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(8, 4))
ImGui.Text('Line 1')
ImGui.Text('Line 2')
ImGui.PopStyleVar()

-- Multiple at once:
ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4.0)
ImGui.PushStyleVar(ImGuiStyleVar.FramePadding,  ImVec2(8, 4))
-- draw stuff
ImGui.PopStyleVar(2)
```

| Style Var | Type | Effect |
|-----------|------|--------|
| `ImGuiStyleVar.Alpha` | float | Overall opacity |
| `ImGuiStyleVar.WindowPadding` | ImVec2 | Padding inside windows |
| `ImGuiStyleVar.WindowRounding` | float | Corner rounding on windows |
| `ImGuiStyleVar.FramePadding` | ImVec2 | Padding inside input/button frames |
| `ImGuiStyleVar.FrameRounding` | float | Corner rounding on frames |
| `ImGuiStyleVar.ItemSpacing` | ImVec2 | Spacing between items |
| `ImGuiStyleVar.IndentSpacing` | float | Width of an indent step |

---

### Drawing Item Icons

Item icons in EQ are stored as cells in a large sprite sheet texture. Use `FindTextureAnimation` to get the animation object once at startup, then select the cell by icon ID inside your draw callback.

```lua
-- At script startup (OUTSIDE the draw callback):
local drag_anim = mq.FindTextureAnimation('A_DragItem')

-- Inside the draw callback, for each item you want to show an icon for:
local item = mq.TLO.Me.Inventory('primary')
if item() and drag_anim then
    drag_anim:SetTextureCell(item.Icon())        -- select the correct icon sprite
    ImGui.DrawTextureAnimation(drag_anim, 40, 40) -- draw at 40x40 pixels
    ImGui.SameLine()
    ImGui.Text(item.Name())
end
```

---

### Selectable Lists

`Selectable` is a clickable row — like a list item. It returns `true` when clicked.

```lua
local selectedIdx = -1   -- -1 means nothing selected

for i, entry in ipairs(myList) do
    -- Second arg is whether this item is currently selected (for highlight)
    if ImGui.Selectable(entry.name, selectedIdx == i) then
        selectedIdx = i   -- update selection on click
    end
end

if selectedIdx >= 1 then
    ImGui.Text('Selected: ' .. myList[selectedIdx].name)
end
```

---

### Collapsing Sections and Tree Nodes

Use these to organize content into expandable sections.

```lua
-- CollapsingHeader: a clickable header that shows/hides content
if ImGui.CollapsingHeader('Settings') then
    -- Only drawn when the header is expanded:
    ImGui.Checkbox('Enable X', enableX)
    ImGui.SliderFloat('Speed', speed, 0, 100)
end

-- TreeNode: an indented expandable node with an arrow
if ImGui.TreeNode('Advanced Options') then
    -- Only drawn when expanded:
    ImGui.Text('Some advanced setting')
    ImGui.TreePop()   -- MUST call TreePop() when TreeNode returns true
end
```

---

### Popups

Popups are modal or non-modal windows triggered by user action.

```lua
-- Trigger a popup by calling OpenPopup on the same frame a button is pressed:
if ImGui.Button('Open Popup') then
    ImGui.OpenPopup('MyPopup##id')
end

-- Render the popup (BeginPopup handles show/hide automatically):
if ImGui.BeginPopup('MyPopup##id') then
    ImGui.Text('You opened the popup!')
    if ImGui.Button('Close') then
        ImGui.CloseCurrentPopup()
    end
    ImGui.EndPopup()
end

-- Modal popup (blocks all other input until closed):
if ImGui.Button('Delete Item') then
    ImGui.OpenPopup('Confirm Delete')
end
if ImGui.BeginPopupModal('Confirm Delete', nil, ImGuiWindowFlags.AlwaysAutoResize) then
    ImGui.Text('Are you sure you want to delete this item?')
    ImGui.Spacing()
    if ImGui.Button('Yes, Delete') then
        -- do the delete
        ImGui.CloseCurrentPopup()
    end
    ImGui.SameLine()
    if ImGui.Button('Cancel') then
        ImGui.CloseCurrentPopup()
    end
    ImGui.EndPopup()
end
```

---

### Querying Item and Mouse State

After drawing a widget, you can query information about it using the `IsItem*` functions. These always refer to the most recently drawn widget.

```lua
ImGui.Button('Hover Me')
if ImGui.IsItemHovered() then ... end    -- mouse is over the button
if ImGui.IsItemClicked() then ... end    -- button was clicked this frame
if ImGui.IsItemActive() then ... end     -- button is currently being held
if ImGui.IsItemVisible() then ... end    -- button is visible (not clipped)
local sz = ImGui.GetItemRectSize()       -- returns ImVec2 with width/height
```

---

### Tabs

```lua
if ImGui.BeginTabBar('##maintabs') then
    if ImGui.BeginTabItem('Overview') then
        ImGui.Text('Overview content here')
        ImGui.EndTabItem()   -- always call when BeginTabItem returns true
    end

    if ImGui.BeginTabItem('Settings') then
        ImGui.Text('Settings content here')
        ImGui.EndTabItem()
    end

    if ImGui.BeginTabItem('Log') then
        ImGui.Text('Log content here')
        ImGui.EndTabItem()
    end

    ImGui.EndTabBar()
end
```

---

### Menu Bar

To add a menu bar to a window, include `ImGuiWindowFlags.MenuBar` in the window flags, then call `BeginMenuBar()` inside the window body.

```lua
local flags = ImGuiWindowFlags.MenuBar

local isOpen, show = ImGui.Begin('My App', open, flags)
if not isOpen then open = false end

if show then
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu('File') then
            if ImGui.MenuItem('Save') then
                saveConfig()
            end
            if ImGui.MenuItem('Quit') then
                open = false
            end
            ImGui.EndMenu()
        end

        if ImGui.BeginMenu('Help') then
            if ImGui.MenuItem('About') then
                -- show about info
            end
            ImGui.EndMenu()
        end

        ImGui.EndMenuBar()
    end

    -- rest of window content
end

ImGui.End()
```

---

## 7. Common Patterns & Recipes

### Pattern 1: Complete Minimal Script with ImGui Window

A self-contained script template you can use as a starting point for any project.

```lua
local mq    = require('mq')
local ImGui = require('ImGui')

local open   = true
local clicks = 0

local function draw()
    if not open then return end

    local isOpen, show = ImGui.Begin('My Script', open)
    if not isOpen then open = false end

    if show then
        ImGui.Text('Clicks: ' .. clicks)
        if ImGui.Button('Click Me') then
            clicks = clicks + 1
        end
    end

    ImGui.End()
end

ImGui.Register('MyScript', draw)

while open do
    mq.delay(500)
end
```

---

### Pattern 2: Running Slash Commands

The most common thing an MQ script does — issuing commands to control your character.

```lua
-- Basic commands:
mq.cmd('/say Hello everyone!')
mq.cmd('/cast 3')               -- cast spell in gem slot 3
mq.cmd('/sit')
mq.cmd('/stand')
mq.cmd('/autoinventory')        -- put cursor item into your bags

-- Commands with variable data (use cmdf):
local spawnId = 12345
mq.cmdf('/target id %d', spawnId)

local playerName = 'Bob'
mq.cmdf('/tell %s I am on my way', playerName)

mq.cmdf('/say My HP is %d out of %d', mq.TLO.Me.CurrentHPs(), mq.TLO.Me.MaxHPs())
```

---

### Pattern 3: Waiting for Something to Happen

Never use a fixed `delay` to wait for game actions — the timing varies. Instead, use `mq.delay` with a condition that terminates the wait early once the expected state is reached.

```lua
-- Cast a spell and wait up to 5 seconds for it to finish casting:
mq.cmd('/cast 1')
mq.delay(5000, function()
    return mq.TLO.Me.Casting() == nil   -- stop waiting once no longer casting
end)

-- Start navigation and wait up to 30 seconds to arrive:
mq.cmdf('/nav id %d', targetId)
mq.delay(30000, function()
    return not mq.TLO.Navigation.Active()
end)

-- Wait up to 10 seconds for a loot window to appear:
mq.cmd('/loot')
mq.delay(10000, function()
    return mq.TLO.Corpse.Items() ~= nil
end)

-- Wait until you are no longer moving:
mq.delay(10000, function()
    return not mq.TLO.Me.Moving()
end)
```

---

### Pattern 4: Reading Character Info

Pulling game state into readable output or variables for logic decisions.

```lua
local me = mq.TLO.Me

-- Formatted output:
print(string.format('Name:  %s (Level %d %s %s)',
    me.Name(), me.Level(), me.Race.Name(), me.Class.Name()))

print(string.format('HP:    %d / %d (%.0f%%)',
    me.CurrentHPs(), me.MaxHPs(), me.PctHPs()))

print(string.format('Mana:  %d / %d (%.0f%%)',
    me.CurrentMana(), me.MaxMana(), me.PctMana()))

print(string.format('Zone:  %s', mq.TLO.Zone.Name()))

local targetName = mq.TLO.Target.Name() or 'none'
print(string.format('Target: %s', targetName))

print(string.format('Cash:  %d pp', me.Platinum()))
print(string.format('State: %s', me.CombatState()))
```

---

### Pattern 5: Scanning Inventory

Iterating through all bags and their contents. Remember to handle the nil cases — not every bag slot has a bag, and not every bag slot within a bag has an item.

```lua
local totalValue = 0

for bagNum = 1, 10 do
    local bag = mq.TLO.Me.Inventory('pack' .. bagNum)

    -- Check that a bag exists in this slot and that it IS a bag (has slots):
    if bag() and (bag.Container() or 0) > 0 then
        for slot = 1, bag.Container() do
            local item = bag.Item(slot)
            if item() then
                local valuePP = (item.Value() or 0) / 1000
                totalValue = totalValue + valuePP
                print(string.format('  [pack%d/%d] %s — %.1f pp',
                    bagNum, slot, item.Name(), valuePP))
            end
        end
    end
end

print(string.format('Total inventory value: %.1f pp', totalValue))
```

---

### Pattern 6: Listening for Chat Events

Use events to react to specific things that appear in the chat log.

```lua
local running = true

-- Fire when someone sends you a tell.
-- #*# matches any text (ignored), #1# captures matching text as an argument.
mq.event('OnTell', '#*#tells you, \'#1#\'', function(line, message)
    print('Got tell: ' .. message)
    mq.cmdf('/tell sender Thank you for your message!')
end)

-- React to dying:
mq.event('OnDeath', 'You have been slain by #*#', function()
    print('I was slain! Stopping script.')
    running = false
end)

-- React to zone messages:
mq.event('OnZoneMessage', '#*#has entered the zone.#*#', function()
    -- someone zoned in, do something
end)

-- REQUIRED: call doevents() every loop iteration or events won't fire
while running do
    mq.doevents()
    mq.delay(100)
end

-- Clean up events when done:
mq.unevent('OnTell')
mq.unevent('OnDeath')
mq.unevent('OnZoneMessage')
```

---

### Pattern 7: HP Bar with Color

Drawing a health bar where the color shifts from green to red as HP drops — a common HUD element.

```lua
local function drawHPBar(entity)
    local current = entity.CurrentHPs() or 0
    local max     = entity.MaxHPs() or 1
    local pct     = math.max(0, math.min(1, current / max))

    -- Red increases as HP drops, green increases as HP rises:
    local r = 1.0 - pct
    local g = pct
    local b = 0.0

    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(r, g, b, 1))
    ImGui.ProgressBar(pct, ImVec2(-1, 18),
        string.format('%d / %d', current, max))
    ImGui.PopStyleColor()
end

-- Usage in a draw callback:
local function draw()
    local _, show = ImGui.Begin('HP Monitor', true)
    if show then
        ImGui.Text('My HP:')
        drawHPBar(mq.TLO.Me)

        if mq.TLO.Target() then
            ImGui.Spacing()
            ImGui.Text('Target HP:')
            drawHPBar(mq.TLO.Target)
        end
    end
    ImGui.End()
end
```

---

### Pattern 8: Binding a Custom Slash Command

Expose controls for your script via in-game commands.

```lua
local enabled = false

mq.bind('/mytoggle', function()
    enabled = not enabled
    print('[MyScript] ' .. (enabled and 'Enabled' or 'Disabled'))
end)

mq.bind('/mygreet', function(name)
    -- Arguments after the command name come in as separate strings
    local target = name or 'everyone'
    mq.cmdf('/say Hello, %s!', target)
end)

-- In-game usage:
--   /mytoggle         -> toggles enabled state
--   /mygreet Bob      -> /say Hello, Bob!
--   /mygreet          -> /say Hello, everyone!

-- Always clean up bindings when the script ends:
local function onShutdown()
    mq.unbind('/mytoggle')
    mq.unbind('/mygreet')
end
```

---

### Pattern 9: Saving and Loading Config with Pickle

Persist settings across sessions using `mq.pickle` and `mq.unpickle`. Store config files in `mq.configDir` so they live alongside other MQ configuration.

```lua
local configPath = mq.configDir .. '/myscript.lua'

-- Default config (used if no saved config exists):
local config = {
    enabled   = true,
    interval  = 1000,
    message   = 'Hello!',
    windowPos = { x = 100, y = 100 },
}

-- Load saved config (if it exists):
local ok, loaded = pcall(mq.unpickle, configPath)
if ok and loaded then
    -- Merge loaded values into defaults (so new keys in defaults are preserved):
    for k, v in pairs(loaded) do
        config[k] = v
    end
    print('[MyScript] Config loaded.')
end

-- Save the config (call this when settings change or on shutdown):
local function saveConfig()
    mq.pickle(configPath, config)
    print('[MyScript] Config saved.')
end

-- Example: save on script exit via a bind:
mq.bind('/mysave', saveConfig)
```

---

### Pattern 10: Checking for a Buff and Reacting

Poll for game conditions in the main loop and act on them. This is the core of any automation script.

```lua
local running = true

while running do
    local me = mq.TLO.Me

    -- Don't do anything if we're in certain bad states:
    if me.Zoning() or not me.Standing() then
        mq.delay(500)
        goto continue
    end

    -- Rebuff if Spirit of Wolf dropped:
    if not me.Buff('Spirit of Wolf')() then
        if me.SpellReady('Spirit of Wolf')() then
            mq.cmd('/cast Spirit of Wolf')
            -- Wait up to 5 seconds for cast to complete:
            mq.delay(5000, function()
                return mq.TLO.Me.Casting() == nil
            end)
        end
    end

    -- Sit to med if mana is low and not in combat:
    if me.PctMana() < 50 and not me.Combat() then
        if not me.Sitting() then
            mq.cmd('/sit on')
        end
    elseif me.PctMana() >= 95 and me.Sitting() then
        mq.cmd('/sit off')
    end

    mq.doevents()
    mq.delay(1000)

    ::continue::
end
```

---

### Pattern 11: A Complete HUD Overlay

A minimal HUD that sits on screen without a title bar, showing essential character info.

```lua
local mq    = require('mq')
local ImGui = require('ImGui')

local running = true

local function drawHUD()
    -- Position and configure the HUD window:
    ImGui.SetNextWindowPos(ImVec2(10, 10))
    ImGui.SetNextWindowBgAlpha(0.6)

    local hudFlags = bit32.bor(
        ImGuiWindowFlags.NoTitleBar,
        ImGuiWindowFlags.NoResize,
        ImGuiWindowFlags.NoMove,
        ImGuiWindowFlags.AlwaysAutoResize,
        ImGuiWindowFlags.NoInputs
    )

    local _, show = ImGui.Begin('##hud', true, hudFlags)

    if show then
        local me = mq.TLO.Me

        -- Name and level:
        ImGui.TextColored(ImVec4(1, 1, 0, 1),
            string.format('%s [%d]', me.Name() or '?', me.Level() or 0))

        -- HP bar:
        local hpPct = (me.PctHPs() or 0) / 100
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(1 - hpPct, hpPct, 0, 1))
        ImGui.ProgressBar(hpPct, ImVec2(200, 14),
            string.format('HP %d%%', me.PctHPs() or 0))
        ImGui.PopStyleColor()

        -- Mana bar (only if class has mana):
        if (me.MaxMana() or 0) > 0 then
            local manaPct = (me.PctMana() or 0) / 100
            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(0.2, 0.4, 1, 1))
            ImGui.ProgressBar(manaPct, ImVec2(200, 14),
                string.format('MP %d%%', me.PctMana() or 0))
            ImGui.PopStyleColor()
        end

        -- Zone:
        ImGui.TextDisabled(mq.TLO.Zone.ShortName() or '?')
    end

    ImGui.End()
end

ImGui.Register('HUD', drawHUD)

while running do
    mq.doevents()
    mq.delay(100)
end
```

---

## 8. MQ Chat Color Codes

When printing to the EQ chat window via `print()` or `mq.cmd('/echo ...')`, you can embed color codes directly in the string. Use `\ax` to reset back to the default color.

| Code | Color |
|------|-------|
| `\ag` | Green |
| `\ar` | Red |
| `\ay` | Yellow |
| `\ab` | Blue (dark) |
| `\at` | Teal |
| `\am` | Magenta / Purple |
| `\aw` | White |
| `\ao` | Orange |
| `\ax` | Reset to default |

```lua
-- Announce script activity with colored prefix:
print('\ag[MyScript]\ax Script started.')

-- Highlight an item name:
print('\ag[MyScript]\ax Found item: \at' .. itemName .. '\ax')

-- Show an error:
print('\ar[MyScript ERROR]\ax Something went wrong!')

-- Multi-color line:
print(string.format('\ay[Warning]\ax HP is only \ar%d%%\ax!', me.PctHPs()))
```

Note: These color codes work in EQ chat output. They do not affect ImGui `ImGui.Text()` calls — use `ImGui.TextColored()` or `ImGui.PushStyleColor()` for colored ImGui text.

---

## 9. ImGui ID Tips (the ## Trick)

ImGui identifies every widget internally by its label text. If two widgets share the same label, they'll conflict and behave unexpectedly — clicks on one may register on the other, or state may be shared incorrectly.

### The `##` Separator

Everything after `##` in a label is used as part of the internal ID, but is NOT displayed as text. This lets you have multiple widgets with the same visible label but different IDs.

```lua
-- Two "OK" buttons — without the ## trick, these would conflict:
if ImGui.Button('OK##confirm_dialog') then confirmAction()  end
if ImGui.Button('OK##cancel_dialog')  then cancelAction()   end
-- Both show "OK" but have different IDs

-- Windows follow the same rule:
ImGui.Begin('Settings##player_settings')   -- visible title: "Settings"
ImGui.Begin('Settings##world_settings')    -- visible title: "Settings" (different window!)
```

### The `###` Separator

Everything after `###` becomes the entire ID, replacing the visible label. Use this when the visible label changes dynamically but the widget identity should stay constant.

```lua
-- The ID is always "my_button" regardless of what the label says:
local label = 'Click me (' .. clicks .. ')'
if ImGui.Button(label .. '###my_button') then
    clicks = clicks + 1
end
```

### `PushID` / `PopID` for Loops

When generating widgets in a loop, use `PushID`/`PopID` to create a unique ID scope. This prevents all the "Delete" buttons in a list from sharing one ID.

```lua
for i, item in ipairs(myList) do
    ImGui.PushID(i)   -- creates a unique scope using the index

    if ImGui.Button('Delete') then
        table.remove(myList, i)   -- safe: each button has a unique ID
    end

    ImGui.SameLine()
    ImGui.Text(item.name)

    ImGui.PopID()
end
```

You can also push string IDs:

```lua
ImGui.PushID('section_a')
ImGui.Button('OK')    -- ID is effectively "section_a/OK"
ImGui.PopID()

ImGui.PushID('section_b')
ImGui.Button('OK')    -- ID is effectively "section_b/OK" — no conflict
ImGui.PopID()
```

---

## 10. Useful `bit32` Operations

ImGui flags are bitmasks — integers where each bit represents a boolean option. You combine them using bitwise OR. The `bit32` library is available globally in the MQ Lua environment.

### Combining Flags (Most Common Use)

```lua
-- Combine multiple flags into one value:
local windowFlags = bit32.bor(
    ImGuiWindowFlags.NoTitleBar,
    ImGuiWindowFlags.NoResize,
    ImGuiWindowFlags.NoMove
)

local tableFlags = bit32.bor(
    ImGuiTableFlags.Borders,
    ImGuiTableFlags.RowBg,
    ImGuiTableFlags.ScrollY
)
```

### Other bit32 Operations

```lua
-- Bitwise AND: test whether a flag is set
local hasFlag = bit32.band(flags, ImGuiWindowFlags.NoResize) ~= 0

-- Bitwise OR: combine flags (most common use)
local combined = bit32.bor(flag1, flag2, flag3)

-- Bitwise XOR: toggle a flag
local toggled = bit32.bxor(flags, ImGuiWindowFlags.NoMove)

-- Bitwise NOT: invert all bits
local inverted = bit32.bnot(flags)

-- Left shift: equivalent to multiplying by 2^n
local shifted = bit32.lshift(1, 4)   -- = 16  (bit 4)

-- Right shift: equivalent to integer dividing by 2^n
local value = bit32.rshift(flags, 2)
```

### Practical Example: Checking and Toggling Flags

```lua
local flags = bit32.bor(
    ImGuiWindowFlags.NoTitleBar,
    ImGuiWindowFlags.NoResize
)

-- Check if NoResize flag is set:
local isFixed = bit32.band(flags, ImGuiWindowFlags.NoResize) ~= 0
print('Window is ' .. (isFixed and 'fixed size' or 'resizable'))

-- Remove the NoResize flag (keep everything else):
local resizableFlags = bit32.band(flags, bit32.bnot(ImGuiWindowFlags.NoResize))
```

---

## 11. Draw Lists (ImDrawList)

Draw lists let you draw raw primitives — lines, rectangles, circles, text, textures — directly onto the screen, bypassing the normal ImGui widget system. This is the right tool for HUD overlays, custom gauges, world-space markers, and anything that doesn't fit inside a window.

> **Verified against** `lua_ImGuiUserTypes.cpp` and `lua_ImGuiCore.cpp` from the MQ source tree.

---

### Three Draw Lists — Which One to Use?

| Function | What it draws on | Coordinate origin |
|---|---|---|
| `ImGui.GetForegroundDrawList()` | On top of **everything** — windows, widgets, UI | Screen (0,0 = top-left) |
| `ImGui.GetBackgroundDrawList()` | Behind **everything** — appears under all windows | Screen (0,0 = top-left) |
| `ImGui.GetWindowDrawList()` | Inside the current ImGui window, behind its widgets | Screen (0,0 = top-left) |

**Important:** all three use **screen coordinates**, not window-relative coordinates. Even `GetWindowDrawList` uses absolute screen positions. Use `ImGui.GetWindowPos()` or `ImGui.GetCursorScreenPos()` to find reference points.

```lua
-- GetForegroundDrawList: draw on top of everything, any time from within an ImGui callback
local dl = ImGui.GetForegroundDrawList()

-- GetBackgroundDrawList: draw behind everything
local dl = ImGui.GetBackgroundDrawList()

-- GetWindowDrawList: draw inside the current window (must be between Begin/End)
-- Must be called from inside an ImGui.Begin() / ImGui.End() block
local dl = ImGui.GetWindowDrawList()
```

---

### Color Format (ImU32)

All draw-list functions take colors as a single `ImU32` integer.

The format is `0xAABBGGRR` where each pair of hex digits is:
- `AA` = Alpha (FF = fully opaque, 00 = fully transparent) — **highest** byte
- `BB` = Blue
- `GG` = Green
- `RR` = Red — **lowest** byte

```lua
-- Common colors (all fully opaque, AA = FF):
local RED    = 0xFF0000FF   -- R=FF, G=00, B=00
local GREEN  = 0xFF00FF00   -- R=00, G=FF, B=00
local BLUE   = 0xFFFF0000   -- R=00, G=00, B=FF
local YELLOW = 0xFF00FFFF   -- R=FF, G=FF, B=00
local WHITE  = 0xFFFFFFFF
local BLACK  = 0xFF000000

-- Semi-transparent yellow (alpha = 80 = ~50% opaque):
local YELLOW_50 = 0x8000FFFF

-- Convert from float RGBA (each value 0.0–1.0):
local col = ImGui.ColorConvertFloat4ToU32(ImVec4(1.0, 0.5, 0.0, 1.0))  -- orange
```

---

### Useful Screen-Position Helpers

Use these to find positions for drawing before calling draw-list functions.

```lua
-- Total screen dimensions (e.g. 1920 x 1080)
local screen = ImGui.GetDisplaySize()     -- returns ImVec2

-- Current ImGui window's top-left corner in screen coordinates
local win_pos = ImGui.GetWindowPos()      -- returns ImVec2

-- Current ImGui cursor position in screen coordinates
-- (where the next widget would be drawn)
local cursor = ImGui.GetCursorScreenPos() -- returns ImVec2
```

---

### Primitives Reference

All examples below assume `local dl = ImGui.GetForegroundDrawList()`.

#### Lines

```lua
-- AddLine(p1, p2, color, thickness?)
dl:AddLine(ImVec2(100, 100), ImVec2(300, 100), 0xFFFFFFFF)           -- white, 1px
dl:AddLine(ImVec2(100, 200), ImVec2(300, 200), 0xFF0000FF, 3.0)      -- red, 3px thick
```

#### Rectangles

```lua
-- AddRect(top_left, bottom_right, color, rounding?, flags?, thickness?)
-- Draws an outline rectangle.
dl:AddRect(ImVec2(50, 50), ImVec2(200, 100), 0xFFFFFFFF)             -- 1px outline
dl:AddRect(ImVec2(50, 50), ImVec2(200, 100), 0xFFFFFFFF, 8.0)        -- rounded corners

-- AddRectFilled(top_left, bottom_right, color, rounding?)
-- Draws a filled rectangle.
dl:AddRectFilled(ImVec2(50, 50), ImVec2(200, 100), 0x800000FF)       -- semi-transparent red fill
dl:AddRectFilled(ImVec2(50, 50), ImVec2(200, 100), 0x800000FF, 6.0)  -- with rounded corners

-- AddRectFilledMultiColor(top_left, bottom_right, col_top_left, col_top_right, col_bot_right, col_bot_left)
-- Draws a filled rectangle with a different color at each corner (gradient).
dl:AddRectFilledMultiColor(
    ImVec2(50, 50), ImVec2(250, 150),
    0xFF0000FF,   -- top-left: red
    0xFF00FF00,   -- top-right: green
    0xFFFF0000,   -- bottom-right: blue
    0xFFFFFFFF    -- bottom-left: white
)
```

#### Circles

```lua
-- AddCircle(center, radius, color, num_segments?, thickness?)
-- num_segments = 0 means auto (ImGui picks a smooth value)
dl:AddCircle(ImVec2(400, 300), 50, 0xFFFFFFFF)          -- white circle outline
dl:AddCircle(ImVec2(400, 300), 50, 0xFFFFFFFF, 32, 2.0) -- 32 segments, 2px thick

-- AddCircleFilled(center, radius, color, num_segments?)
dl:AddCircleFilled(ImVec2(400, 300), 50, 0x8000FF00)    -- semi-transparent green fill
```

#### Triangles

```lua
-- AddTriangle(p1, p2, p3, color, thickness?)
dl:AddTriangle(ImVec2(200, 300), ImVec2(250, 200), ImVec2(300, 300), 0xFFFFFFFF)
dl:AddTriangle(ImVec2(200, 300), ImVec2(250, 200), ImVec2(300, 300), 0xFFFFFFFF, 2.0)

-- AddTriangleFilled(p1, p2, p3, color)
dl:AddTriangleFilled(ImVec2(200, 300), ImVec2(250, 200), ImVec2(300, 300), 0xFF0000FF)
```

#### Quads (four arbitrary corners)

```lua
-- AddQuad(p1, p2, p3, p4, color, thickness?)
-- Points should be in order (clockwise or counter-clockwise).
dl:AddQuad(ImVec2(100,100), ImVec2(200,80), ImVec2(220,180), ImVec2(120,200), 0xFFFFFFFF)

-- AddQuadFilled(p1, p2, p3, p4, color)
dl:AddQuadFilled(ImVec2(100,100), ImVec2(200,80), ImVec2(220,180), ImVec2(120,200), 0x8000FFFF)
```

#### N-sided Regular Polygons (Ngon)

```lua
-- AddNgon(center, radius, color, num_segments, thickness?)
-- num_segments must be >= 3. Use this for pentagons, hexagons, etc.
dl:AddNgon(ImVec2(300, 300), 60, 0xFFFFFFFF, 6)         -- hexagon outline
dl:AddNgon(ImVec2(300, 300), 60, 0xFFFFFFFF, 5, 2.0)    -- pentagon, 2px thick

-- AddNgonFilled(center, radius, color, num_segments)
dl:AddNgonFilled(ImVec2(300, 300), 60, 0x8000FFFF, 6)   -- filled hexagon
```

#### Text

```lua
-- AddText(pos, color, text)
-- Uses the default ImGui font at default size.
dl:AddText(ImVec2(100, 100), 0xFFFFFFFF, "Hello EQ!")

-- AddText(font, font_size, pos, color, text)
-- Use a specific font and size.
local font = ImGui.GetEQImFont(0)   -- EQ font style 0; see Section 6 for styles
dl:AddText(font, 16.0, ImVec2(100, 120), 0xFF00FFFF, "Custom font text")
```

#### Bezier Curves

```lua
-- AddBezierCubic(p1, p2, p3, p4, color, thickness, num_segments?)
-- A cubic bezier: p1=start, p2/p3=control points, p4=end.
dl:AddBezierCubic(
    ImVec2(100, 200),   -- start
    ImVec2(200, 100),   -- control 1
    ImVec2(300, 300),   -- control 2
    ImVec2(400, 200),   -- end
    0xFFFFFFFF, 2.0
)

-- AddBezierQuadratic(p1, p2, p3, color, thickness, num_segments?)
-- A quadratic bezier: p1=start, p2=control, p3=end.
dl:AddBezierQuadratic(
    ImVec2(100, 200),   -- start
    ImVec2(250, 50),    -- control point
    ImVec2(400, 200),   -- end
    0xFFFFFFFF, 2.0
)
```

#### Polylines and Filled Polygons

For these, pass a Lua **table** of `ImVec2` values.

```lua
local points = {
    ImVec2(100, 200),
    ImVec2(150, 100),
    ImVec2(250, 100),
    ImVec2(300, 200),
    ImVec2(200, 260),
}

-- AddPolyline(points_table, color, flags, thickness)
-- flags: 0 = open line, 1 = closed loop (connects last point back to first)
dl:AddPolyline(points, 0xFFFFFFFF, 0, 2.0)   -- open polyline
dl:AddPolyline(points, 0xFFFFFFFF, 1, 2.0)   -- closed polygon outline

-- AddConvexPolyFilled(points_table, color)
-- Fill a convex polygon. Points must form a convex shape (no caves/indentations).
dl:AddConvexPolyFilled(points, 0x8000FF00)

-- AddConcavePolyFilled(points_table, color)
-- Fill a concave polygon (any shape). Slower than AddConvexPolyFilled.
dl:AddConcavePolyFilled(points, 0x8000FF00)
```

---

### EQ Texture Icons (AddTextureAnimation)

This is a MQ-specific extension. It lets you draw a `CTextureAnimation` directly on a draw list at any screen position — no ImGui window needed.

```lua
-- AddTextureAnimation(anim, pos, size?)
-- pos  = ImVec2 screen position (top-left of where icon is drawn)
-- size = ImVec2 (optional; omit to use the animation's native size)

local drag_anim = mq.FindTextureAnimation("A_DragItem")

local function draw()
    local dl = ImGui.GetForegroundDrawList()

    -- Draw the icon for item with icon_id at screen position (200, 200), 40x40 pixels
    drag_anim:SetTextureCell(icon_id)                          -- select which icon
    dl:AddTextureAnimation(drag_anim, ImVec2(200, 200), ImVec2(40, 40))

    -- Without a size argument (uses animation's native size):
    dl:AddTextureAnimation(drag_anim, ImVec2(250, 200))
end

ImGui.Register("MyOverlay", draw)
```

---

### Clip Rectangles

Clip rects limit drawing to a specific screen region. Anything drawn outside the rect is clipped.

```lua
-- Push a clip rect — drawing is confined to this screen region
dl:PushClipRect(ImVec2(50, 50), ImVec2(400, 300))
-- Optional third arg: if true, intersects with the current clip rect instead of replacing it
dl:PushClipRect(ImVec2(50, 50), ImVec2(400, 300), true)

-- Draw stuff here — all clipped to the region above
dl:AddLine(ImVec2(0, 0), ImVec2(500, 500), 0xFFFFFFFF)

-- Pop to restore the previous clip rect
dl:PopClipRect()

-- Or push full screen (no clipping at all):
dl:PushClipRectFullScreen()
dl:PopClipRect()

-- Read current clip rect boundaries:
local clip_min = dl:GetClipRectMin()   -- returns ImVec2
local clip_max = dl:GetClipRectMax()   -- returns ImVec2
```

---

### Path API (Stateful Drawing)

The Path API lets you build a shape step-by-step and then stroke or fill it all at once. Useful for complex shapes that would be awkward to build as point tables.

```lua
-- Clear any pending path (optional safety call before starting):
dl:PathClear()

-- Add points to the path:
dl:PathLineTo(ImVec2(100, 200))
dl:PathLineTo(ImVec2(200, 100))
dl:PathLineTo(ImVec2(300, 200))

-- Finish: stroke the path as an outline
-- PathStroke(color, flags?, thickness?)
-- flags: 0 = open, 1 = closed loop
dl:PathStroke(0xFFFFFFFF, 1, 2.0)   -- closed white outline, 2px

-- OR finish: fill the path as a solid shape (convex shapes only)
-- dl:PathFillConvex(0x800000FF)

-- -----------------------------------------------------------------------

-- Arc path (builds a circular arc from a_min to a_max in radians):
dl:PathArcTo(ImVec2(300, 300), 80, 0, math.pi, 32)   -- half circle
dl:PathStroke(0xFF00FFFF, 0, 2.0)

-- Fast arc using 12-step approximation (steps 0-12 = full circle):
dl:PathArcToFast(ImVec2(300, 300), 80, 3, 9)   -- bottom half
dl:PathStroke(0xFF00FFFF, 0, 2.0)

-- Bezier path segments:
dl:PathLineTo(ImVec2(100, 200))                              -- move to start
dl:PathBezierCubicCurveTo(ImVec2(150,100), ImVec2(250,300), ImVec2(300,200))
dl:PathStroke(0xFFFFFFFF, 0, 1.5)

-- Rounded rectangle path:
dl:PathRect(ImVec2(100, 100), ImVec2(300, 200), 12.0)       -- 12px corner radius
dl:PathStroke(0xFFFFFFFF, 1, 2.0)                            -- closed outline
-- or: dl:PathFillConvex(0x8000FF00)                         -- filled
```

---

### Channel Splitting (Advanced)

Channels let you draw on multiple "layers" within a single draw list and then merge them. Useful when you need to draw something on top of things that are drawn later in the same callback (e.g., draw a highlight behind text that hasn't been drawn yet).

```lua
-- Split into N channels. Channel 0 is the background.
dl:ChannelsSplit(2)

-- Draw into channel 1 (top):
dl:ChannelsSetCurrent(1)
dl:AddRectFilled(ImVec2(100, 100), ImVec2(300, 200), 0xFFFFFFFF)

-- Draw into channel 0 (behind channel 1):
dl:ChannelsSetCurrent(0)
dl:AddRectFilled(ImVec2(90, 90), ImVec2(310, 210), 0xFF000000)

-- Merge all channels back together:
dl:ChannelsMerge()
```

---

### Practical Example: HUD Overlay

A complete example of a permanent HUD overlay that draws HP/Mana bars and target info directly on screen, with no visible window chrome.

```lua
local mq    = require('mq')
local ImGui = require('ImGui')

-- Screen position for our HUD (top-left corner)
local HUD_X, HUD_Y = 20, 200
local BAR_W, BAR_H = 160, 14

-- Draws a labeled health/resource bar using raw draw-list primitives.
local function draw_bar(dl, x, y, label, current, maximum, fill_color)
    if maximum <= 0 then return end

    local pct   = math.max(0, math.min(1, current / maximum))
    local x2    = x + BAR_W
    local y2    = y + BAR_H
    local fill_x = x + math.floor(BAR_W * pct)

    -- Background (dark grey)
    dl:AddRectFilled(ImVec2(x, y), ImVec2(x2, y2), 0xBB333333, 2.0)
    -- Filled portion
    if fill_x > x then
        dl:AddRectFilled(ImVec2(x, y), ImVec2(fill_x, y2), fill_color, 2.0)
    end
    -- Border
    dl:AddRect(ImVec2(x, y), ImVec2(x2, y2), 0xFFAAAAAA, 2.0)
    -- Label text
    dl:AddText(ImVec2(x + 4, y + 1), 0xFFFFFFFF, string.format("%s %d/%d", label, current, maximum))
end

local function draw_hud()
    local dl = ImGui.GetForegroundDrawList()
    local me = mq.TLO.Me

    -- Draw HP and Mana bars
    draw_bar(dl, HUD_X, HUD_Y,      "HP",   me.CurrentHPs(), me.MaxHPs(),   0xFF2244CC)
    draw_bar(dl, HUD_X, HUD_Y + 18, "MP",   me.CurrentMana(), me.MaxMana(), 0xFFCC6622)
    draw_bar(dl, HUD_X, HUD_Y + 36, "END",  me.CurrentEndurance(), me.MaxEndurance(), 0xFF22CC44)

    -- Draw target name above the bars (if we have a target)
    local tgt = mq.TLO.Target
    if tgt() then
        dl:AddText(ImVec2(HUD_X, HUD_Y - 18), 0xFF00FFFF,
            string.format("Target: %s", tgt.CleanName() or "???"))
    end
end

-- Register draws the HUD every frame.
-- We never open a window — draw_hud only touches the draw list.
ImGui.Register("MyHUD", draw_hud)

-- Keep the script running.
local running = true
while running do
    mq.delay(1000)
end
```

---

### What is NOT Bound

These ImGui functions exist in C++ but are **not exposed** in MQ Lua:

- `AddEllipse` / `AddEllipseFilled` — not yet bound
- `PathFillConcave` — not yet bound
- `PathEllipticalArcTo` — not yet bound
- `Prim*` low-level vertex API (`PrimReserve`, `PrimWriteVtx`, etc.) — not bound

---

*This reference covers base MacroQuest Lua — no plugins required. For plugin-specific TLOs (MQ2Nav, MQ2Melee, etc.), consult the documentation for those individual plugins.*
