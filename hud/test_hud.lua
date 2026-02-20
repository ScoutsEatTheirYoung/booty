local mq = require('mq')
local ImGui = require('ImGui')

local ticker = require('booty.hud.ticker')

local tickerHud = ticker.new(500, 40, 120)

ImGui.Register('TickerHUD', tickerHud.draw)

while openGUI do mq.delay(50) end