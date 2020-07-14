import effect_types

import rich_text
import worlds
import attacks
import prelude
import options
import graphics/color
import modifiers


proc asRichText*(view: WorldView, character: Entity, effect: GameEffect): RichText =
   case effect.kind:
   of GameEffectKind.Attack:
      if character.isSentinel:
         richText(taxon("game concepts", "attack"))
      else:
         let attack = attacks.resolveAttack(view, character, effect.attackSelector)
         if attack.isSome:
            richText("actually resolved attack")
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
