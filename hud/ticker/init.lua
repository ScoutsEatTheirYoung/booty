local mq = require('mq')
local ImGui = require('ImGui')

-- 1. Style Registry
local Styles = {
    smart_enemy = function(draw_list, x, y, blip, angle, distance)
        draw_list:AddRectFilled(ImVec2(x - 4, y + 10), ImVec2(x + 4, y + 20), 0xFF0000FF)
        
        -- Center Cone (30 degrees total)
        if math.abs(angle) <= 15  and distance < 100 then
            local text = string.format("%s (%.0fft)", blip.label or "Unknown", distance)
            text_loc = ImVec2(x - 15, y + 25)
            shadow_loc = text_loc + ImVec2(1, 1)
            draw_list:AddText(shadow_loc, 0xFF000000, text)
            shadow_loc = text_loc + ImVec2(-1, 1)
            draw_list:AddText(shadow_loc, 0xFF000000, text)
            draw_list:AddText(text_loc, 0xFFFFFFFF, text)
            draw_list:AddRect(ImVec2(x - 4, y + 10), ImVec2(x + 4, y + 20), 0xFFFFFFFF)
        end
    end,

    target = function(draw_list, x, y, blip, angle, distance)
        draw_list:AddTriangleFilled(
            ImVec2(x, y + 30), 
            ImVec2(x - 8, y + 45), 
            ImVec2(x + 8, y + 45), 
            0xFF00FF00
        )
        if blip.label then
            draw_list:AddText(ImVec2(x - 10, y + 48), 0xFFFFFFFF, tostring(blip.label))
        end
    end,

    text_only = function(draw_list, x, y, blip, angle, distance)
        if blip.label then
            draw_list:AddText(ImVec2(x - 5, y + 8), 0xFFDDDDDD, tostring(blip.label))
        end
    end
}

-- 2. Ticker Class
local Ticker = {}
Ticker.__index = Ticker

function Ticker.new(width, yOffset, fov)
    local self = setmetatable({}, Ticker)
    self.Width = width or 500
    self.Y = yOffset or 40
    self.FOV = fov or 120
    self.blips = {}
    return self
end

function Ticker:clear()
    self.blips = {}
end

function Ticker:add(x, y, style_key, label)
    table.insert(self.blips, {x = x, y = y, style = style_key, label = label})
end

local function getRelativeAngle(fromX, fromY, toX, toY, heading)
    -- east is negative, west is positive, north is 0/360, south is 180
    local dx = fromX - toX
    local dy = toY - fromY
    local target_heading = math.atan2(dx, dy) * (180 / math.pi)
    target_heading = (target_heading + 360) % 360 
    local rel_angle = target_heading - heading 
    
    if rel_angle > 180 then rel_angle = rel_angle - 360 end
    if rel_angle < -180 then rel_angle = rel_angle + 360 end
    return rel_angle
end

function Ticker:draw(me, draw_list)
    local viewport = ImGui.GetMainViewport()
    local centerX = viewport.Size.x / 2
    local barHalf = self.Width / 2
    local fovHalf = self.FOV / 2

    local p_min = ImVec2(centerX - barHalf, self.Y)
    local p_max = ImVec2(centerX + barHalf, self.Y + 30)
    draw_list:AddRectFilled(p_min, p_max, 0x88000000)
    draw_list:AddRect(p_min, p_max, 0xFF888888)
    draw_list:AddLine(ImVec2(centerX, self.Y), ImVec2(centerX, self.Y + 30), 0xFFFFFFFF, 2.0)

    for _, blip in ipairs(self.blips) do
        local dx = blip.x - me.X()
        local dy = blip.y - me.Y()
        local distance = math.sqrt(dx*dx + dy*dy)
        local angle = getRelativeAngle(me.X(), me.Y(), blip.x, blip.y, me.Heading.Degrees())
        
        if math.abs(angle) <= fovHalf then
            local pixel_offset = (angle / fovHalf) * barHalf
            local posX = centerX + pixel_offset
            
            local drawFunc = Styles[blip.style]
            if drawFunc then
                drawFunc(draw_list, posX, self.Y, blip, angle, distance)
            end
        end
    end
end

-- 3. Export the class
return Ticker