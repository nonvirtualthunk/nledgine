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
import config
import arxregex
import strutils
import core

variantp AttackSelector:
   AnyAttack
   AttackType(isA: seq[Taxon])
   FromWeapon(weapon: Entity, index: int)
   FromWeaponType(weaponType: seq[Taxon])

variantp AttackTarget:
   Single
   Multiple(count: int)
   Shape(shape: SelectionShape)

variantp StrikeResult:
   Hit(damage: int)
   Blocked(blocked: int, remainingDamage: int)
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
      attacks*: seq[Attack]

   DamageExpression* = object
      dice: DicePool
      fixed: int
      damageType: Taxon

   ConditionalAttackEffectKind* = enum
      OnHit
      OnMiss

   ConditionalAttackEffect* = object
      kind*: ConditionalAttackEffectKind
      effect*: GameEffect

   Attack* = object
      attackType*: Taxon
      damage*: DamageExpression
      bonusDamage*: seq[DamageExpression]
      minRange*: int16
      maxRange*: int16
      accuracy*: int16
      strikeCount*: int16
      actionCost*: int16
      staminaCost*: int16
      target*: AttackTarget
      additionalCosts*: seq[GameEffect]
      conditionalEffects*: seq[ConditionalAttackEffect]

   AttackModifier* = object
      attackType*: Modifier[Taxon]
      damage*: Modifier[DamageExpression]
      bonusDamage*: Modifier[seq[DamageExpression]]
      minRange*: Modifier[int16]
      maxRange*: Modifier[int16]
      accuracy*: Modifier[int16]
      strikeCount*: Modifier[int16]
      actionCost*: Modifier[int16]
      staminaCost*: Modifier[int16]
      additionalCosts*: Modifier[seq[GameEffect]]
      conditionalEffects*: Modifier[seq[ConditionalAttackEffect]]


   GameEffectKind* {.pure.} = enum
      Attack
      ChangeFlag
      ChangeResource
      Move

   GameEffect* = object
      target*: Selector
      case kind*: GameEffectKind:
      of GameEffectKind.Attack:
         attackSelector*: AttackSelector
         attackModifier*: AttackModifier
      of GameEffectKind.ChangeFlag:
         flag*: Taxon
         flagModifier*: Modifier[int]
      of GameEffectKind.Move:
         moveRange*: int
      of GameEffectKind.ChangeResource:
         resource*: Taxon
         resourceModifier*: Modifier[int]

   # Game effect being triggered by a particular character
   CharacterGameEffects* = object
      view*: WorldView
      character*: Entity
      active*: bool
      effects*: seq[GameEffect]


   EffectGroup* = object
      name*: Option[string]
      costs*: seq[GameEffect]
      effects*: seq[GameEffect]

   EffectPlay* = object
      isCost*: bool
      effect*: GameEffect
      selectors*: Table[SelectorKey, Selector]
      selected*: Table[SelectorKey, SelectionResult]

   EffectPlayGroup* = object
      source*: Entity
      plays*: seq[EffectPlay]


defineReflection(Weapon)

const wordNumberPattern = re"([a-zA-Z0-9]+)\s?\(([0-9]+)\)"

proc `==`*(a, b: GameEffect): bool =
   if a.kind != b.kind or a.target != b.target:
      return false
   case a.kind:
   of GameEffectKind.Attack:
      a.attackSelector == b.attackSelector and a.attackModifier == b.attackModifier
   of GameEffectKind.ChangeFlag:
      a.flag == b.flag and a.flagModifier == b.flagModifier
   of GameEffectKind.Move:
      a.moveRange == b.moveRange
   of GameEffectKind.ChangeResource:
      a.resource == b.resource and a.resourceModifier == b.resourceModifier

proc `==`*(a, b: EffectPlayGroup): bool = a.plays == b.plays

proc readFromConfig*(cv: ConfigValue, ge: var GameEffect) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(wordNumberPattern, word, numberStr):
            let num = numberStr.parseInt()
            if word.toLowerAscii == "move":
               ge = GameEffect(kind: GameEffectKind.Move, target: selfSelector(), moveRange: num)
            else:
               let rsrcPool = maybeTaxon("ResourcePools", word)
               if rsrcPool.isSome:
                  ge = GameEffect(kind: GameEffectKind.ChangeResource, target: selfSelector(), resource: rsrcPool.get, resourceModifier: modifiers.reduce(num))
               else:
                  warn &"unknown word(number) pattern for game effect: {word}, {numberStr}"
         warn &"Unknown string based game effect: {str}"
   else:
      warn &"unknown config representation of game effect : {cv}"

defineSimpleReadFromConfig(EffectGroup)

proc matches*(sel: AttackSelector, view: WorldView, attack: Attack): bool =
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
