import tables
import game_prelude
import strutils
import noto
import windowingsystem/rich_text
import game/randomness
import game/flags
import graphics/taxonomy_display
import graphics/color

type
  EffectKind* {.pure.} = enum
    Encounter
    Damage
    Money
    ChangeFlag
    SetFlag
    Crew
    Terror
    Quest

  ConditionKind* {.pure.} = enum
    Attribute
    Flag
    Money

  OptionKind* {.pure.} = enum
    Choice
    Location

  EnemyForce* = object
    kind*: Taxon
    number*: int

  Effect* = object
    case kind* : EffectKind
    of EffectKind.Damage, EffectKind.Money, EffectKind.Terror, EffectKind.Crew:
      amount*: ClosedIntRange
    of EffectKind.ChangeFlag, EffectKind.SetFlag:
      flag*: Taxon
      by*: int
      to*: int
    of EffectKind.Encounter:
      encounterNode*: Taxon
    of EffectKind.Quest:
      quest*: Taxon


  Condition* = object
    case kind*: ConditionKind
    of ConditionKind.Attribute:
      attribute*: Taxon
      minValue*: int
    of ConditionKind.Flag:
      flag*: Taxon
      range*: IntRange
    of ConditionKind.Money:
      amount*: int

  EncounterNode* = object
    text*: RichText
    options*: seq[EncounterOption]

  EncounterOption* = object
    prompt*: RichText
    text*: RichText
    hidden*: bool
    kind*: OptionKind
    requirements*: seq[Condition]
    challenges*: seq[Challenge]
    onFailure*: seq[EncounterOutcome]
    onCriticalFailure*: seq[EncounterOutcome]
    onSuccess*: seq[EncounterOutcome]
    onCriticalSuccess*: seq[EncounterOutcome]

  EncounterOutcome* = object
    text*: RichText
    effects*: seq[Effect]
    conditions*: seq[Condition]
    weight*: int

  ChallengeKind* = enum
    Attribute
    Combat

  Challenge* = object
    case kind* : ChallengeKind:
      of ChallengeKind.Attribute:
        attribute*: Taxon
        difficulty*: int
      of ChallengeKind.Combat:
        enemies*: seq[EnemyForce]


  ChallengeCheck* = object
    difficulty*: int
    rolls*: seq[int]
    successes*: int
    result*: ChallengeResult

  ChallengeResult* {.pure.} = enum
    Success
    CriticalSuccess
    Failure
    CriticalFailure

  OutcomeAccessor* = object
    optionIndex*: int
    challengeResult*: ChallengeResult
    outcomeIndex*: int

  EncounterElement* = object
    node*: Option[Taxon]
    outcome*: Option[OutcomeAccessor]


  Captain* = object
    attributes*: Table[Taxon, int]
    money*: int
    activeOfficers*: seq[Entity]
    terror*: int
    crew*: int
    encounterStack*: seq[EncounterElement]
    quests*: seq[Taxon]
    deck*: Entity

  ResourcePools* = object
    resources*: Table[Taxon, Reduceable[int]]

  Officer* = object


  Character* = object
    name*: string
    health*: Reduceable[int]
    dead*: bool

  ChallengeCheckEvent* = ref object of GameEvent
    challenge*: Challenge
    check*: ChallengeCheck


  # Combatant* = object
  #   name*: string
  #   health*: Reduceable[int]
    
  EnemyCombatant* = object
    intent*: string
    lastIntent*: Option[string]
    actions*: Table[string, EnemyAction]
    xp*: int

  EnemyArchetype* = object
    name*: string
    actions*: Table[string, EnemyAction]
    xp*: int
    health*: DiceExpression

  EnemyAction* = object
    effects*: seq[CardEffect]
    weight*: float

  Column* = object
    combatants*: seq[Entity]
    blockAmount*: int

  TacticalSide* {.pure.} = enum
    Friendly
    Enemy

  TacticalBoard* = object
    sides*: array[2, Table[int, Column]]
    activated*: Entity
    friendlyTurn*: bool

  CardEffectKind* {.pure.} = enum
    Damage
    Block
    Move
    WorldEffect
    ApplyFlag
    Activate

  TacticalDirection* {.pure.} = enum
    Left
    Right
    Forward
    Back
    
  CardEffectTargetKind* {.pure.} = enum
    Self
    Enemy
    Enemies
    Allies
    Direction
    
  CardEffectTarget* = object
    ranged*: bool
    case kind*: CardEffectTargetKind
    of CardEffectTargetKind.Self, CardEffectTargetKind.Enemy, CardEffectTargetKind.Enemies, CardEffectTargetKind.Allies:
      discard
    of CardEffectTargetKind.Direction:
      direction*: TacticalDirection

  CardEffect* = object
    target*: CardEffectTarget
    case kind*: CardEffectKind
    of CardEffectKind.Damage:
      damageAmount*: int
    of CardEffectKind.Block:
      blockAmount*: int
    of CardEffectKind.Move:
      distance*: int
      direction*: TacticalDirection
    of CardEffectKind.WorldEffect:
      effect*: Effect
    of CardEffectKind.ApplyFlag:
      flag*: Taxon
      flagAmount*: int
    of CardEffectKind.Activate:
      discard


  CardEffectGroup* = object
    name*: string
    costs*: seq[CardCost]
    effects*: seq[CardEffect]

  CardCostKind* {.pure.} = enum
    Energy

  CardCost* = object
    case kind*: CardCostKind
    of CardCostKind.Energy:
      energyAmount*: int

  Card* = object
    effectGroups*: seq[CardEffectGroup]
    archetype*: Taxon

  CardArchetype* = object
    name*: string
    effectGroups*: seq[CardEffectGroup]


  CardEffectResolvedEvent* = ref object of GameEvent
    entity*: Entity
    effect*: CardEffect
    targets*: seq[Entity]

  CardPlayedEvent* = ref object of GameEvent
    entity*: Entity
    card*: Entity

  EncounterOptionChosenEvent* = ref object of GameEvent
    entity*: Entity
    option*: EncounterOption

  EncounterOutcomeContinueEvent* = ref object of GameEvent
    entity*: Entity

  IntentChosenEvent* = ref object of GameEvent
    entity*: Entity
    intent*: string



