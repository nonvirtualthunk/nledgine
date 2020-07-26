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


proc resolveAttack*(view: WorldView, character: Entity, selector: AttackSelector): Option[Attack] =
   warn "attack resolution not yet implemented"
   some(Attack())

proc applyModifiers*(attack: var Attack, modifier: AttackModifier) =
   warn "attack modifier applicaton not yet implemented"

proc attackCosts*(attack: Attack): seq[GameEffect] =
   if attack.actionCost != 0:
      result.add(GameEffect(kind: GameEffectKind.ChangeResource, resource: taxon("ResourcePools", "actionPoints")))
   if attack.staminaCost != 0:
      result.add(GameEffect(kind: GameEffectKind.ChangeResource, resource: taxon("ResourcePools", "staminaPoints")))
   result.add(attack.additionalCosts)
