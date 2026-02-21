local ImGui = require('ImGui')

local Ticker = {}
Ticker.__index = Ticker

function Ticker.new(width, yOffset, fov, height)
    local self = setmetatable({}, Ticker)
    self.Width = width or 500
    self.Y = yOffset or 40
    self.FOV = fov or 120
    self.Height = height or 30
    self.blips = {}
    return self
end

function Ticker:clear()
    self.blips = {}
end

function Ticker:add(x, y, label, renderCallback)
    table.insert(self.blips, {
        x = x, 
        y = y, 
        label = label, 
        render = renderCallback
    })
end

local function getRelativeAngle(fromX, fromY, toX, toY, heading)
    local dx = fromX - toX -- east is negative, west is positive
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
    local p_max = ImVec2(centerX + barHalf, self.Y + self.Height)
    draw_list:AddRectFilled(p_min, p_max, 0x88000000)
    draw_list:AddRect(p_min, p_max, 0xFF888888)
    draw_list:AddLine(ImVec2(centerX, self.Y), ImVec2(centerX, self.Y + self.Height), 0xFFFFFFFF, 2.0)

    for _, blip in ipairs(self.blips) do
        local dx = blip.x - me.X()
        local dy = blip.y - me.Y()
        local distance = math.sqrt(dx*dx + dy*dy)
        local angle = getRelativeAngle(me.X(), me.Y(), blip.x, blip.y, me.Heading.Degrees())
        
        local posX = centerX
        if math.abs(angle) <= fovHalf then
            local pixel_offset = (angle / fovHalf) * barHalf
            posX = centerX + pixel_offset
        elseif angle > fovHalf or angle < -fovHalf then
            posX = centerX + (angle > 0 and barHalf or -barHalf)
        end
            
        if type(blip.render) == "function" then
            blip.render(draw_list, posX, self, blip.label, angle, distance)
        end
    end
end

return Ticker