defineReflection(Captain)
defineReflection(ResourcePools)
defineReflection(Character)
defineReflection(Officer)
# defineReflection(Combatant)
defineReflection(EnemyCombatant)
defineReflection(Card)
defineReflection(TacticalBoard)

eventToStr(IntentChosenEvent)
eventToStr(EncounterOutcomeContinueEvent)
eventToStr(EncounterOptionChosenEvent)
eventToStr(CardPlayedEvent)
eventToStr(CardEffectResolvedEvent)


proc `$`*(c: EnemyForce) : string =
  &"{c.kind} x{c.number}"

proc `$`*(c: Challenge) : string =
  case c.kind:
    of ChallengeKind.Attribute:
      &"AttributeChallenge({c.attribute}, {c.difficulty})"
    of ChallengeKind.Combat:
      &"CombatChallenge({c.enemies})"

proc `$`*(e: Effect) : string =
  case e.kind:
    of EffectKind.Encounter:
      &"Encounter({e.encounterNode})"
    of EffectKind.Quest:
      &"Quest({e.quest})"
    of EffectKind.ChangeFlag:
      &"ChangeFlag({e.flag},{e.by})"
    of EffectKind.Money, EffectKind.Crew, EffectKind.Damage, EffectKind.Terror:
      let verb = if e.amount.min > 0: "Gain" else: "Lose"
      let noun = case e.kind:
        of EffectKind.Money: "Money"
        of EffectKind.Crew: "Crew"
        of EffectKind.Damage: "Damage"
        of EffectKind.Terror: "Terror"
        else: "Unknown"

      if e.amount.min == e.amount.max:
        &"{verb}{noun}({abs(e.amount.min)})"
      else:
        &"Gain{noun}({e.amount.min} - {e.amount.max})"
    of EffectKind.SetFlag:
      &"SetFlag({e.flag}, to: {e.to})"


proc flagToRichText*(flag: Taxon): RichText =
  library(TaxonomyDisplay).get(flag).flatMapIt(it.text).get(richText(flag.displayName))

