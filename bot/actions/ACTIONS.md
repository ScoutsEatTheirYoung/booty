# Bot Action Pieces

Small, composable functions. Each does one thing and returns immediately.
Call from state `execute()` functions — never block, never delay.

---

## Casting (`spell.lua`)
- [ ] `castSpell(spellName, gem)` — cast spell on current target, return true if action taken
- [ ] `interruptCast()` — interrupt current cast
- [ ] `isReadyToAct()` — not casting, not stunned, not silenced, not feigning
- [ ] `memorizeSpell(gem, spellName)` — memorize spell into gem slot
- [ ] `findGemForSpell(spellName)` — iterate gems 1-12, return gem num or nil
- [ ] `isSpellMemmed(spellName)` — bool, wraps findGemForSpell
- [ ] `isSpellReady(spellName)` — bool, memmed and off cooldown
- [ ] `willLand(spellName)` — wraps Spell.WillLand(), checks against current target
- [ ] `getSpellData(spellName)` — return useful fields from Spell TLO (resist, duration, targetType, beneficial, stacks)

---

## Buff / Debuff (`buff.lua`)
- [x] `checkAndBuff(buffList, gem)` — cycle through buff list, one action per tick
- [ ] `castDebuff(spellName, gem)` — cast debuff/slow/DoT on current target
- [ ] `hasBuff(spawn, buffName)` — bool, does spawn have this buff
- [ ] `hasDebuff(spawn, debuffName)` — bool, does spawn have this debuff
- [ ] `isSlowed(spawn)` — check for any slow debuff
- [ ] `isMaloed(spawn)` — check for malo/tash debuff

---

## Healing (`healing.lua`)
- [ ] `needsHeal(spawn, pct)` — bool, spawn HP below threshold
- [ ] `findInjuredGroupMember(pct)` — scan group, return first spawn below pct HP or nil
- [ ] `castHeal(spellName, gem, targetSpawn)` — target spawn and cast heal, one action

---

## Crowd Control (`cc.lua`)
- [ ] `castMez(spellName, gem, targetSpawn)` — mez a specific spawn
- [ ] `isMezzed(spawn)` — bool, has mez debuff
- [ ] `castSnare(spellName, gem)` — snare current target
- [ ] `isSnared(spawn)` — bool

---

## Target (`target.lua`)
- [x] `acquireTargetSpawn(spawn)` — target by spawn TLO
- [ ] `acquireTargetID(id)` — target by spawn ID
- [ ] `clearTarget()` — /target clear
- [ ] `hasLiveTarget()` — current target is a live NPC (not corpse, not PC)
- [ ] `getLeaderTarget(leaderName)` — return leader's target spawn or nil
- [ ] `isTargetInMeleeRange(range)` — bool

---

## Combat / Aggro (`melee.lua`)
- [x] `attackOn()` / `attackOff()`
- [x] `combatOff()` — attack off + pet back off
- [ ] `isInCombat()` — Me.Combat()
- [ ] `isMobOnMe()` — NPC with me as target within range
- [ ] `findMobOnMember(memberSpawn)` — return spawn attacking that member or nil
- [ ] `isMobOnAnyMember()` — scan group, return first mob+member pair found

---

## Pet (`pet.lua`)
- [x] `sendPet(targetID)` — send pet to attack if not already on target
- [ ] `petBack()` — /pet back off
- [ ] `petGuard()` — /pet guard here
- [ ] `petFollow()` — /pet follow
- [ ] `hasPet()` — Me.Pet.ID() > 0
- [ ] `petNeedsTarget(targetID)` — bool, pet not already attacking this ID

---

## Movement (`movement.lua`)
- [x] `fanFollow(leaderName, offset, threshold)` — nav to leader + offset if too far
- [x] `approachTarget(meleeRange)` — nav toward current target
- [ ] `navToSpawn(spawn, distance)` — nav to any spawn at distance
- [ ] `navToLoc(y, x)` — nav to coordinates
- [ ] `stopNav()` — /nav stop
- [ ] `isNavigating()` — Navigation.Active()
- [ ] `isNavigationPaused()` — Navigation.Paused()
- [ ] `faceTarget()` — /face target

---

## Mana / HP Management (`regen.lua`)
- [ ] `shouldSit()` — low mana, not in combat, not moving
- [ ] `sit()` / `stand()`
- [ ] `isSitting()` — Me.Sitting()
- [ ] `myHPPct()` — Me.PctHPs()
- [ ] `myManaPct()` — Me.PctMana()
- [ ] `hasEnoughMana(pct)` — bool
- [ ] `hasEnoughHP(pct)` — bool

---

## Group (`group.lua`)
- [x] `resolveTargets(targetList)` — expand self/pet/group/name to spawn list
- [ ] `isGrouped()` — Me.Grouped()
- [ ] `groupSize()` — Group.Members() + 1
- [ ] `getGroupMember(i)` — Group.Member(i) spawn
- [ ] `scanGroupHP(pct)` — return first member spawn below pct HP or nil
- [ ] `scanGroupMana(pct)` — return first member spawn below pct mana or nil
- [ ] `allMembersAlive()` — bool, no dead group members

---

## Loot (`loot.lua`)
- [ ] `findNearbyCorpse(range)` — return nearest NPC corpse spawn within range or nil
- [ ] `lootCorpse(spawn)` — nav to corpse and open loot window
- [ ] `isLooting()` — loot window open

---

## State Checks (`state.lua`)
- [ ] `isAlive()` — not a corpse, not feigning
- [ ] `isFeigning()` — Me.Feigning()
- [ ] `isSafe(range)` — no hostile NPCs within range targeting group
- [ ] `isZoning()` — detect zoning state

---

## Communication (`comms.lua`)
- [ ] `gsay(msg)` — /gsay
- [ ] `tellLeader(leaderName, msg)` — /tell
- [ ] `dtell(peerName, cmd)` — /dtell for DNet peer commands
- [ ] `dgtell(cmd)` — /dgge broadcast to all DNet peers
