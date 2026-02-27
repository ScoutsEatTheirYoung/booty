-- ============================================================================
-- lua/booty/search/item/init.lua
--
-- Opens a window that lists every item in your inventory.
-- Each row shows the item's icon sprite, name, and where it lives.
--
-- How to run:  /lua run booty/search/item
-- ============================================================================

local mq    = require('mq')    -- MacroQuest Lua API (TLOs, commands, delays)
local ImGui = require('ImGui') -- Dear ImGui overlay UI library

-- ============================================================================
-- EQUIPMENT SLOT NAME TABLE
-- EverQuest has 23 "worn" slots numbered 0-22.
-- We use this lookup so we can print "Head" instead of "Slot 2".
-- ============================================================================
local SLOT_NAMES = {
    [0]  = "Charm",
    [1]  = "Left Ear",
    [2]  = "Head",
    [3]  = "Face",
    [4]  = "Right Ear",
    [5]  = "Neck",
    [6]  = "Shoulder",
    [7]  = "Arms",
    [8]  = "Back",
    [9]  = "Left Wrist",
    [10] = "Right Wrist",
    [11] = "Range",
    [12] = "Hands",
    [13] = "Primary",
    [14] = "Secondary",
    [15] = "Left Finger",
    [16] = "Right Finger",
    [17] = "Chest",
    [18] = "Legs",
    [19] = "Feet",
    [20] = "Waist",
    [21] = "Power Source",
    [22] = "Ammo",
}

-- ============================================================================
-- ICON ANIMATION SETUP
--
-- All EQ item icons live inside one master animation called "A_DragItem".
-- It is a sprite sheet animation with one frame per dragitem.dds texture.
-- To show a specific item's icon:
--   1. Call drag_anim:SetTextureCell(icon_id) to select the right sprite.
--   2. Call ImGui.DrawTextureAnimation(drag_anim, width, height) to draw it.
--
-- We fetch this animation ONCE here. If it fails (nil), icons show as [?].
-- ============================================================================
local drag_anim = mq.FindTextureAnimation("A_DragItem")

-- ============================================================================
-- STATE
-- ImGui calls draw_window ~60 times per second. These variables persist
-- across every frame — they are NOT reset each time draw_window runs.
-- ============================================================================
local open      = true  -- Set to false to close the window and end the script.
local item_list = {}    -- Flat table of item records; rebuilt on each scan.

-- ============================================================================
-- HELPER: add_item
-- Takes a MacroQuest Item TLO and a location string, then appends a record
-- to item_list if the item actually exists.
-- ============================================================================
local function add_item(item_tlo, location)
    -- Calling item_tlo() returns true if the slot is occupied.
    -- An empty slot still gives back an item object, but item_tlo() == false.
    if not item_tlo() then return end

    table.insert(item_list, {
        name    = item_tlo.Name() or "Unknown",
        location = location,
        -- Store the raw icon ID (MQFloat, converted to int with math.floor).
        -- We use this in draw_window to call SetTextureCell before drawing.
        icon_id = math.floor(item_tlo.Icon() or 0),
    })
end

-- ============================================================================
-- SCAN INVENTORY
-- Iterates over worn slots and bag contents, filling item_list from scratch.
-- Call once at startup; the Refresh button calls it again on demand.
-- ============================================================================
local function scan_inventory()
    item_list = {}  -- Clear previous results before each scan.

    -- -----------------------------------------------------------------------
    -- PART 1 — Worn / Equipment Slots (indices 0 through 22)
    --
    -- mq.TLO.Me.Inventory(index) returns the item TLO for that slot.
    -- SLOT_NAMES[i] converts the index to a readable name like "Chest".
    -- -----------------------------------------------------------------------
    for slot_index = 0, 22 do
        local item      = mq.TLO.Me.Inventory(slot_index)
        local slot_name = SLOT_NAMES[slot_index] or ("Worn " .. slot_index)
        add_item(item, slot_name)
    end

    -- -----------------------------------------------------------------------
    -- PART 2 — Main Inventory Slots ("pack1" through "pack10")
    --
    -- Each pack slot can contain:
    --   a) A container (bag)  — we dig inside and list each bag slot item.
    --   b) A plain item       — we list it directly.
    --
    -- pack.Container() returns how many slots the bag has (0 if not a bag).
    -- pack.Item(n)     returns the item TLO for slot n inside the bag.
    -- -----------------------------------------------------------------------
    for bag_num = 1, 10 do
        local pack = mq.TLO.Me.Inventory("pack" .. bag_num)

        if pack() then
            local num_slots = pack.Container() or 0

            if num_slots > 0 then
                -- It is a bag — walk every slot inside it.
                for slot_num = 1, num_slots do
                    local item = pack.Item(slot_num)
                    local loc  = string.format("Bag %d, Slot %d", bag_num, slot_num)
                    add_item(item, loc)
                end
            else
                -- Plain item sitting directly in a pack slot (not a container).
                local loc = string.format("Inv Slot %d", bag_num)
                add_item(pack, loc)
            end
        end
    end