proc toRichText*(world: LiveWorld, e: Effect, entity: Entity, presentTense: bool): RichText =
  case e.kind:
    of EffectKind.Encounter:
      richText(&"Encounter({e.encounterNode})")
    of EffectKind.Quest:
      richText(&"You have gained a Quest")
    of EffectKind.ChangeFlag:
      let newValue = entity[Flags].flagValue(e.flag)

      let verb = if e.by > 0:
        if presentTense: "Gain" else: "Gained"
      else:
        if presentTense: "Lose" else: "Lost"

      let flagDisp = flagToRichText(e.flag)
      var t = richText(&"{verb} ")
      t.add(flagDisp)
      t.add(richText(&", now {newValue}"))
      t
    of EffectKind.Money, EffectKind.Crew, EffectKind.Damage, EffectKind.Terror:
      let verb = if e.amount.min > 0:
        if e.kind == EffectKind.Damage:
          if presentTense: "Take" else: "Took"
        else:
          if presentTense: "Gain" else: "Gained"
      else:
        if e.kind == EffectKind.Damage:
          if presentTense: "Heal" else: "Healed"
        else:
          if presentTense: "Lose" else: "Lost"
      let noun = case e.kind:
        of EffectKind.Money: richText("Money", color = some(rgba(241,196,60,255)))
        of EffectKind.Crew: richText("Crew", color = some(rgba(198,171,92,255)))
        of EffectKind.Damage: richText("Damage", color = some(rgba(200,100,100,255)))
        of EffectKind.Terror: richText("Terror", color = some(rgba(290,19,60,255)))
        else: richText("Unknown")

      let endValue = case e.kind:
        of EffectKind.Money: entity[Captain].money
        of EffectKind.Crew: entity[Captain].crew
        of EffectKind.Damage: entity[Character].health.currentValue
        of EffectKind.Terror: entity[Captain].terror
        else: 0

      var t = richText(&"{verb} {e.amount.min.abs} ")
      t.add(noun)
      t.add(richText(&", now {endValue}"))
      t
    of EffectKind.SetFlag:
      richText(&"{e.flag} is now {e.to}")


proc toRichText*(world: LiveWorld, e: CardEffect, entity: Entity): RichText =
  # TODO: incorporate targeting, that's kind of important
  case e.kind:
    of CardEffectKind.Damage: richText(&"{e.damageAmount} Damage")
    of CardEffectKind.Block: richText(&"{e.blockAmount} Block")
    of CardEffectKind.Move: richText(&"Move {($e.direction).capitalize}")
    of CardEffectKind.WorldEffect: toRichText(world, e.effect, entity, true)
    of CardEffectKind.ApplyFlag:
      var t = richText("Apply {e.flagAmount} ")
      t.add(flagToRichText(e.flag))
      t
    of CardEffectKind.Activate:
      richText("Activate")

proc outcomes*(opt: EncounterOption, res : ChallengeResult): seq[EncounterOutcome] =
  case res:
    of ChallengeResult.CriticalFailure:
      if opt.onCriticalFailure.nonEmpty: opt.onCriticalFailure
      elif opt.onFailure.nonEmpty: opt.onFailure
      else:
        warn &"challenge result was a critical failure, but no on failure handling at all {opt}"
        opt.onSuccess
    of ChallengeResult.CriticalSuccess:
      if opt.onCriticalSuccess.nonEmpty: opt.onCriticalSuccess
      else: opt.onSuccess
    of ChallengeResult.Success: opt.onSuccess
    of ChallengeResult.Failure:
      if opt.onFailure.nonEmpty: opt.onFailure
      else:
        warn &"challenge result was a failure, but no on failure handling {opt}"
        opt.onSuccess

proc outcome*(node: ref EncounterNode, acc: OutcomeAccessor): EncounterOutcome =
  if node.options.len > acc.optionIndex:
    let opt = node.options[acc.optionIndex]
    let oc = outcomes(opt, acc.challengeResult)
    if oc.len > acc.outcomeIndex:
      return oc[acc.outcomeIndex]
  warn &"Encounter outcome accessor was not in bounds {node[]}, {acc}"
  EncounterOutcome(text: richText("Not found"))


