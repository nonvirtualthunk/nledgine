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



proc asRichText*(de: DamageExpression): RichText =
   result = de.dice.asRichText
   if de.fixed != 0:
      result.add(richText(toSignedString(de.fixed)))
   result.add(richText(de.damageType))

proc asRichText*(view: WorldView, character: Entity, attack: Attack): RichText =
   result.add(richText("Attack "))
   result.add(richText(&"{attack.accuracy.toSignedString}"))
   result.add(richText(taxon("game concepts", "accuracy")))
   result.add(richTextSpacing(4))
   result.add(attack.damage.asRichText)

   var rangeShape = richText()
   if attack.minRange > 1 or attack.maxRange > 1:
      rangeShape.add(richText(&"Range {attack.maxRange}"))
   match attack.target:
      Shape(shape): rangeShape.add(shape.asRichText)
      _: discard

   if rangeShape.nonEmpty: result.add(richTextVerticalBreak(), rangeShape)





proc asRichText*(view: WorldView, character: Entity, effect: GameEffect, subjectSelector: Option[Selector], targetSelector: Option[Selector]): RichText =
   case effect.kind:
   of GameEffectKind.Attack:
      if character.isSentinel:
         richText(taxon("game concepts", "attack"))
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
