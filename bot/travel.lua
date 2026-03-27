local mq            = require('mq')
local targetActions = require('booty.bot.bricks.targetActions')
local movementActions = require('booty.bot.bricks.movementActions')
local altabilityActions = require('booty.bot.bricks.altabilityActions')

local travel = {}

-- Phase tracking for ascendantGuildHallPort.
-- NONE:          idle, nothing in progress
-- TOGUILDHALL:   Marked Passage fired, zoning into guild hall
-- TODESTINATION: /say sent to porter, zoning to final destination
local PORT_PHASE = { NONE = 0, TOGUILDHALL = 1, TODESTINATION = 2 }
local portPhase = PORT_PHASE.NONE

---A command to get all bots to the guild hall and then move to the in game porters
---and ported to the correct location. Returns false when the bot has zoned in to the
---destination, so the caller can transition to the next state.
---@param porterName string either druid, wizard, or name of the npc porter in guild hall
---@param location string name of the location to port to that is used by the porter
---@return boolean, string
function travel.ascendantGuildHallPort(porterName, location)
    local gameState = mq.TLO.MacroQuest.GameState()

    if gameState ~= 'INGAME' then
        return true, 'Zoning...'
    end

    local zone = mq.TLO.Zone.ShortName()

    -- Waiting to arrive in guild hall — hold until we're actually there
    if portPhase == PORT_PHASE.TOGUILDHALL then
        if zone ~= 'guildlobby' then
            return true, 'Waiting to zone to guild hall'
        end
        portPhase = PORT_PHASE.NONE
        -- Fall through to porter logic
    end

    -- Waiting to arrive at destination — hold until we've left guild hall
    if portPhase == PORT_PHASE.TODESTINATION then
        if zone == 'guildlobby' then
            return true, string.format('Waiting to zone to %s', location)
        end
        portPhase = PORT_PHASE.NONE
        return false, 'Arrived at destination'
    end

    if porterName == nil or location == nil then return false, 'Porter name and location required' end
    if porterName:lower() == 'druid' then
        porterName = 'Circlekeeper Aurin'
    elseif porterName:lower() == 'wizard' then
        porterName = 'Spirekeeper Aethen'
    elseif porterName:lower() == 'liminal' then
        porterName = 'Liminal'
    end

    -- Not in guild hall yet — cast Marked Passage and wait
    if zone ~= 'guildlobby' then
        local c, r = altabilityActions.castAA('Marked Passage')
        if c then portPhase = PORT_PHASE.TOGUILDHALL end
        return true, r or 'Waiting for Marked Passage'
    end

    local porter = mq.TLO.Spawn('npc =' .. porterName)

    local c, r = movementActions.navToSpawn(porter, 50)
    if c then return c, r end

    c, r = targetActions.targetSpawn(porter)
    if c then return c, r end

    -- Only say once — prevents repeat /say while waiting for zone-out
    if portPhase == PORT_PHASE.NONE then
        local sayString
        if porterName:lower() == 'liminal' then
            sayString = string.format('/say travel %s', location:lower())
        else
            sayString = string.format('/say %s', location:lower())
        end
        mq.cmdf(sayString)
        portPhase = PORT_PHASE.TODESTINATION
    end
    return true, string.format('Waiting to zone to %s', location)
end

return travel