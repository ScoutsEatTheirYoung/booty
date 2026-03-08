local mq = require('mq')
local imgui = require('ImGui')
local Filter = require('booty.filter')

-- Localize imgui calls used every frame
local imgui_Begin      = imgui.Begin
local imgui_End        = imgui.End
local imgui_BeginChild = imgui.BeginChild
local imgui_EndChild   = imgui.EndChild
local imgui_SameLine   = imgui.SameLine
local imgui_Selectable = imgui.Selectable
local imgui_Separator  = imgui.Separator
local imgui_Text       = imgui.Text

-- 1. State: Controls whether the window (and the script) stays alive
local state = {
    open = true,
    filters_available = {},
    selected_filter = nil,
    filter = nil
}

-- 2. Render Callback: This runs every single frame
local function draw_window()
    local open_state, should_draw = imgui_Begin("Booty Loot Filter", state.open)

    state.open = open_state

    if state.open and should_draw then
        -- --- LEFT PANE (Navigation / Filters) ---
        imgui_BeginChild("LeftPane", 150, 0, true)

        if imgui_Selectable("Create New") then
            -- Create New Logic
        end

        if #state.filters_available == 0 then
            imgui_Text("No filters found.")
        else
            for _, filter_name in ipairs(state.filters_available) do
                if imgui_Selectable(filter_name) then
                    state.selected_filter = filter_name
                    state.filter = Filter.load(filter_name)
                end
            end
        end
        imgui_EndChild()

        imgui_SameLine()

        -- --- RIGHT PANE (Item List / Details) ---
        imgui_BeginChild("RightPane", 0, 0, true)
            imgui_Text("MATCHING ITEMS")
            imgui_Separator()
            -- Your loop of items goes here
            imgui_Text("Jade Mace")
            imgui_Text("Exalted Shadow Knight Tome")
        imgui_EndChild()
    end

    imgui_End()
end

-- 3. Initialization
mq.imgui.init('BootyGUI', draw_window)

state.filters_available = Filter.getAllFilters()

-- 4. Main Loop
print("GUI started. Click the X to terminate the script.")
while state.open do
    mq.delay(10)
end

print("Window closed. Script exiting.")
