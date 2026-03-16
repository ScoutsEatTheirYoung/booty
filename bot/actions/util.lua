local mq = require('mq')

local util = {}

-- ============================================================
-- Pure checks  (get* / find*)
-- ============================================================

--- Return the spawn that pcName is currently targeting, or nil.
---@param pcName string
---@return spawn|nil
function util.getPcTarget(pcName)
    local pc = mq.TLO.Spawn('pc =' .. pcName)
    if not pc() then return nil end
    local t = pc.TargetOfTarget --[[@as spawn]]
    if not t or not t() then return nil end
    return t
end

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

-- ============================================================
-- Actors  (target*)
-- ============================================================

--- Target spawn if not already targeted.
---@param spawn spawn
---@return boolean, string
function util.targetSpawn(spawn)
    if not spawn or not spawn() then return false, 'Invalid spawn' end
    local id = spawn.ID()
    if mq.TLO.Target.ID() == id then return false, 'Already targeted' end
    mq.cmdf('/squelch /tar id %d', id)
    return true, string.format('Targeting %s', spawn.Name() or tostring(id))
end

--- Target spawn by ID if not already targeted.
---@param id integer
---@return boolean, string
function util.targetByID(id)
    if not id or id <= 0 then return false, 'Invalid spawn ID' end
    if mq.TLO.Target.ID() == id then return false, 'Already targeted' end
    mq.cmdf('/squelch /tar id %d', id)
    return true, string.format('Targeting spawn ID %d', id)
end

return util
