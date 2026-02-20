local mq = require('mq')
local ImGui = require('ImGui')

-- Import the Ticker class from the subdirectory
-- Lua automatically looks for /init.lua when you require a folder path
local Ticker = require('booty.hud.ticker')

local openGUI = true
local myTicker = Ticker.new(500, 40, 120)

local function HUD_Loop()
    if not openGUI then return end

    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(10, 10))
    local flags = bit32.bor(ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.NoBackground, ImGuiWindowFlags.NoInputs)

    if ImGui.Begin("BootyHUD", true, flags) then
        local draw_list = ImGui.GetForegroundDrawList()
        local me = mq.TLO.Me

        if me() then
            myTicker:clear()

            -- Gather Target Data
            local target = mq.TLO.Target
            if target() then
                myTicker:add(target.X(), target.Y(), "target", string.format("%dft", target.Distance()))
            end

            -- Gather Spawn Data
            local mobs = mq.getFilteredSpawns(function(s) 
                return s.Type() == 'NPC' and s.Distance3D() < 200 
            end)

            for _, mob in ipairs(mobs) do
                if not target() or mob.ID() ~= target.ID() then
                    myTicker:add(mob.X(), mob.Y(), "smart_enemy", mob.CleanName())
                end
            end

            -- Add Static Compass Data (Example)
            -- If you calculate N/S/E/W absolute coordinates relative to player, push them here.

            -- Render the frame
            myTicker:draw(me, draw_list)
        end
    end
    ImGui.End()
end

ImGui.Register('BootyHUD', HUD_Loop)

while openGUI do 
    mq.delay(50) 
end