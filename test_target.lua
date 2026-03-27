local mq            = require('mq')
local targetActions = require('booty.bot.bricks.targetActions')

local function check(label, c, r)
    print(string.format('[%s] c=%s  r=%s', label, tostring(c), tostring(r)))
end

-- 1. Target self by ID
local selfID = mq.TLO.Me.ID()
print('Self ID: ' .. tostring(selfID))
check('targetByID(self)', targetActions.targetByID(selfID))
mq.delay(500)
check('targetByID(self again)', targetActions.targetByID(selfID))

-- 2. Bad ID
check('targetByID(0)', targetActions.targetByID(0))
check('targetByID(nil)', targetActions.targetByID(nil --[[@as integer]]))

-- 3. targetSpawn(nil)
check('targetSpawn(nil)', targetActions.targetSpawn(nil))

-- 4. Current target (if you have something targeted before running)
local t = mq.TLO.Target
if t() then
    local id = t.ID()
    print('Pre-existing target: ' .. tostring(t.Name()) .. ' id=' .. tostring(id))
    check('targetByID(existing)', targetActions.targetByID(id))
    mq.delay(500)
    check('targetByID(existing again)', targetActions.targetByID(id))
else
    print('No pre-existing target — target something before running for test 4')
end

print('Done.')
