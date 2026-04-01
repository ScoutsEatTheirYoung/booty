local mq = require('mq')
local BB = { 
    state = {},
    cache = {}
}

local sensors = {
    pctMana = function() return mq.TLO.Me.PctMana() or 0 end,
    isCasting = function() return mq.TLO.Me.Casting.ID() ~= nil end,
}

function BB.NewTick() BB.cache = {} end

function BB.get(key)
    if BB.state[key] ~= nil then return BB.state[key] end
    if BB.cache[key] == nil and sensors[key] then
        BB.cache[key] = sensors[key]()
    end
    return BB.cache[key]
end

function BB.set(k, v) BB.state[k] = v end

return BB