end

-- ============================================================================
-- DRAW WINDOW
-- Called automatically by ImGui every frame. Keep this fast — no file I/O,
-- no looping over spawns, just read item_list and draw.
-- ============================================================================
local function draw_window()
    if not open then return end  -- Already closed; nothing to draw.

    -- ImGui.Begin() creates the window frame and returns two values:
    --   is_open    : updated close-button state; false means user hit X
    --   should_draw: false when the window is collapsed (rolled up)
    local is_open, should_draw = ImGui.Begin("Inventory Search", open)

    if not is_open then
        open = false  -- Close button was clicked; signal the loop to exit.
    end

    if should_draw then
        -- Refresh button: rebuilds item_list from current inventory state.
        if ImGui.Button("Refresh") then
            scan_inventory()
        end

        ImGui.SameLine()  -- Place the next element on the same line.
        ImGui.Text(string.format("%d items", #item_list))
        ImGui.Separator()

        -- Table display flags (combined with bitwise OR):
        --   Borders  = draw grid lines between cells
        --   RowBg    = alternate row background colors (easier to scan)
        --   ScrollY  = enable vertical scrolling inside the table
        local tbl_flags = bit32.bor(
            ImGuiTableFlags.Borders,
            ImGuiTableFlags.RowBg,
            ImGuiTableFlags.ScrollY
        )

        -- BeginTable(id, column_count, flags, size)
        -- "##invtable" — the ## prefix means the id is hidden from display.
        -- ImVec2(0, 400) = auto width, fixed 400px height (enables scrolling).
        if ImGui.BeginTable("##invtable", 3, tbl_flags, ImVec2(0, 400)) then

            -- Freeze the header row so column names stay visible while scrolling.
            ImGui.TableSetupScrollFreeze(0, 1)

            -- Define columns:
            --   WidthFixed   = column is a set number of pixels wide
            --   WidthStretch = column fills whatever space is left over
            ImGui.TableSetupColumn("Icon",     ImGuiTableColumnFlags.WidthFixed,   44)
            ImGui.TableSetupColumn("Name",     ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableSetupColumn("Location", ImGuiTableColumnFlags.WidthFixed,   160)

            -- Render the header row with the column names defined above.
            ImGui.TableHeadersRow()

            -- One row per item in the list.
            for _, item in ipairs(item_list) do
                ImGui.TableNextRow()

                -- Column 0: item icon sprite
                ImGui.TableSetColumnIndex(0)
                if drag_anim then
                    -- SetTextureCell(icon_id) selects which sprite from A_DragItem
                    -- to display. Must be called right before DrawTextureAnimation.
                    drag_anim:SetTextureCell(item.icon_id)
                    ImGui.DrawTextureAnimation(drag_anim, 40, 40)
                else
                    ImGui.Text("[?]")  -- A_DragItem animation not found.
                end

                -- Column 1: item name
                ImGui.TableSetColumnIndex(1)
                ImGui.Text(item.name)

                -- Column 2: where the item is located
                ImGui.TableSetColumnIndex(2)
                ImGui.Text(item.location)
            end

            ImGui.EndTable()
        end
    end

    -- IMPORTANT: End() must always be called to match Begin(), even when
    -- should_draw is false (e.g. when the window is collapsed).
    ImGui.End()
end

-- ============================================================================
-- STARTUP
-- ============================================================================

-- Populate item_list right away so the window isn't blank on first open.
scan_inventory()

-- Register the draw callback with ImGui.
-- "ItemSearch" is the internal handle MQ uses to track this overlay.
-- draw_window will fire automatically every frame from this point on.
ImGui.Register("ItemSearch", draw_window)

-- ============================================================================
-- MAIN LOOP
-- The script must stay running for the ImGui callback to keep firing.
-- mq.delay(1000) yields to EQ for 1 second before resuming here.
-- Once the user closes the window (open = false), the loop exits and the
-- script ends cleanly.
-- ============================================================================
while open do
    mq.delay(1000)
end