proc readFromConfig*(cv: ConfigValue, c: var Condition) =
  if cv.isArr:
    let arr = cv.asArr
    if arr.len > 1:
      let kind = arr[0].asStr
      case kind.toLowerAscii:
        of "money": c = Condition(kind: ConditionKind.Money, amount : arr[1].asInt)
        else:
          let attrOpt = maybeTaxon("Attributes", kind)
          if attrOpt.isSome:
            c = Condition(kind: ConditionKind.Attribute, attribute: attrOpt.get, minValue: arr[1].asInt)
          else:
            let t = findTaxon(kind)
            if t != UnknownThing:
              c = Condition(kind: ConditionKind.Flag, flag: t, range: arr[1].readInto(IntRange))
            else:
              warn &"Unknown taxon for condition: {cv}"
    else:
      warn &"Insufficiently sized condition array in config?: {cv}"
  elif cv.isStr:
    warn &"unknown taxon for condition: {cv}"
  else:
    warn &"Invlid condition config value: {cv}"


proc readFromConfig*(cv: ConfigValue, c: var Challenge) =
  if cv.isArr:
    let arr = cv.asArr
    if arr.len > 0:
      let kind = arr[0].asStr
      if kind.toLowerAscii == "combat":
        # i.e. [combat, 3, slimes]
        if arr.len == 3:
          let count = arr[1].asInt
          let enemyKind = maybeTaxon("enemies", arr[2].asStr)
          if enemyKind.isSome:
            c = Challenge(kind: ChallengeKind.Combat, enemies: @[EnemyForce(kind: enemyKind.get, number: count)])
          else:
            warn &"Unknown enemy kind for combat: {arr[2].asStr}"
      else:
        let attrOpt = maybeTaxon("Attributes",kind)
        if attrOpt.isSome:
          if arr.len > 1:
            c = Challenge(kind: ChallengeKind.Attribute, attribute: attrOpt.get, difficulty: arr[1].asInt)
          else:
            warn &"Attribute challenge should have a difficulty supplied, defaulting to 1"
            c = Challenge(kind: ChallengeKind.Attribute, attribute: attrOpt.get, difficulty: 1)
        else:
          warn &"Unknown kind of challenge: {cv}"
    else:
      warn &"Empty challenge array in config?: {cv}"
  else:
    warn &"Unknown config format for challenge: {cv}"

proc readFromConfig*(cv: ConfigValue, o: var Effect) =
  if cv.isArr:
    let arr = cv.asArr
    if arr.len > 0:
      let kind = arr[0].asStr
      case kind.toLowerAscii:
        of "money": o = Effect(kind: EffectKind.Money, amount: arr[1].readInto(ClosedIntRange))
        of "crew": o = Effect(kind: EffectKind.Crew, amount: arr[1].readInto(ClosedIntRange))
        of "terror": o = Effect(kind: EffectKind.Terror, amount: arr[1].readInto(ClosedIntRange))
        of "damage": o = Effect(kind: EffectKind.Damage, amount: arr[1].readInto(ClosedIntRange))
        else:
          let t = findTaxon(kind)
          if t != UnknownThing:
            if t.isA(† Quality) or t.isA(† Occurrence):
              if arr.len == 2:
                let arg = if arr[1].isNumber:
                  some(arr[1].asInt)
                elif arr[1].isStr:
                  parseIntOpt(arr[1].asStr)
                else:
                  none(int)

                if arg.isSome:
                  o = Effect(kind: EffectKind.ChangeFlag, flag: t, by: arg.get)
                else:
                  warn &"non-integer argument to flag effect: {cv}"
            elif t.isA(† Encounter):
              o = Effect(kind: EffectKind.Encounter, encounterNode: t)
            elif t.isA(† Quest):
              o = Effect(kind: EffectKind.Quest, quest: t)
            else:
              warn &"Unknown kind of taxon in effect: {t}, overall config: {cv}"
          else:
            warn &"Unknown taxon in effect: {kind}. Overall config: {cv}"
    else:
      warn &"Empty array for effect config?"
  elif cv.isStr:
    let t = findTaxon(cv.asStr)
    if t.isA(† Encounter):
      o = Effect(kind: EffectKind.Encounter, encounterNode: t)
    elif t.isA(† Quest):
      o = Effect(kind: EffectKind.Quest, quest: t)
  else:
    warn &"Unknown effect config {cv}"

