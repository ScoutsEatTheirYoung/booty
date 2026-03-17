local mq = require('mq')

local util = {}

--- Resolve target specifiers to a flat list of ResolvedTarget pairs.
--- Rebuilt fresh each tick — IDs used only for deduplication within this call.
---@param targetList TargetSpecifier[]
---@return ResolvedTarget[]
function util.resolveTargets(targetList)
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
            add(mq.TLO.Me, "self")
            add(mq.TLO.Me.Pet, "my pet")
            local count = mq.TLO.Group.Members() or 0
            for i = 1, count do
                local m = mq.TLO.Group.Member(i)
                if m and m.Name() then
                    add(m.Spawn, m.Name())
                    add(m.Pet,   m.Name() .. "'s pet")
                end
            end

        else
            add(mq.TLO.Spawn('pc =' .. t), t)
        end
    end

    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

return util
