local mq    = require('mq')
local ImGui = require('ImGui')

-- ============================================================
-- Target bounding box using MQ2Camera built-in projection
-- ============================================================

-- World-space height of a humanoid target (EQ units)
local BOX_HEIGHT = 6.0
local BOX_WIDTH  = 1.5  -- half-width; controls aspect ratio of box

local COLOR_NPC     = 0xFF3344CC  -- red-ish  (ABGR)
local COLOR_PC      = 0xFF33CC44  -- green-ish
local COLOR_DEFAULT = 0xFFCCCCCC  -- grey

local function targetColor(target)
    local t = target.Type()
    if t == 'NPC' then return COLOR_NPC end
    if t == 'PC'  then return COLOR_PC  end
    return COLOR_DEFAULT
end

--- Use Camera.ProjectX/Y/Visible to convert a world point to screen pixels.
---@param x number  world X
---@param y number  world Y
---@param z number  world Z
---@return number|nil sx, number|nil sy, boolean visible
local function project(x, y, z)
    local cam = mq.TLO.Camera
    local key = string.format('%.4f,%.4f,%.4f', x, y, z)
    local sx  = cam.ProjectX(key)()
    local sy  = cam.ProjectY(key)()
    local vis = cam.ProjectVisible(key)()
    if not sx or sx == -1 then return nil, nil, false end
    local screenW = cam.ScreenW()
    return screenW - sx, sy, vis == true
end

-- ============================================================
-- ImGui render callback — runs every frame
-- ============================================================
ImGui.Register('SimpleTarget', function()
    local cam = mq.TLO.Camera
    if not cam or not cam() then return end

    local target = mq.TLO.Target
    if not target() then return end

    local tx, ty, tz = target.X(), target.Y(), target.Z()
    if not tx then return end

    local bsx, bsy, bvis = project(tx, ty, tz)               -- feet
    local tsx, tsy        = project(tx, ty, tz + BOX_HEIGHT)  -- head

    -- Skip if feet are not visible (behind or off-screen)
    if not bvis or not bsx or not tsx then return end

    -- Derive screen-space box from projected foot/head positions
    local sh   = math.abs(tsy - bsy)
    local sw   = sh * (BOX_WIDTH / (BOX_HEIGHT / 2))
    local cx2  = (bsx + tsx) / 2
    local minX = cx2 - sw / 2
    local maxX = cx2 + sw / 2
    local minY = math.min(bsy, tsy)
    local maxY = math.max(bsy, tsy)

    local col = targetColor(target)
    local dl  = ImGui.GetForegroundDrawList()

    -- Bounding box
    dl:AddRect(ImVec2(minX, minY), ImVec2(maxX, maxY), col, 0, 0, 2)

    -- Name + HP label above box
    local name  = target.CleanName() or target.Name() or '???'
    local hp    = target.PctHPs()
    local label = hp and string.format('%s  %d%%', name, hp) or name
    dl:AddText(ImVec2(minX, minY - 14), col, label)
end)

-- ============================================================
-- Keep the script alive
-- ============================================================
while true do
    mq.doevents()
    mq.delay(50)
end
