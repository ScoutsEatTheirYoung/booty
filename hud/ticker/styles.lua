local ImGui = require('ImGui')

-- ==============================================================================
-- THE STYLE CONTRACT (FRAMEWORK)
-- Every style function MUST accept these exact 6 arguments, in this order:
--
-- 1. draw_list : The ImGui foreground draw list.
-- 2. x         : The exact horizontal center pixel for this specific blip.
-- 3. ticker    : The parent Ticker object (access ticker.Y, ticker.Height, etc).
-- 4. label     : The string name (can be nil).
-- 5. angle     : Relative angle in degrees (for cone math).
-- 6. distance  : Distance in in-game units (for scaling/logic).
-- ==============================================================================

local Styles = {}

-- Example 1: Painting BELOW the ticker (Target Triangle)
Styles.Target = function(draw_list, x, ticker, label, angle, distance)
    local bottomEdge = ticker.Y + ticker.Height
    
    -- Triangle touching the bottom edge and pointing UP
    draw_list:AddTriangleFilled(
        ImVec2(x, bottomEdge),           -- Top tip
        ImVec2(x - 8, bottomEdge + 15),  -- Bottom left
        ImVec2(x + 8, bottomEdge + 15),  -- Bottom right
        0xFF00FF00                       -- Green
    )
    
    if label then
        local textX = x - 10
        local textY = bottomEdge + 18
        draw_list:AddText(ImVec2(textX - 1, textY - 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX + 1, textY - 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX - 1, textY + 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX + 1, textY + 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX, textY), 0xFFFFFFFF, label)
    end
end

-- Example 2: Painting INSIDE the ticker (Compass N/S/E/W)
Styles.Compass = function(draw_list, x, ticker, label, angle, distance)
    -- Vertically center the text inside the bar itself
    local centerY = ticker.Y + (ticker.Height / 2) - 7 -- subtract roughly half font height
    local textX = x - 5
    
    if label then
        draw_list:AddText(ImVec2(textX - 1, centerY - 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX + 1, centerY - 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX - 1, centerY + 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX + 1, centerY + 1), 0xFF000000, label)
        draw_list:AddText(ImVec2(textX, centerY), 0xFFDDDDDD, label)
    end
end

-- Example 3: Painting ABOVE the ticker (Smart Enemy)
Styles.NPC = function(draw_list, x, ticker, label, angle, distance)
    local topEdge = ticker.Y
    
    -- Draw a red box sitting right on top of the bar
    draw_list:AddRectFilled(
        ImVec2(x - 4, topEdge - 10), 
        ImVec2(x + 4, topEdge), 
        0xFF0000FF
    )
    
    -- Cone logic: Pop white text above the box if looking at them
    if math.abs(angle) <= 15 and distance < 50 then
        local text = string.format("%s (%.0fft)", label or "NPC", distance)
        draw_list:AddText(ImVec2(x - 14, topEdge - 24), 0xFF000000, text)
        draw_list:AddText(ImVec2(x - 16, topEdge - 26), 0xFF000000, text)
        draw_list:AddText(ImVec2(x - 14, topEdge - 26), 0xFF000000, text)
        draw_list:AddText(ImVec2(x - 16, topEdge - 24), 0xFF000000, text)
        draw_list:AddText(ImVec2(x - 15, topEdge - 25), 0xFFFFFFFF, text)
    end
end

return Styles