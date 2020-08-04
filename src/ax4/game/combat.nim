import worlds
import reflect
import patty
import noto
import modifiers
import tables
import options
import randomness
import targeting_types
import effect_types
import ax4/game/items
import flags
import ax_events
import core
import characters
import items
import sequtils
import prelude

let defenseDelta = taxon("flags", "defense delta")
let physicalDamage = taxon("damage types", "physical")
let armorDelta = taxon("flags", "armor delta")
let blockFlag = taxon("flags", "block")

proc availableAttacks*(view: WorldView, character: Entity): seq[Attack] =
   withView(view):
      for item in equippedItems(view, character):
         if item.hasData(Weapon):
            let WD = item[Weapon]
            for value in WD.attacks.values:
               result.add(value.attack)

proc resolveAttack*(view: WorldView, character: Entity, selector: AttackSelector): Option[Attack] =
   withView(view):
      match selector:
         FromWeapon(weapon, key):
            let wd = weapon[Weapon]
            if wd.attacks.hasKey(key):
               return some(wd.attacks[key].attack)
            else:
               warn &"Attack selector failed to resolve, weapon does not have appropriate attack"
               return none(Attack)
         _: discard

      let allAttacks = availableAttacks(view, character)
      let allSelectors = match selector:
         CompoundAttackSelector(selectors): selectors
         _: @[selector]

      for attack in allAttacks:
         if allSelectors.all(sel => sel.matches(view, attack)):
            return some(attack)
      none(Attack)



proc attackCosts*(attack: Attack): seq[GameEffect] =
   if attack.actionCost != 0:
      result.add(GameEffect(kind: GameEffectKind.ChangeResource, resource: taxon("ResourcePools", "actionPoints"), resourceModifier: reduce(attack.actionCost.int)))
   if attack.staminaCost != 0:
      result.add(GameEffect(kind: GameEffectKind.ChangeResource, resource: taxon("ResourcePools", "staminaPoints"), resourceModifier: reduce(attack.staminaCost.int)))
   result.add(attack.additionalCosts)

proc defenseFor*(view: WorldView, character: Entity): Defense =
   withView(view):
      let flags = character[Flags]
      result.defense += flags.flagvalue(defenseDelta)
      result.damageReduction[physicalDamage] = flags.flagValue(armorDelta)
      result.blockAmount = flags.flagValue(blockFlag)

proc dealDamage*(world: World, character: Entity, damage: DamageExpressionResult) =
   withWorld(world):
      world.eventStmts(DamageEvent(entity: character, damage: damage)):
         character.modify(Character.health.reduceBy(damage.total))

proc performAttack*(world: World, character: Entity, attack: Attack, targets: seq[Entity]) =
   withWorld(world):
      var randomizer = world.randomizer

      world.eventStmts(AttackEvent(entity: character, attack: attack, targets: targets)):
         for target in targets:
            for strikeIndex in 0 ..< attack.strikeCount:
               let defense = defenseFor(world, character)

               echo &"Attack:\n{attack}\nDefense:\n{defense}"

               let baseRoll = randomizer.stdRoll().total - 10

               if baseRoll + attack.accuracy - defense.defense > 0:
                  var damage = attack.damage.roll(randomizer)
                  let rawDamage = damage.total
                  var blockReduction = min(rawDamage, defense.blockAmount)
                  damage.reducedBy = blockReduction
                  let strikeResult = if blockReduction > 0:
                     Blocked(blockReduction, damage.total)
                  else:
                     Hit(damage.total)

                  world.eventStmts(StrikeEvent(entity: character, target: target, attack: attack, result: strikeResult)):
                     dealDamage(world, target, damage)
                     if blockReduction > 0:
                        modifyFlag(world, target, blockFlag, sub(blockReduction))
               else:
                  world.eventStmts(StrikeEvent(entity: character, target: target, attack: attack, result: Missed())):
                     discard
