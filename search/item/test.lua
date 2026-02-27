-- ============================================================================
-- lua/booty/search/item/test.lua
--
-- Icon format tester. Run this to figure out the right texture animation
-- name format before using it in the real inventory window.
--
-- How to run:  /lua run booty/search/item/test
--
-- What it does:
--   1. Finds the first real item it can in your inventory
--   2. Prints its icon ID to chat
--   3. Tries every plausible animation name format, prints FOUND/NIL for each
--   4. Opens a small ImGui window showing a box for each format so you can
--      see which ones actually render a visible sprite
-- ============================================================================

local mq    = require('mq')
local ImGui = require('ImGui')

-- ============================================================================
-- STEP 1: Find any real item so we have a real icon ID to test with.
-- We check bag 1-10, slot 1 until we find something.
-- ============================================================================
local test_icon_id = nil
local test_item_name = "none"

for bag_num = 1, 10 do
    local pack = mq.TLO.Me.Inventory("pack" .. bag_num)
    if pack() and pack.Container() and pack.Container() > 0 then
        for slot_num = 1, pack.Container() do
            local item = pack.Item(slot_num)
            if item() then
                test_icon_id  = item.Icon()
                test_item_name = item.Name() or "?"
                break
            end
        end
    end
    if test_icon_id then break end
end

-- Fallback: try worn slots
if not test_icon_id then
    for i = 0, 22 do
        local item = mq.TLO.Me.Inventory(i)
        if item() then
            test_icon_id  = item.Icon()
            test_item_name = item.Name() or "?"
            break
        end
    end
end

if not test_icon_id then
    print("\ar[IconTest]\ax No items found in inventory to test with.")
    return
end

-- Force to integer (MQFloat can come back as 500.0 instead of 500)
local icon_int = math.floor(test_icon_id)

print(string.format("\ag[IconTest]\ax Testing item: \at%s\ax  (Icon ID: \aw%d\ax)", test_item_name, icon_int))

-- ============================================================================
-- STEP 2: Build a list of every name format to try.
-- We store { label, name_string, result } for each attempt.
-- ============================================================================
local formats = {
    { label = 'Item_%04d  (zero-pad 4)',   name = string.format("Item_%04d",  icon_int) },
    { label = 'Item_%d    (no pad)',        name = string.format("Item_%d",    icon_int) },
    { label = 'item%04d   (lower+nounder)', name = string.format("item%04d",  icon_int) },
    { label = '%04d       (just number)',   name = string.format("%04d",       icon_int) },
    { label = '%d         (plain number)',  name = string.format("%d",         icon_int) },
    -- EQ spells use "A_SpellGems" — this tests that FindTextureAnimation works at all
    { label = 'A_SpellGems (known spell)',  name = "A_SpellGems" },
}

-- Try each format, store the CTextureAnimation (or nil)
for _, fmt in ipairs(formats) do
    fmt.ta = mq.FindTextureAnimation(fmt.name)
    local result = fmt.ta and "\agFOUND\ax" or "\arNIL\ax"
    print(string.format("  [IconTest] %-30s -> %s  (%s)", fmt.label, result, fmt.name))
end

-- ============================================================================
-- STEP 3: Show an ImGui window with one box per format.
-- A visible icon sprite confirms the format is correct.
-- ============================================================================
local open = true

local function draw_test()
    if not open then return end

    local is_open, should_draw = ImGui.Begin("Icon Format Test", open)
    if not is_open then open = false end

    if should_draw then
        ImGui.Text(string.format("Item: %s  (Icon ID: %d)", test_item_name, icon_int))
        ImGui.Separator()

        for _, fmt in ipairs(formats) do
            -- Draw a 40x40 box showing the icon (or a red X if nil)
            ImGui.BeginGroup()

            if fmt.ta then
                ImGui.DrawTextureAnimation(fmt.ta, 40, 40)
            else
                -- Red placeholder so you can see the slot exists
                ImGui.PushStyleColor(ImGuiCol.Button, 0xFF0000AA)
                ImGui.Button("nil", ImVec2(40, 40))
                ImGui.PopStyleColor()
            end

            ImGui.SameLine()
            ImGui.Text(fmt.label .. "  [" .. fmt.name .. "]")

            ImGui.EndGroup()
        end
    end

    ImGui.End()
end

ImGui.Register("IconFormatTest", draw_test)

print("\ag[IconTest]\ax Window registered. Look for 'Icon Format Test' on screen.")
print("\ag[IconTest]\ax Also check chat above for FOUND/NIL results per format.")

while open do
    mq.delay(1000)
end
