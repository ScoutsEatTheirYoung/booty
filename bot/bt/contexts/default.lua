local mq = require('mq')

-- Builds the default context table passed to every tree tick.
-- Configs inject their class-specific domains on top of this.
-- The engine and all nodes read from this table — never replace it, only mutate it.
---@param leaderName string
---@return table
local function new(leaderName)

    local function allGemsOpen()
        local openGems = {}
        for i = 1, mq.TLO.Me.NumGems() do
            if not mq.TLO.Me.Gem(i)() then table.insert(openGems, i) end
        end
        return openGems
    end

    return {
        leaderName = leaderName,
        group = {
            lastInviteFrom = nil,
        },
        combat = {
            mode = "Walk",
        },
        spell = {
            gemCount      = mq.TLO.Me.NumGems(),
            protectedGems = {},
            openGems      = allGemsOpen(), -- by default all open
        },
    }
end

return new
