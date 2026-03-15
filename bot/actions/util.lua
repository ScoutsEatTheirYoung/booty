local mq = require('mq')

local utilActs = {}

function utilActs.getPcTarget(pcName)
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return nil end
    return pc.TargetOfTarget
end

-- Resolves target specifiers to a flat list of { spawn, label } pairs.
-- Spawn TLO refs are stored directly since the list is rebuilt every tick.
-- IDs are used only for deduplication.
function utilActs.resolveTargets(targetList)
    local list = {}
    local seen = {}

    local function add(spawn, label)
        if not spawn then return end
        local id = spawn.ID()
        if not id or id <= 0 or seen[id] then return end
        seen[id] = true
        table.insert(list, { spawn = spawn, label = label })
    end

    for _, t in ipairs(targetList) do
        if t == "self" then
            add(mq.TLO.Me, "self")

        elseif t == "pet" then
            add(mq.TLO.Me.Pet, "my pet")

        elseif t == "group" then
            -- Group members + their pets
            -- Group.Members() returns count of OTHER members (excludes self)
            -- Group.Member(i).Spawn = their spawn, Group.Member(i).Pet = their pet spawn
            local count = mq.TLO.Group.Members() or 0
            for i = 1, count do
                local m = mq.TLO.Group.Member(i)
                if m and m.Name() then
                    add(m.Spawn,  m.Name())
                    add(m.Pet,    m.Name() .. "'s pet")
                end
            end

        else
            -- Named PC
            add(mq.TLO.Spawn('pc =' .. t), t)
        end
    end

    -- sort the list so its always in the same order (by label)
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

function utilActs.acquireTargetSpawn(spawn)
    if not spawn or not spawn() then return false end
    local spawnId = spawn.ID()
    mq.cmd('/target id ' .. spawnId)
    return true
end

return utilActs