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
import prelude

type
   AttackKey* {.pure.} = enum
      Primary
      Secondary

variantp AttackSelector:
   AnyAttack
   AttackType(isA: seq[Taxon])
   DamageType(damageType: Taxon)
   FromWeapon(weapon: Entity, key: AttackKey)
   FromWeaponType(weaponType: seq[Taxon])
   CompoundAttackSelector(selectors: seq[AttackSelector])

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
      dice*: DicePool
      fixed*: int
      damageType*: Taxon

   DamageExpressionResult* = object
      diceRoll*: DiceRoll
      fixed*: int
      damageType*: Taxon
      reducedBy*: int

   ConditionalAttackEffectKind* = enum
      OnHit
      OnMiss

   ConditionalAttackEffectTarget* {.pure.} = enum
      Target
      Card
      Self

   ConditionalAttackEffect* = object
      kind*: ConditionalAttackEffectKind
      target*: ConditionalAttackEffectTarget
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
      attackTypes*: Modifier[seq[Taxon]]
      damage*: Modifier[int]
      bonusDamage*: Modifier[seq[DamageExpression]]
      minRange*: Modifier[int16]
      maxRange*: Modifier[int16]
      accuracy*: Modifier[int16]
      strikeCount*: Modifier[int16]
      actionCost*: Modifier[int16]
      staminaCost*: Modifier[int16]
      target*: Modifier[AttackTarget]
      additionalCosts*: Modifier[seq[GameEffect]]
      conditionalEffects*: Modifier[seq[ConditionalAttackEffect]]

   Defense* = object
      defense*: int
      blockAmount*: int
      damageReduction*: Table[Taxon, int]

   GameEffectKind* {.pure.} = enum
      Attack
      SimpleAttack
      ChangeFlag
      ChangeResource
      Move
      AddCard
      MoveCard

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
      of GameEffectKind.MoveCard:
         moveToDeck*: Option[DeckKind]
         moveToLocation*: Option[CardLocation]


   # Game effect being triggered by a particular character
   CharacterGameEffects* = object
      view*: WorldView
      character*: Entity
      active*: bool
      effects*: seq[SelectableEffects]

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
      condition*: GameCondition
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
      a.cardChoices == b.cardChoices and a.toDeck == b.toDeck and a.toLocation == b.toLocation
   of GameEffectKind.MoveCard:
      a.moveToDeck == b.moveToDeck and a.moveToLocation == b.moveToLocation

proc `==`*(a, b: EffectPlayGroup): bool = a.plays == b.plays

iterator items*(s: SelectableEffects): GameEffect =
   for e in s.effects: yield e

proc costs*(s: EffectGroup): seq[SelectableEffects] =
   s.effects.filterIt(it.isCost)

proc nonCosts*(s: EffectGroup): seq[SelectableEffects] =
   s.effects.filterIt(not it.isCost)

proc roll*(s: DamageExpression, r: var Randomizer): DamageExpressionResult =
   DamageExpressionResult(
      diceRoll: s.dice.roll(r),
      fixed: s.fixed,
      damageType: s.damageType,
   )

proc total*(s: DamageExpressionResult): int =
   s.diceRoll.total + s.fixed - s.reducedBy

proc minDamage*(d: DamageExpression): int =
   d.dice.minRoll + d.fixed

proc maxDamage*(d: DamageExpression): int =
   d.dice.maxRoll + d.fixed

proc damageRange*(d: DamageExpression): (int, int) =
   (d.minDamage, d.maxDamage)

const simpleDamageExprRegex = re"([0-9]+)d([0-9]+)\s?([+-][0-9]+)?\s?([a-zA-Z]+)"
const simpleFixedDamageExprRegex = re"([+-]?[0-9]+)\s?([a-zA-Z]+)"

proc readFromConfig*(cv: ConfigValue, d: var DamageExpression) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(simpleDamageExprRegex, dice, pips, bonusStr, damageType):
            d.dice = dicePool(dice.parseInt, pips.parseInt)
            if bonusStr != "":
               d.fixed = bonusStr.parseInt
            d.damageType = taxon("DamageTypes", damageType)
         extractMatches(simpleFixedDamageExprRegex, bonusStr, damageType):
            d.fixed = bonusStr.parseInt
            d.damageType = taxon("DamageTypes", damageType)
         warn &"Unexpected string format for damage expression: {str}"
   else:
      warn &"unexpected config for damage expression: {cv}"

const singleAttackTargetRegex = re"(?i)single"
const multipleAttackTargetRegex = re"(?i)multiple\s?\((\d+)\)"
const lineTargetRegex = re"(?ix)line\(([\d+]),([\d+])\)"

proc readFromConfig*(cv: ConfigValue, t: var AttackTarget) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(singleAttackTargetRegex):
            t = Single()
         extractMatches(multipleAttackTargetRegex, count):
            t = Multiple(count.parseInt)
         extractMatches(lineTargetRegex, min, max):
            t = Shape(Line(min.parseInt, max.parseInt))
         warn &"Unsupported attack target expression: {str}"
   else:
      warn &"unsupported attack target config: {cv}"

const anyAttackRegex = re"(?ix)anyAttack"
const attackTypeRegex = re"(?ix)attackType\((.+)\)"
const damageTypeRegex = re"(?ix)damageType\((.+)\)"
const weaponTypeRegex = re"(?ix)weaponType\((.+)\)"


