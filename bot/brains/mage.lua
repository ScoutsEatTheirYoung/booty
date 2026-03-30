local mq       = require('mq')
local bt       = require('booty.bot.bt.engine')
local setup    = require('booty.bot.bt.nodes.setup')
local movement = require('booty.bot.bt.nodes.movement')
local combat   = require('booty.bot.bt.nodes.combat')
local spell    = require('booty.bot.bt.nodes.spell')
local buff     = require('booty.bot.bt.nodes.buff')
local group    = require('booty.bot.bt.nodes.group')
local bb = require('booty.bot.bt.blackboard')

-- ── Class config ─────────────────────────────────────────────────────────────
bb.set("nukeSpell", "Blaze")
bb.set("petSpell", "Minor Conjuration: Water")
bb.set("petReagent", "Malachite")

local BUFFS = {
    { spellName = "Burnout II",      refreshTime = 600, targets = { "pet"  } },
    { spellName = "Major Shielding", refreshTime = 600, targets = { "self" } },
    { spellName = "Inferno Shield",  refreshTime = 60,  targets = { "group", "pet", "self" } },
}
-- ─────────────────────────────────────────────────────────────────────────────

local root = bt.Sequence("MageRoot", {
    setup.goToLeaderAndGroup(),

    bt.Selector("Main", {

        bt.Gate("If_Engaged", group.isGroupEngaged,
            bt.Sequence("Combat", {
                combat.assistLeader(),
                spell.castSpell("nukeSpell"),
            })
        ),

        bt.Sequence("Idle", {
            movement.followLeader(),
            bt.Selector("Pet_OK", {
                spell.hasPet(),
                spell.summonPet("petSpell", "petReagent"),
            }),
            bt.Cooldown("GroupBuffCooldown", 10000,
                buff.MaintainGroupBuffs(BUFFS)
            ),
        }),

    }),
})

return root
