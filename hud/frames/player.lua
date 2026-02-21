local mq = require('mq')
local ImGui = require('ImGui')
local config = require('booty.config')

local PlayerFrame = {}

-- This is a very basic player frame that shows HP and Endurance as progress bars.
function PlayerFrame.draw(me)
    local cfg = config.get().hud.player_frame
    local posX, posY = cfg.x, cfg.y
    local width, height = cfg.width, cfg.height

    local currentHP = me.CurrentHPs() or 0
    local maxHP = me.MaxHPs() or 1
    local pctHP = currentHP / maxHP

    ImGui.SetNextWindowPos(ImVec2(posX, posY), ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(ImVec2(width + 20, height * 3))
    
    local flags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.AlwaysAutoResize)
    
    if ImGui.Begin("PlayerStatus", nil, flags) then
        -- HP Bar
        ImGui.Text(string.format("HP: %d / %d", currentHP, maxHP))
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0xFF00FF00) -- Green
        ImGui.ProgressBar(pctHP, ImVec2(width, height), "")
        ImGui.PopStyleColor()

        -- Endurance Bar
        local pctEnd = (me.PctEndurance() or 0) / 100
        ImGui.Text("Endurance")
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 0xFF00FFFF) -- Yellow
        ImGui.ProgressBar(pctEnd, ImVec2(width, height), "")
        ImGui.PopStyleColor()
    end
    ImGui.End()
end

return PlayerFrame