import worlds
import reflect
import patty
import noto
import modifiers
import tables
import options
import randomness
import targeting
import options
import root_types
import sugar
import sequtils

variantp AttackSelector:
   AnyAttack
   AttackType(isA : seq[Taxon])
   FromWeapon(weapon : Entity, index : int)
   FromWeaponType(weaponType : seq[Taxon])

variantp AttackTarget:
   Single
   Multiple(count : int)
   Shape(shape : SelectionShape)

variantp StrikeResult:
   Hit(damage : int)
   Blocked(blocked : int, remainingDamage : int)
   Missed
   Dodged
   Deflected

type
   #================================
   # Flag stuff
   #================================

   #================================
   # Attack stuff
   #================================
   Weapon* = object
      attacks* : seq[Attack]

   DamageExpression* = object
      dice : DicePool
      fixed : int
      damageType : Taxon

   ConditionalAttackEffectKind* = enum
      OnHit
      OnMiss

   ConditionalAttackEffect* = object
      kind* : ConditionalAttackEffectKind
      effect* : GameEffect

   Attack* = object
      attackType* : Taxon
      damage* : DamageExpression
      bonusDamage* : seq[DamageExpression]
      minRange* : int16
      maxRange* : int16
      accuracy* : int16
      strikeCount* : int16
      actionCost* : int16
      staminaCost* : int16
      target* : AttackTarget
      additionalCosts* : seq[GameEffect]
      conditionalEffects* : seq[ConditionalAttackEffect]

   AttackModifier* = object
      attackType* : Modifier[Taxon]
      damage* : Modifier[DamageExpression]
      bonusDamage* : Modifier[seq[DamageExpression]]
      minRange* : Modifier[int16]
      maxRange* : Modifier[int16]
      accuracy* : Modifier[int16]
      strikeCount* : Modifier[int16]
      actionCost* : Modifier[int16]
      staminaCost* : Modifier[int16]
      additionalCosts* : Modifier[seq[GameEffect]]
      conditionalEffects* : Modifier[seq[ConditionalAttackEffect]]


   GameEffectKind* {.pure.} = enum
      BasicAttack
      SpecialAttack
      ChangeFlag
      ChangeResource
      Move

   GameEffect* = object
      target* : Selector
      attackSelector* : AttackSelector
      case kind* : GameEffectKind:
      of GameEffectKind.BasicAttack: 
         discard
      of GameEffectKind.SpecialAttack:
         attackModifier* : AttackModifier
      of GameEffectKind.ChangeFlag:
         flag* : Taxon
         flagModifier* : Modifier[int]
      of GameEffectKind.Move:
         moveRange* : int
      of GameEffectKind.ChangeResource:
         resource* : Taxon
         resourceModifier* : Modifier[int]

   EffectGroup* = object
      name* : Option[string]
      costs*: seq[GameEffect]
      effects*: seq[GameEffect]

   EffectPlay* = object
      isCost* : bool
      effect* : GameEffect
      selectors* : Table[SelectorKey, Selector]
      selected* : Table[SelectorKey, SelectionResult]
      

defineReflection(Weapon)

proc matches*(sel : AttackSelector, view : WorldView, attack : Attack) : bool = 
   match sel:
      AnyAttack: true
      AttackType(isA): isA.all((x) => attack.attackType.isA(x))
      FromWeapon(weapon, index): 
         warn "FromWeapon(weapon,index) doesn't make sense when doing reverse matching"
         false
      FromWeaponType(weaponType): 
         # weaponType.all((x) => )
         warn "FromWeaponType(weaponType) not yet implemented for attack selector"
         false