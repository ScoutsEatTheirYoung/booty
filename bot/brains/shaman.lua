local bt = require('booty.bot.bt.engine')
local setup  = require('booty.bot.bt.nodes.setup')
local movement = require('booty.bot.bt.nodes.movement')
local combat   = require('booty.bot.bt.nodes.combat')
local spell    = require('booty.bot.bt.nodes.spell')
local buff     = require('booty.bot.bt.nodes.buff')
local group    = require('booty.bot.bt.nodes.group')
local check    = require('booty.bot.bt.nodes.check')
local bb = require('booty.bot.bt.blackboard')

-- ── Class config ─────────────────────────────────────────────────────────────
bb.set("nukeSpell", "Winter's Roar")

local BUFFS = {
    { spellName = "Inner Fire",       refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Raging Strength",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Rising Dexterity", refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Nimble",           refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Health",           refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Shifting Shield",  refreshTime = 600, targets = { "self", "group" } },
    { spellName = "Regeneration",     refreshTime = 60,  targets = { "self", "group" } },
    { spellName = "Quickness",        refreshTime = 60,  targets = { "self", "group" } },
    { spellName = "Talisman of Tnarg", refreshTime = 600, targets = { "self", "group" } },
}

bb.set("healSpell", "Greater Healing")
-- ─────────────────────────────────────────────────────────────────────────────


-- Define the Shaman's unique logic
local root = bt.Sequence("ShamanRoot", {
    setup.goToLeaderAndGroup(),

    bt.Selector("Main", {

        bt.Gate("If_Engaged", group.isGroupEngaged,
            bt.Sequence("Combat", {
                combat.assistLeader(),
                spell.castSpell('nukeSpell'),
            })
        ),

        bt.Sequence("Idle", {
            movement.followLeader(),
            bt.Cooldown("GroupBuffCooldown", 5000,
                buff.MaintainGroupBuffs(BUFFS)
            ),
        }),

    }),
})

return root