local mq = require('mq')
local ImGui = require('ImGui')


local gui = {}
-- 1. STATE (Variables that persist)
local state = {
    open = true,
    click_count = 0,
    last_action = "None"
}

-- 2. THE GUI CALLBACK
function gui.draw_gui()
    local function draw_gui()
        if not state.open then return end

        -- Create the window
        local open, show = ImGui.Begin("My Button Tester", state.open)
        if not open then state.open = false end -- Handle the 'X' close button

        if show then
            -- DISPLAY DATA
            ImGui.Text("Clicks: " .. state.click_count)
            ImGui.Text("Last Action: " .. state.last_action)
            
            ImGui.Separator()

            -- THE BUTTON LOGIC
            -- ImGui.Button returns TRUE only on the exact frame you release the mouse.
            if ImGui.Button("Do The Thing") then
                
                -- === THIS IS WHERE THE ACTION HAPPENS ===
                state.click_count = state.click_count + 1
                state.last_action = "Clicked at " .. os.time()
                
                print("\at[MyScript] \agButton was clicked!") -- Prints to EQ Chat
                -- You could call a function here: sell_all_trash()
                -- =======================================
                
            end
        end
        
        ImGui.End()
    end

    -- 3. REGISTER
    mq.imgui.init('ButtonTester', draw_gui)

    -- 4. LOOP
    print("\awScript Started. Window should appear.")
    while state.open do
        mq.delay(100) -- Keep script alive
    end
    print("\awScript Ending.")
end

return gui