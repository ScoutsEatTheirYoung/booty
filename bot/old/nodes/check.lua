local bt = require("bot.bt.engine")
local bb = require("bot.bt.blackboard")
local check = {}

function check.checkBBVariable(key, expectedValue)
    return function()
        local actualValue = bb.get(key)
        if actualValue == expectedValue then
            return bt.SUCCESS, string.format("BB[%s] is %s as expected", key, tostring(actualValue)), "checkBBVariable"
        end
        return bt.FAILURE, string.format("BB[%s] is %s but expected %s", key, tostring(actualValue), tostring(expectedValue)), "checkBBVariable"
    end
end

return check