local mq = require('mq')
local ImGui = require('ImGui')
local Ticker = require('booty.hud.ticker')
local TickerStyles = require('booty.hud.ticker.styles')

local openGUI = true
local myTicker = Ticker.new(500, 40, 120, 30)

-- =========================================================
-- THE RENDERER (Fast - 60+ FPS)
-- =========================================================
local function HUD_Loop()
    if not openGUI then return end

    ImGui.SetNextWindowPos(ImVec2(0, 0))
    ImGui.SetNextWindowSize(ImVec2(10, 10))
    local flags = bit32.bor(ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.NoBackground, ImGuiWindowFlags.NoInputs)

    if ImGui.Begin("BootyHUD", true, flags) then
        local me = mq.TLO.Me
        if me() then
            myTicker:draw(me, ImGui.GetForegroundDrawList())
        end
    end
    ImGui.End()
end

ImGui.Register('BootyHUD', HUD_Loop)

-- =========================================================
-- THE GATHERER (Slow - 10 FPS)
-- =========================================================
while openGUI do 
    local me = mq.TLO.Me
    if me() then
        myTicker:clear()

        local target = mq.TLO.Target
        if target() then
            myTicker:add(target.X(), target.Y(), string.format("%dft", target.Distance()), TickerStyles.Target)
        end

        local mobs = mq.getFilteredSpawns(function(s) 
            return s.Type() == 'NPC' and s.Distance3D() < 200 
        end)

        for _, mob in ipairs(mobs) do
            if not target() or mob.ID() ~= target.ID() then
                myTicker:add(mob.X(), mob.Y(), mob.CleanName(), TickerStyles.NPC)
            end
        end
    end
    
    mq.delay(100) 
end