proc readFromConfig*(cv: ConfigValue, s: var AttackSelector) =
   if cv.isArr:
      s = CompoundAttackSelector(cv.asArr.mapIt(it.readInto(AttackSelector)))
   elif cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(anyAttackRegex): s = AnyAttack()
         extractMatches(attackTypeRegex, attackTypeStr): s = AttackType(@[taxon("attack types", attackTypeStr)])
         extractMatches(damageTypeRegex, damageTypeStr): s = DamageType(taxon("damage types", damageTypeStr))
         extractMatches(weaponTypeRegex, weaponType): s = FromWeaponType(@[taxon("weapon types", weaponType)])
         warn &"Invalid string format for attack selector: {str}"
   else:
      warn &"unsupported attack selector config: {cv}"


proc readFromConfig*(cv: ConfigValue, ge: var GameEffect) {.gcsafe.}

const onHitExpr = re"(?i)onHit\s?\((.+)\)"
const onMissExpr = re"(?i)onMiss\s?\((.+)\)"

const onHitKindExpr = re"(?ix)onHit"
const onMissKindExpr = re"(?ix)onHit"

const targetTargetExpr = re"(?ix)target"
const selfTargetExpr = re"(ix)self"
const cardTargetExpr = re"(ix)card"

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
   elif cv.isObj:
      var target = ConditionalAttackEffectTarget.Target
      if cv["target"].nonEmpty:
         let str = cv["target"].asStr
         matcher(str):
            extractMatches(targetTargetExpr):
               target = ConditionalAttackEffectTarget.Target
            extractMatches(selfTargetExpr):
               target = ConditionalAttackEffectTarget.Self
            extractMatches(cardTargetExpr):
               target = ConditionalAttackEffectTarget.Card
            warn &"Invalid conditional attack effect target: {str}"
      let effect = cv["effect"].readInto(GameEffect)
      let str = cv["kind"].asStr
      matcher(str):
         extractMatches(onHitKindExpr):
            e = ConditionalAttackEffect(kind: OnHit, target: target, effect: effect)
         extractMatches(onMissKindExpr):
            e = ConditionalAttackEffect(kind: OnMiss, target: target, effect: effect)
         warn &"Invalid conditional attack effect kind: {str}"
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
const expendRe = re"(?i)expend"
const changeFlagRe = re"(?ix)changeflag\((.+),(.+)\)"
const increaseFlagRe = re"(?ix)increaseflag\((.+),(.+)\)"

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
                  if num <= 0:
                     ge = GameEffect(kind: GameEffectKind.ChangeResource, resource: rsrcPool.get, resourceModifier: modifiers.reduce(-num))
                  else:
                     ge = GameEffect(kind: GameEffectKind.ChangeResource, resource: rsrcPool.get, resourceModifier: modifiers.recover(num))
               else:
                  let flagOpt = maybeTaxon("flags", word)
                  if flagOpt.isSome:
                     if num < 0:
                        ge = GameEffect(kind: GameEffectKind.ChangeFlag, flag: flagOpt.get, flagModifier: modifiers.sub(-num))
                     else:
                        ge = GameEffect(kind: GameEffectKind.ChangeFlag, flag: flagOpt.get, flagModifier: modifiers.add(num))
                  else:
                     warn &"unknown word(number) pattern for game effect: {word}, {numberStr}"
         extractMatches(simpleAttackPattern):
            ge = GameEffect(kind: GameEffectKind.SimpleAttack, attack: readInto(asConf(str), Attack))
         extractMatches(addCardRe, cardName):
            ge = GameEffect(kind: GameEffectKind.AddCard, cardChoices: @[taxon("card types", cardName)])
         extractMatches(expendRe):
            ge = GameEffect(kind: GameEffectKind.MoveCard, moveToLocation: some(CardLocation.ExpendPile))
         extractMatches(changeFlagRe, flag, amount):
            ge = GameEffect(kind: GameEffectKind.ChangeFlag, flag: taxon("flags", flag), flagModifier: readInto(asConf(amount), Modifier[int]))
         extractMatches(increaseFlagRe, flag, amount):
            ge = GameEffect(kind: GameEffectKind.ChangeFlag, flag: taxon("flags", flag), flagModifier: readInto(asConf(amount), Modifier[int]))
         warn &"Unknown string based game effect: {str}"
   elif cv.isObj:
      let kind = cv["kind"].asStr.toLowerAscii
      case kind:
      of "simpleattack":
         ge = GameEffect(kind: GameEffectKind.SimpleAttack, attack: readInto(cv, Attack))
      of "attack":
         ge = GameEffect(kind: GameEffectKind.Attack, attackSelector: readInto(cv["attackSelector"], AttackSelector), attackModifier: readInto(cv["attackModifier"], AttackModifier))
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
      readInto(cv["condition"], s.condition)

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
      DamageType(damageType):
         attack.damage.damageType.isA(damageType)
      FromWeapon(weapon, key):
         warn "FromWeapon(weapon,index) doesn't make sense when doing reverse matching"
         false
      CompoundAttackSelector(selectors):
         selectors.all(s => matches(s, view, attack))
      FromWeaponType(weaponType):
         # weaponType.all((x) => )
         warn "FromWeaponType(weaponType) not yet implemented for attack selector"
         false


proc applyModifiers*(attack: var Attack, modifier: AttackModifier) =
   modifier.attackTypes.apply(attack.attackTypes)
   modifier.damage.apply(attack.damage.fixed)
   modifier.bonusDamage.apply(attack.bonusDamage)
   modifier.minRange.apply(attack.minRange)
   modifier.maxRange.apply(attack.maxRange)
   modifier.accuracy.apply(attack.accuracy)
   modifier.strikeCount.apply(attack.strikeCount)
   modifier.actionCost.apply(attack.actionCost)
   modifier.staminaCost.apply(attack.staminaCost)
   modifier.target.apply(attack.target)
   modifier.additionalCosts.apply(attack.additionalCosts)
   modifier.conditionalEffects.apply(attack.conditionalEffects)
