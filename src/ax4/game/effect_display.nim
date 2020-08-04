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





proc asRichText*(view: WorldView, character: Entity, effect: GameEffect): RichText =
   case effect.kind:
   of GameEffectKind.Attack:
      if character.isSentinel:
         richText(taxon("game concepts", "attack"))
      else:
         let attack = combat.resolveAttack(view, character, effect.attackSelector)
         if attack.isSome:
            var attack = attack.get
            attack.applyModifiers(effect.attackModifier)
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
   else:
      richText("unsupported character game effect")


proc asRichText*(cge: CharacterGameEffects): RichText =
   let view = cge.view
   let character = cge.character

   result = richText(@[])
   for effect in cge.effects:
      result.add(asRichText(view, character, effect))
   if not cge.active:
      result.tint = some(rgba(1.0f, 1.0f, 1.0f, 1.0f))
