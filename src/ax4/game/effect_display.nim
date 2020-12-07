import effect_types

import rich_text
import worlds
import combat
import prelude
import options
import graphics/color
import modifiers
import prelude
import noto
import randomness
import patty
import ax4/game/targeting_types
import sequtils

const PrintDamageExpressionsInDicePlusFixedStyle = false

proc asRichText*(de: DamageExpression): RichText =
   # This approach is the 1d8+4 style,
   when PrintDamageExpressionsInDicePlusFixedStyle:
      result = de.dice.asRichText
      if de.fixed != 0:
         result.add(richText(toSignedString(de.fixed)))
   else:
      result = richText(&"{de.minDamage}-{de.maxDamage}")

   result.add(richText(de.damageType))

proc asRichText*(target: AttackTarget): RichText =
   match target:
      Shape(shape): shape.asRichText
      _: richText()

proc asRichText*(view: WorldView, character: Entity, attack: Attack): RichText =
   result.add(richText("Attack "))
   result.add(richText(&"{attack.accuracy.toSignedString}"))
   result.add(richText(taxon("game concepts", "accuracy")))
   result.add(richTextSpacing(4))
   result.add(attack.damage.asRichText)

   var rangeShape = richText()
   if attack.minRange > 1 or attack.maxRange > 1:
      rangeShape.add(richText(&"Range {attack.maxRange}"))
   rangeShape.add(attack.target.asRichText)

   if rangeShape.nonEmpty: result.add(richTextVerticalBreak(), rangeShape)


proc asRichText*(modifier: Modifier[int16]): RichText =
   case modifier.operation:
   of ModifierOperation.Identity: richText()
   of ModifierOperation.Add: richText(modifier.value.toSignedString)
   of ModifierOperation.Sub: richText((modifier.value * -1).toSignedString)
   of ModifierOperation.Mul: richText(&"x{modifier.value}")
   of ModifierOperation.Div: richText(&"/{modifier.value}")
   of ModifierOperation.Set: richText(&"{modifier.value}")
   of ModifierOperation.Reduce: richText(&"reduce by {modifier.value}")
   of ModifierOperation.Recover: richText(&"recover by {modifier.value}")


proc asRichText*(view: WorldView, attack: AttackModifier): RichText =
   if attack.accuracy.operation != ModifierOperation.Identity:
      result.add(attack.accuracy.asRichText)
      result.add(richText(taxon("game concepts", "accuracy")))
      result.add(richTextVerticalBreak())
   if attack.damage.operation != ModifierOperation.Identity:
      result.add(attack.damage.asRichText)
      result.add(richText(" damage"))
      result.add(richTextVerticalBreak())
   if attack.minRange.operation != ModifierOperation.Identity:
      result.add(attack.minRange.asRichText)
      result.add(richText(" minimum range"))
      result.add(richTextVerticalBreak())
   if attack.maxRange.operation != ModifierOperation.Identity:
      result.add(attack.maxRange.asRichText)
      result.add(richText(" maximum range"))
      result.add(richTextVerticalBreak())
   if attack.strikeCount.notIdentity:
      result.add(attack.strikeCount.asRichText)
      result.add(richText(" strikes"))
      result.add(richTextVerticalBreak())
   if attack.actionCost.notIdentity or attack.staminaCost.notIdentity:
      if attack.actionCost.notIdentity:
         result.add(attack.actionCost.asRichText)
         result.add(richText(taxon("resource pools", "action points")))
      if attack.staminaCost.notIdentity:
         result.add(attack.staminaCost.asRichText)
         result.add(richText(taxon("resource pools", "stamina points")))
      result.add(richTextVerticalBreak())
   if attack.target.notIdentity:
      if attack.target.operation != ModifierOperation.Set:
         warn &"An operation other than 'set' doesn't make sense for targets in attack modifiers"
      else:
         result.add(richText("target "))
         result.add(attack.target.value.asRichText)


