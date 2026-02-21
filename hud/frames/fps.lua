local ImGui = require('ImGui')
local config = require('booty.config')

local FPSFrame = {}

-- Pre-allocate the history table
local HISTORY_SIZE = config.get().hud.fps.history_size
local fps_history = {}
for i = 1, HISTORY_SIZE do
    fps_history[i] = 0
end

-- Establish the state tracker outside the loop
local max_fps_seen = 0.0

function FPSFrame.draw()
    -- Get ImGui's internal framerate calculation
    local current_fps = ImGui.GetIO().Framerate

    if current_fps > max_fps_seen then
        max_fps_seen = current_fps
    end


    -- 2. Shift all values left by 1 (Zero garbage collection)
    for i = 1, HISTORY_SIZE - 1 do
        fps_history[i] = fps_history[i + 1]
    end
    -- Append the newest frame to the end
    fps_history[HISTORY_SIZE] = current_fps

    -- 3. Render the Window
    -- We use AlwaysAutoResize so the window tightly hugs the graph
    local flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.AlwaysAutoResize)
    
    if ImGui.Begin("FPS Tracker", nil, flags) then
        local overlay_text = string.format("FPS: %.1f", current_fps)
        
        -- PlotLines signature: 
        -- label, values_table, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size
        ImGui.PlotLines(
            "##fpsgraph",          -- Hidden label
            fps_history,           -- The pre-allocated table
            HISTORY_SIZE,          -- How many points to draw
            0,                     -- Offset (we manually shifted, so 0)
            overlay_text,          -- Text to display inside the graph
            0.0,                   -- Y-Axis Minimum
            max_fps_seen,                 -- Y-Axis Maximum (Set to your monitor's refresh rate)
            ImVec2(200, 50)        -- Dimensions of the graph itself
        )
    end
    ImGui.End()
end

return FPSFrame