local Leaf  = require('booty.bot.bt.core.leaf')
local State = require('booty.bot.bt.core.state')

---@class Sensor : Leaf
local Sensor = {}
setmetatable(Sensor, { __index = Leaf })
Sensor.__index = Sensor

---@param name string
---@param fn fun(self: Sensor, context: table): integer, string?
---@return Sensor
function Sensor:new(name, fn)
    local function guarded(self, context)
        local state, msg = fn(self, context)
        if state == State.RUNNING then
            error(string.format(
                "[Sensor] '%s' returned RUNNING — Sensors must be instant checks only, not stateful actions.",
                name), 2)
        end
        return state, msg
    end
    return Leaf.new(self, name, guarded) --[[@as Sensor]]
end

return Sensor