proc asRichText*(sel: AttackSelector): RichText =
   match sel:
      AnyAttack:
         discard
      AttackType(isA):
         result.add(richText("Is a "))
         var first = true
         for t in isA:
            if not first:
               result.add(richText(","))
            result.add(richText(t))
            first = false
      DamageType(damageType):
         result.add(richText("Does"))
         result.add(richText(damageType))
      FromWeapon(weapon, key):
         result.add(richText("Weapon Keyed selector doesn't usually make sense to see in the abstract"))
      FromWeaponType(weaponType):
         result.add(richText("Weapon is a "))
         result.add(weaponType.mapIt(richText(it)).join(richText(",")))
      CompoundAttackSelector(selectors):
         result = selectors.mapIt(it.asRichText).join(richTextVerticalBreak())




proc asRichText*(view: WorldView, character: Entity, effect: GameEffect, subjectSelector: Option[Selector], targetSelector: Option[Selector]): RichText =
   case effect.kind:
   of GameEffectKind.Attack:
      if character.isSentinel:
         var res = richText(taxon("game concepts", "attack"))
         res.add(richTextVerticalBreak())
         res.add(effect.attackSelector.asRichText)
         res.add(richTextVerticalBreak())
         res.add(asRichText(view, effect.attackModifier))
         res
      else:
         let attack = combat.resolveAttack(view, character, effect.attackSelector)
         if attack.isSome:
            var attack = attack.get
            attack.applyModifiers(effect.attackModifier)
            let extraModifiers = attackModifierFromFlags(view, character)
            attack.applyModifiers(extraModifiers)
            asRichText(view, character, attack)
         else:
            richText("did not resolve attack")
   of GameEffectKind.Move:
      richText(taxon("game concepts", "move")) & richText($effect.moveRange)
   of GameEffectKind.ChangeResource:
      if effect.resourceModifier.operation == ModifierOperation.Reduce:
         richText($effect.resourceModifier.value) & richText(effect.resource)
      elif effect.resourceModifier.operation == ModifierOperation.Recover:
         richText("Recover " & $effect.resourceModifier.value) & richText(effect.resource)
      elif effect.resourceModifier.operation == ModifierOperation.Add:
         richText("Gain " & $effect.resourceModifier.value) & richText(effect.resource)
      else:
         richText("unsupported resource operation")
   of GameEffectKind.ChangeFlag:
      let selfTargeted = targetSelector.isSome and targetSelector.get.restrictions.containsSelfRestriction
      case effect.flagModifier.operation:
      of ModifierOperation.Add, ModifierOperation.Sub:
         var effDelta = 0
         effect.flagModifier.apply(effDelta)
         if effDelta >= 0:
            if selfTargeted: richText(&"Gain {effDelta}") & richText(effect.flag)
            else: richText(&"Apply {effDelta}") & richText(effect.flag)
         else:
            if selfTargeted: richText(&"Lose {effDelta}") & richText(effect.flag)
            else: richText(&"Remove {effDelta}") & richText(effect.flag)
      of ModifierOperation.Mul:
         let word = case effect.flagModifier.value:
            of 2: "Double"
            of 3: "Triple"
            of 4: "Quadruple"
            else: &"x{effect.flagModifier.value}"


         if selfTargeted: richText(&"{word} your") & richText(effect.flag)
         else: richText(&"{word} target's") & richText(effect.flag)
      else:
         richText("unsupported modifier to flags in effect_display, need to add it")
   else:
      richText("unsupported character game effect")

proc asRichText*(view: WorldView, character: Entity, effect: GameEffect): RichText =
   asRichText(view, character, effect, none(Selector), none(Selector))

proc asRichText*(view: WorldView, character: Entity, selEff: SelectableEffects): RichText =
   match selEff.condition:
      AlwaysTrue: discard
      _:
         result.add(richText("If "))
         result.add(selEff.condition.asRichText())
         result.add(richText(":"))
         result.add(richTextVerticalBreak())

   var first = true
   for effect in selEff.effects:
      if not first:
         result.add(richTextVerticalBreak())
      first = false
      result.add(asRichText(view, character, effect, selEff.subjectSelector, selEff.targetSelector))

proc asRichText*(cge: CharacterGameEffects): RichText =
   let view = cge.view
   let character = cge.character

   var first = true
   result = richText(@[])
   for effect in cge.effects:
      if not first:
         result.add(richTextVerticalBreak())
      first = false
      result.add(asRichText(view, character, effect))
   if not cge.active:
      result.tint = some(rgba(1.0f, 1.0f, 1.0f, 1.0f))
