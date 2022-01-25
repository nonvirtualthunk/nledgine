import worlds
import reflect
import patty
import noto
import game/modifiers
import tables
import options
import game/randomness
import targeting_types
import effect_types
import ax4/game/items
import flags
import ax_events
import core
import characters
import sequtils
import prelude
import hex
import ax4/game/derived_modifiers

let defenseDelta = taxon("flags", "defense delta")
let physicalDamage = taxon("damage types", "physical")
let armorDelta = taxon("flags", "armor delta")
let blockFlag = taxon("flags", "block")


type
   BlockGainedEvent* = ref object of AxEvent
      amountGained*: int

method toString*(evt: BlockGainedEvent, view: WorldView): string =
   return &"BlockGained({$evt[]})"

proc applyDerivedModifier*(view: WorldView, character: Entity, target: Option[Entity], modifier: DerivedModifier[AttackField], attack: var Attack) =
   let delta = derivedModifierDelta(view, character, target, modifier)
   case modifier.field:
   of AttackField.Damage: attack.damage.fixed += delta
   of AttackField.MinRange: attack.minRange = max(attack.minRange + delta, 0).int16
   of AttackField.MaxRange: attack.maxRange = max(attack.maxRange + delta, 0).int16
   of AttackField.Accuracy: attack.accuracy += delta.int16
   of AttackField.StrikeCount: attack.strikeCount = max(attack.strikeCount + delta, 0).int16
   of AttackField.ActionCost: attack.actionCost = max(attack.actionCost + delta, 0).int16
   of AttackField.StaminaCost: attack.staminaCost = max(attack.staminaCost + delta, 0).int16

proc applyUntargetedDerivedAttackModifiers*(view: WorldView, character: Entity, attack: var Attack) =
   for derivedModifier in attack.derivedModifiers:
      if derivedModifier.entity != DerivedModifierEntity.Target:
         applyDerivedModifier(view, character, none(Entity), derivedModifier, attack)

proc applyTargetedDerivedAttackModifiers*(view: WorldView, character: Entity, target: Entity, attack: var Attack) =
   for derivedModifier in attack.derivedModifiers:
      if derivedModifier.entity == DerivedModifierEntity.Target:
         applyDerivedModifier(view, character, some(target), derivedModifier, attack)

proc availableAttacks*(view: WorldView, character: Entity): seq[Attack] =
   withView(view):
      for item in equippedItems(view, character):
         if item.hasData(Weapon):
            let WD = item[Weapon]
            for value in WD.attacks.values:
               result.add(value.attack)

proc resolveAttack*(view: WorldView, character: Entity, selector: AttackSelector): Option[Attack] =
  warn "Resolve attack has been deprecated"
  writeStackTrace()
  none(Attack)

   # withView(view):
   #    match selector:
   #       FromWeapon(weapon, key):
   #          let wd = weapon[Weapon]
   #          if wd.attacks.hasKey(key):
   #             return some(wd.attacks[key].attack)
   #          else:
   #             warn &"Attack selector failed to resolve, weapon does not have appropriate attack"
   #             return none(Attack)
   #       _: discard
   #
   #    let allAttacks = availableAttacks(view, character)
   #    let allSelectors = match selector:
   #       CompoundAttackSelector(selectors): selectors
   #       _: @[selector]
   #
   #    for attack in allAttacks:
   #       let attackCopy = attack
   #       if allSelectors.all(sel => sel.matches(view, attackCopy)):
   #          return some(attack)
   #    none(Attack)

proc attackModifierFromFlags*(view: WorldView, character: Entity): AttackModifier =
   result.damage = add(flags.flagValue(view, character, taxon("flags", "damage bonus")).int16)
   let damageFractReductionFlag = flags.flagValue(view, character, taxon("flags", "damage dealt reduction percent"))
   if damageFractReductionFlag != 0:
      result.damageFraction = mul(1.0f - (damageFractReductionFlag.float / 100.0f))
   result.accuracy = add(flags.flagValue(view, character, taxon("flags", "accuracy delta")).int16)

proc attackModifierFromTargetedFlags*(view: WorldView, character: Entity, target: Entity): AttackModifier =
   let damageTakenIncreaseFlag = flags.flagValue(view, character, taxon("flags", "DamageTakenIncreasePercent"))
   if damageTakenIncreaseFlag != 0:
      result.damageFraction = mul(1.0f + (damageTakenIncreaseFlag.float / 100.0f))


proc attackCosts*(attack: Attack): seq[GameEffect] =
   if attack.actionCost != 0:
      result.add(GameEffect(kind: GameEffectKind.ChangeResource, resource: taxon("resource pools", "action points"), resourceModifier: reduce(attack.actionCost.int)))
   if attack.staminaCost != 0:
      result.add(GameEffect(kind: GameEffectKind.ChangeResource, resource: taxon("resource pools", "stamina points"), resourceModifier: reduce(attack.staminaCost.int)))
   result.add(attack.additionalCosts)

proc defenseFor*(view: WorldView, character: Entity): Defense =
   withView(view):
      let flags = character[Flags]
      result.defense += flags.flagvalue(defenseDelta)
      result.damageReduction[physicalDamage] = flags.flagValue(armorDelta)
      result.blockAmount = flags.flagValue(blockFlag)

# proc evaluateDamageIntern(world: World, character: Entity, damage: DamageExpression) =
#    world.eventStmts(DamageEvent(entity: character, damage: damage)):
#       if blockReduction > 0:
#          modifyFlag(world, target, blockFlag, sub(blockReduction))
#       character.modify(Character.health.reduceBy(damage.total))


proc blockFlagFor(damage: DamageExpressionResult): Option[Taxon] =
   if damage.damageType.isA(taxon("damage types", "physical")):
      some(blockFlag)
   else:
      none(Taxon)

proc computeBlockAmount*(view: WorldView, character: Entity, damage: DamageExpressionResult): int =
   withView(view):
      let flag = blockFlagFor(damage)
      if flag.isSome:
         let blockAmount = character[Flags].flagValue(flag.get)
         var blockReduction = min(damage.total, blockAmount)
         blockReduction
      else:
         0

proc dealDamage*(world: World, character: Entity, damage: DamageExpressionResult) =
   let blockFlag = blockFlagFor(damage)
   let blockAmount = computeBlockAmount(world, character, damage)

   var modifiedDamage = damage
   modifiedDamage.reducedBy = blockAmount

   world.eventStmts(DamageEvent(entity: character, damage: modifiedDamage)):
      if blockFlag.isSome:
         modifyFlag(world, character, blockFlag.get, sub(blockAmount))
      character.modify(Character.health.reduceBy(modifiedDamage.total))

proc isAttackValid*(view: WorldView, character: Entity, attack: Attack, targets: seq[Entity]): bool =
   withView(view):
      let attackFrom = character[Physical].position
      for target in targets:
         let dist = target[Physical].position.distance(attackFrom)
         if dist < attack.minRange.float or dist > attack.maxRange.float:
            return false
      true


proc gainBlock*(world: World, entity: Entity, amountGained: int) =
   if amountGained != 0:
      world.eventStmts(BlockGainedEvent(entity: entity, amountGained: amountGained)):
         modifyFlag(world, entity, blockFlag, add(amountGained))
         # entity.modify(Combat.blockAmount += amountGained)
