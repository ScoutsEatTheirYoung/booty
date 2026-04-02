local Sensor = require('booty.bot.bt.core.sensor')
local State  = require('booty.bot.bt.core.state')
local mq     = require('mq')

local group = {}

function group.isGrouped()
    return Sensor:new("[S]_Is_Grouped", function()
        local count = mq.TLO.Group.Members() or 0
        if count > 0 then
            return State.SUCCESS, "Grouped (" .. count .. ")"
        end
        return State.FAILURE, "Not grouped"
    end)
end

function group.hasPendingInvite()
    return Sensor:new("[S]_Has_Pending_Invite", function()
        if mq.TLO.Me.Invited() then
            return State.SUCCESS, "Pending invite from " .. tostring(mq.TLO.Me.Invited())
        end
        return State.FAILURE, "No pending invite"
    end)
end

return group