proc readFromConfig*(cv: ConfigValue, o: var EncounterOutcome) =
  if cv.isObj:
    cv["text"].readInto(o.text)
    if cv["effect"].nonEmpty:
      o.effects = @[cv["effect"].readInto(Effect)]
    else:
      cv["effects"].readInto(o.effects)

    if cv["condition"].nonEmpty:
      o.conditions = @[cv["condition"].readInto(Condition)]
    else:
      cv["conditions"].readInto(o.conditions)

    cv["weight"].readInto(o.weight)
  elif cv.isArr:
    cv.readInto(o.effects)
  elif cv.isStr:
    let t = findTaxon(cv.asStr)
    if t.isA(† Encounter):
      o.effects = @[Effect(kind: EffectKind.Encounter, encounterNode: t)]
    else:
      warn &"Invalid single-string outcome: {cv} (resolved to {t})"
  else: warn &"Invalid format for outcome in config: {cv}"

proc readOutcomes*(cv: ConfigValue, o: var seq[EncounterOutcome]) =
  if cv.isArr:
    var anyObj = false
    for v in cv.asArr:
      if v.isObj: anyObj = true
    if not anyObj:
      o = @[readInto(cv, EncounterOutcome)]
    else:
      readInto(cv, o)
  else:
    o = @[readInto(cv, EncounterOutcome)]

proc readFromConfig*(cv: ConfigValue, enc: var EncounterOption) =
  cv["prompt"].readInto(enc.prompt)
  cv["text"].readInto(enc.text)
  cv["hidden"].readInto(enc.hidden)
  if cv["requirement"].nonEmpty:
    enc.requirements = @[cv["requirement"].readInto(Condition)]
  else:
    cv["requirements"].readInto(enc.requirements)

  if cv["challenge"].nonEmpty:
    enc.challenges = @[cv["challenge"].readInto(Challenge)]
  else:
    cv["challenges"].readInto(enc.challenges)

  if cv["onSuccess"].nonEmpty:
    readOutcomes(cv["onSuccess"], enc.onSuccess)
  if cv["onFailure"].nonEmpty:
    readOutcomes(cv["onFailure"], enc.onFailure)
  if cv["next"].nonEmpty:
    readOutcomes(cv["next"], enc.onSuccess)

  if cv["kind"].nonEmpty:
    case cv["kind"].asStr.toLowerAscii:
      of "choice": enc.kind = OptionKind.Choice
      of "location": enc.kind = OptionKind.Location
      else: warn &"Invalid option kind: {cv}"




proc readFromConfig*(cv: ConfigValue, enc: var EncounterNode) =
  cv["text"].readInto(enc.text)
  cv["options"].readInto(enc.options)

proc parseTacticalDirectionOpt*(str: string): Option[TacticalDirection] =
  case str.toLowerAscii:
    of "left": some(TacticalDirection.Left)
    of "right": some(TacticalDirection.Right)
    of "back": some(TacticalDirection.Back)
    of "forward": some(TacticalDirection.Forward)
    else: none(TacticalDirection)

proc parseTargetOpt*(str: string, allowDir: bool = true): Option[CardEffectTarget] =
  case str.toLowerAscii:
    of "self": some(CardEffectTarget(kind: CardEffectTargetKind.Self))
    of "enemy": some(CardEffectTarget(kind: CardEffectTargetKind.Enemy))
    of "enemies": some(CardEffectTarget(kind: CardEffectTargetKind.Enemies))
    of "allies": some(CardEffectTarget(kind: CardEffectTargetKind.Allies))
    else:
      let dir = parseTacticalDirectionOpt(str)
      if allowDir and dir.isSome:
        some(CardEffectTarget(kind: CardEffectTargetKind.Direction, direction: dir.get))
      else:
        none(CardEffectTarget)

proc extractTarget*(arr: seq[ConfigValue], allowDir: bool = true): (Option[CardEffectTarget], seq[ConfigValue]) =
  var remainingConfig : seq[ConfigValue]
  var targetResult = none(CardEffectTarget)
  var ranged = false
  for i in 0 ..< arr.len:
    if arr[i].isStr:
      let str = arr[i].asStr
      if str.toLowerAscii == "ranged":
        ranged = true
      else:
        let o = parseTargetOpt(str, allowDir)
        if o.isSome:
          targetResult = o
        else:
          remainingConfig.add(arr[i])
    else:
      remainingConfig.add(arr[i])
  (targetResult, remainingConfig)


