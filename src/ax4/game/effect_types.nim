import worlds
import reflect
import patty
import noto
import modifiers
import tables
import options
import randomness
import targeting_types
import options
import root_types
import sugar
import sequtils
import config
import arxregex
import strutils
import core
import config/config_helpers
import arxregex

type
   AttackKey* {.pure.} = enum
      Primary
      Secondary

variantp AttackSelector:
   AnyAttack
   AttackType(isA: seq[Taxon])
   FromWeapon(weapon: Entity, key: AttackKey)
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
      attackTypes*: seq[Taxon]
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
      SimpleAttack
      ChangeFlag
      ChangeResource
      Move
      AddCard

   GameEffect* = object
      case kind*: GameEffectKind:
      of GameEffectKind.Attack:
         attackSelector*: AttackSelector
         attackModifier*: AttackModifier
      of GameEffectKind.SimpleAttack:
         attack*: Attack
      of GameEffectKind.ChangeFlag:
         flag*: Taxon
         flagModifier*: Modifier[int]
      of GameEffectKind.Move:
         moveRange*: int
         desiredDistance*: int # i.e. if you have a ranged attack and want to move to within it's maximum range
      of GameEffectKind.ChangeResource:
         resource*: Taxon
         resourceModifier*: Modifier[int]
      of GameEffectKind.AddCard:
         cardChoices*: seq[Taxon]
         toDeck*: DeckKind
         toLocation*: CardLocation

   # Game effect being triggered by a particular character
   CharacterGameEffects* = object
      view*: WorldView
      character*: Entity
      active*: bool
      effects*: seq[GameEffect]

   # Set of effects that are targeted and applied together, which may or may not be a cost and thefore required before
   # other effects can be applied. May contain additional information on what the allowed selections are
   # Examples:
   # apply 2 weak, 2 vulnerable
   #    conversely: apply 2 weak to self, apply 2 vulnerable to an enemy
   # we want to both be able to differentiate between the two, and also not have to select every target individually

   SelectableEffects* = object
      effects*: seq[GameEffect]
      targetSelector*: Option[Selector]
      subjectSelector*: Option[Selector]
      isCost*: bool

   EffectGroup* = object
      name*: Option[string]
      effects*: seq[SelectableEffects]

   EffectPlay* = object
      isCost*: bool
      effects*: SelectableEffects
      selectors*: OrderedTable[SelectorKey, Selector]
      selected*: Table[SelectorKey, SelectionResult]

   EffectPlayGroup* = object
      source*: Entity
      plays*: seq[EffectPlay]


proc `==`*(a, b: GameEffect): bool =
   if a.kind != b.kind:
      return false
   case a.kind:
   of GameEffectKind.Attack:
      a.attackSelector == b.attackSelector and a.attackModifier == b.attackModifier
   of GameEffectKind.SimpleAttack:
      a.attack == b.attack
   of GameEffectKind.ChangeFlag:
      a.flag == b.flag and a.flagModifier == b.flagModifier
   of GameEffectKind.Move:
      a.moveRange == b.moveRange
   of GameEffectKind.ChangeResource:
      a.resource == b.resource and a.resourceModifier == b.resourceModifier
   of GameEffectKind.AddCard:
      a.cardChoices == b.cardChoices

proc `==`*(a, b: EffectPlayGroup): bool = a.plays == b.plays

iterator items*(s: SelectableEffects): GameEffect =
   for e in s.effects: yield e

proc costs*(s: EffectGroup): seq[SelectableEffects] =
   s.effects.filterIt(it.isCost)

const simpleDamageExprRegex = re"([0-9]+)d([0-9]+)\s?([+-][0-9]+)?\s?([a-zA-Z]+)"

proc readFromConfig*(cv: ConfigValue, d: var DamageExpression) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(simpleDamageExprRegex, dice, pips, bonusStr, damageType):
            d.dice = dicePool(dice.parseInt, pips.parseInt)
            if bonusStr != "":
               d.fixed = bonusStr.parseInt
            d.damageType = taxon("DamageTypes", damageType)
         warn &"Unexpected string format for damage expression: {str}"
   else:
      warn &"unexpected config for damage expression: {cv}"

const singleAttackTargetRegex = re"(?i)single"
const multipleAttackTargetRegex = re"(?i)multiple\s?\((\d+)\)"


proc readFromConfig*(cv: ConfigValue, t: var AttackTarget) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(singleAttackTargetRegex):
            t = Single()
         extractMatches(multipleAttackTargetRegex, count):
            t = Multiple(count.parseInt)
         warn &"Unsupported attack target expression: {str}"
   else:
      warn &"unsupported attack target config: {cv}"

proc readFromConfig*(cv: ConfigValue, ge: var GameEffect) {.gcsafe.}

const onHitExpr = re"(?i)onHit\s?\((.+)\)"
const onMissExpr = re"(?i)onMiss\s?\((.+)\)"

