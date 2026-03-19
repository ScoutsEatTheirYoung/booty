local mq            = require('mq')
local targetActions = require('booty.bot.bricks.targetActions')
local movementActions = require('booty.bot.bricks.movementActions')
local altabilityActions = require('booty.bot.bricks.altabilityActions')

local travel = {}

---A command to get all bots to the guild hall and then move to the in game porters
---and ported to the corredct location
---@param porterName string either druid, wizard, or name of the npc porter in guild hall
---@param location string name of the location to port to that is used by the porter
---@return boolean, string
function travel.ascendantGuildHallPort(porterName, location)
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        return true, 'Currently Porting'
    end

    if porterName == nil or location == nil then return false, 'Porter name and location required' end
    if porterName:lower() == 'druid' then
        porterName = 'Circlekeeper Aurin'
    elseif porterName:lower() == 'wizard' then
        porterName = 'Spirekeeper Aethen'
    elseif porterName:lower() == 'liminal' then
        porterName = 'Liminal'
    end

    if not mq.TLO.Zone.ShortName() == 'guildhall' then
        return altabilityActions.castAA('Marked Passage')
    end

    local porter = mq.TLO.Spawn('npc =' .. porterName)

    local c, r = movementActions.navToSpawn(porter, 50)
    if c then return c, r end

    c, r = targetActions.targetSpawn(porter)
    if c then return c, r end

    mq.cmdf('/say %s', location)
    return true, string.format('Teleporting to %s via %s', location, porter.Name())
end

return travel