proc readFromConfig*(cv: ConfigValue, e: var CardCost) =
  if cv.isArr:
    let arr = cv.asArr
    if arr.len < 2: warn &"array <2 len for card cost makes no sense"
    else:
      let kind = case arr[0].asStr.toLowerAscii:
        of "energy": CardCostKind.Energy
        else:
          warn &"Unknown kind for effect {arr}"
          CardCostKind.Energy

      case kind:
        of CardCostKind.Energy:
          let amount = arr[1].asInt
          e = CardCost(kind: kind, energyAmount: amount)
  else:
    warn &"Non-array config for card cost {cv}"

proc readFromConfig*(cv: ConfigValue, e: var CardEffect) =
  if cv.isArr:
    let arr = cv.asArr
    if arr.len < 2: warn &"array <2 len for card effect makes no sense"
    else:
      let kind = case arr[0].asStr.toLowerAscii:
        of "damage": CardEffectKind.Damage
        of "block": CardEffectKind.Block
        of "move": CardEffectKind.Move
        of "worldeffect", "world effect": CardEffectKind.WorldEffect
        of "applyflag", "apply flag": CardEffectKind.ApplyFlag
        of "activate": CardEffectKind.Activate
        else:
          warn &"Unknown kind for effect {arr}"
          CardEffectKind.Block

      case kind:
        of CardEffectKind.Damage:
          let (target, rem) = extractTarget(arr)
          let amount = rem[1].asInt
          e = CardEffect(kind: kind, damageAmount: amount, target: target.get(CardEffectTarget(kind: CardEffectTargetKind.Enemy)))
        of CardEffectKind.Block:
          let (target, rem) = extractTarget(arr)
          let amount = rem[1].asInt
          e = CardEffect(kind: kind, blockAmount: amount, target: target.get(CardEffectTarget(kind: CardEffectTargetKind.Self)))
        of CardEffectKind.Move:
          let (target, rem) = extractTarget(arr, allowDir = false)
          let dirOpt = parseTacticalDirectionOpt(rem[1].asStr)
          if dirOpt.isNone: warn &"Invalid direction for move effect: {rem[1].asStr}"
          let dir = dirOpt.get(TacticalDirection.Left)
          let distance = if rem.len > 2 and rem[2].isNumber: rem[2].asInt else: 1
          e = CardEffect(kind: kind, distance: distance, direction: dir, target: target.get(CardEffectTarget(kind: CardEffectTargetKind.Self)))
        of CardEffectKind.ApplyFlag:
          let (target, rem) = extractTarget(arr)
          let flag = findTaxon(rem[1].asStr)
          let amount = rem[2].asInt
          e = CardEffect(kind: kind, flag: flag, flagAmount: amount, target: target.get(CardEffectTarget(kind: CardEffectTargetKind.Enemy)))
        of CardEffectKind.WorldEffect:
          warn &"Arbitrary world effects not yet supported for cardeffect deserialization {cv}"
        of CardEffectKind.Activate:
          let (target, rem) = extractTarget(arr)
          if target.isSome:
            e = CardEffect(kind: kind, target: target.get)
          else:
            warn &"Activate ability must have explicitly indicated target"

  else:
    warn &"Non-array config for effect {cv}"

defineSimpleReadFromConfig(CardEffectGroup)
defineSimpleReadFromConfig(EnemyAction)
defineSimpleReadFromConfig(EnemyArchetype)

# proc readFromConfig*(cv: ConfigValue, e: var CardEffectGroup) =
#   cv["name"].readInto(e.name)
#   cv["costs"].readInto(e.costs)
#   cv["effects"].readInto(e.effects)

proc readFromConfig*(cv: ConfigValue, ct: var CardArchetype) =
  if cv["effectGroups"].nonEmpty:
    cv["effectGroups"].readInto(ct.effectGroups)
  else:
    cv.readInto(ct.effectGroups)
  cv["name"].readInto(ct.name)


defineSimpleLibrary[EncounterNode]("hexcrawl/encounters/mod.sml", "Encounters")
defineSimpleLibrary[CardArchetype]("hexcrawl/game/cards/mod.sml", "Cards")
defineSimpleLibrary[EnemyArchetype]("hexcrawl/game/enemies/mod.sml", "Enemies")


template `[]`*(arr: array[2, Table[int, Column]], s: TacticalSide): var Table[int, Column] =
  arr[s.ord]