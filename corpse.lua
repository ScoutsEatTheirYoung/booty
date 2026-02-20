
local mq = require('mq')

local corpse = {}

function corpse.get_all(radius, zradius)
    local results = {}
    local r = radius or 30
    local z = zradius or 10

    local query = string.format('corpse radius %d zradius %d', r, z)
    local count = mq.TLO.SpawnCount(query)()

    for i = 1, count do
        local spawn = mq.TLO.NearestSpawn(i, query)
        if spawn() then
            table.insert(results, {
                id = spawn.ID(),
                name = spawn.Name(),
                clean_name = spawn.CleanName(),
                distance = spawn.Distance() or 0,
            })
        end
    end

    table.sort(results, function(a, b) return a.distance < b.distance end)

    return results
end

return corpse