proc readFromConfig*(cv: ConfigValue, e: var ConditionalAttackEffect) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(onHitExpr, onHit):
            e.kind = OnHit
            readInto(asConf(onHit), e.effect)
         extractMatches(onMissExpr, onMiss):
            e.kind = OnMiss
            readInto(asConf(onMiss), e.effect)
         warn &"Unsupported conditional attack effect expression: {str}"
   else:
      warn &"unsupported conditional attack effect config: {cv}"

const simpleAttackPattern = re"(?i)([+-]\d+) (.+? .+?) (?:x(\d+))?\s?\(([a-z,]+)\)"

proc readFromConfig*(cv: ConfigValue, a: var Attack) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(simpleAttackPattern, accuracy, damageExpr, strikeCountExpr, attackTypesStr):
            let acc = accuracy.parseInt
            let dmg = readInto(asConf(damageExpr), DamageExpression)
            var strikeCount = 1
            if strikeCountExpr != "":
               strikeCount = strikeCountExpr.parseInt
            var attackTypes: seq[Taxon]
            for attackTypeStr in attackTypesStr.split(","):
               attackTypes.add(taxon("attack types", attackTypeStr))
            a = Attack(
               attackTypes: attackTypes,
               damage: dmg,
               minRange: 0,
               maxRange: 1,
               accuracy: acc.int16,
               strikeCount: strikeCount.int16,
               target: Single()
            )
   else:
      readInto(cv["attackTypes"], a.attackTypes)
      readInto(cv["damage"], a.damage)
      readInto(cv["minRange"], a.minRange)
      readIntoOrElse(cv["maxRange"], a.maxRange, 1)
      readInto(cv["accuracy"], a.accuracy)
      readIntoOrElse(cv["strikeCount"], a.strikeCount, 1)
      readIntoOrElse(cv["actionCost"], a.actionCost, 1)
      readIntoOrElse(cv["staminaCost"], a.staminaCost, 0)
      readIntoOrElse(cv["target"], a.target, Single())
      readInto(cv["additionalCosts"], a.additionalCosts)
      readInto(cv["conditionalEffects"], a.conditionalEffects)

proc readFromConfig*(cv: ConfigValue, a: var AttackModifier) =
   if cv.isStr:
      warn &"string based attack modifiers not yet implemented : {cv.asStr}"
   else:
      readFromConfigByField(cv, AttackModifier, a)


const addCardRe = re"(?ix)addcard\((.+)\)"

proc readFromConfig*(cv: ConfigValue, ge: var GameEffect) {.gcsafe.} =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(wordNumberPattern, word, numberStr):
            let num = numberStr.parseInt()
            if word.toLowerAscii == "move":
               ge = GameEffect(kind: GameEffectKind.Move, moveRange: num)
            else:
               let rsrcPool = maybeTaxon("ResourcePools", word)
               if rsrcPool.isSome:
                  ge = GameEffect(kind: GameEffectKind.ChangeResource, resource: rsrcPool.get, resourceModifier: modifiers.reduce(num))
               else:
                  warn &"unknown word(number) pattern for game effect: {word}, {numberStr}"
         extractMatches(simpleAttackPattern):
            ge = GameEffect(kind: GameEffectKind.SimpleAttack, attack: readInto(asConf(str), Attack))
         extractMatches(addCardRe, cardName):
            ge = GameEffect(kind: GameEffectKind.AddCard, cardChoices: @[taxon("card types", cardName)])
         warn &"Unknown string based game effect: {str}"
   elif cv.isObj:
      let kind = cv["kind"].asStr.toLowerAscii
      case kind:
      of "simpleattack":
         ge = GameEffect(kind: GameEffectKind.SimpleAttack, attack: readInto(cv, Attack))
      else: warn &"unknown kind for game effect config object: {kind}"
   else:
      warn &"unknown config representation of game effect : {cv}"

proc readFromConfig*(cv: ConfigValue, s: var SelectableEffects) =
   if cv.isStr:
      s.effects = @[readInto(cv, GameEffect)]
   else:
      readFromConfigByField(cv, SelectableEffects, s)
      readInto(cv["target"], s.targetSelector)
      readInto(cv["subject"], s.subjectSelector)

proc readFromConfig*(cv: ConfigValue, e: var EffectGroup) =
   readInto(cv["name"], e.name)
   readInto(cv["effects"], e.effects)
   if cv["costs"].nonEmpty:
      var costs = readInto(cv["costs"], seq[SelectableEffects])
      for cost in costs.mitems:
         cost.isCost = true
      e.effects.add(costs)

proc readFromConfig*(cv: ConfigValue, v: var AttackKey) =
   v = parseEnum[AttackKey](cv.asStr)

proc matches*(sel: AttackSelector, view: WorldView, attack: Attack): bool =
   match sel:
      AnyAttack: true
      AttackType(isA): isA.all((x) => attack.attackTypes.any(y => y.isA(x)))
      FromWeapon(weapon, key):
         warn "FromWeapon(weapon,index) doesn't make sense when doing reverse matching"
         false
      FromWeaponType(weaponType):
         # weaponType.all((x) => )
         warn "FromWeaponType(weaponType) not yet implemented for attack selector"
         false

