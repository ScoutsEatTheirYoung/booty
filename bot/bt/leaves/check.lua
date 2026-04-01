local Leaf = require('booty.bot.bt.core.leaf')
local State = require('booty.bot.bt.core.state')
local mq = require('mq')

local check = {}

function check.isGrouped()
    return Leaf:new("IsGrouped", function()
        local count = mq.TLO.Group.Members() or 0
        if count > 0 then
            return State.SUCCESS, "Grouped (" .. count .. ")"
        end
        return State.FAILURE, "Not grouped"
    end)
end

function check.hasPendingInvite()
    return Leaf:new("HasPendingInvite", function()
        if mq.TLO.Me.Invited() then
            return State.SUCCESS, "Pending invite found"
        end
        return State.FAILURE, "No pending invite"
    end)
end

function check.amICasting()
    return Leaf:new("AmICasting", function()
        if mq.TLO.Me.Casting() then
            return State.SUCCESS, "Currently casting"
        end
        return State.FAILURE, "Not casting"
    end)
end

function check.notNil(key)
    return Leaf:new("NotNil:" .. key, function(_, context)
        if context[key] ~= nil then
            return State.SUCCESS, key .. " is not nil"
        end
        return State.FAILURE, key .. " is nil"
    end)
end

return check