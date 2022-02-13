import data
import game_prelude
import game/randomness
import game/flags
import noto


proc checkCondition*(world: LiveWorld, entity: Entity, condition: Condition): bool =
  case condition.kind:
    of ConditionKind.Attribute:
      if entity.hasData(Captain):
        entity[Captain].attributes.getOrDefault(condition.attribute) >= condition.minValue
      else:
        false
    of ConditionKind.Flag:
      if entity.hasData(Flags):
        let flagVal = entity[Flags].flagValue(condition.flag)
        condition.range.contains(flagVal)
      else:
        false
    of ConditionKind.Money:
      if entity.hasData(Captain):
        entity[Captain].money >= condition.amount
      else:
        false


proc randomFromRange*(world: LiveWorld, range: ClosedIntRange): int =
  var r = randomizer(world)
  r.nextInt(range.min, range.max+1)


proc applyEffect*(world: LiveWorld, entity: Entity, effect: Effect) =
  case effect.kind:
    of EffectKind.Damage:
      if entity.hasData(Character):
        entity[Character].health.reduceBy(randomFromRange(world, effect.amount))
      else: warn &"Attempting to apply damage to non-character: {entity}"
    of EffectKind.Terror:
      if entity.hasData(Captain):
        entity[Captain].terror += randomFromRange(world, effect.amount)
      else: warn &"Attempting to apply terror to non-captain: {entity}"
    of EffectKind.Crew:
      if entity.hasData(Captain):
        entity[Captain].crew += randomFromRange(world, effect.amount)
      else: warn &"Attempting to apply crew to non-captain: {entity}"
    of EffectKind.Money:
      if entity.hasData(Captain):
        entity[Captain].money += randomFromRange(world, effect.amount)
      else: warn &"Attempting to apply money to non-captain: {entity}"
    of EffectKind.Encounter:
      if entity.hasData(Captain):
        entity[Captain].encounterStack.add(effect.encounterNode)
      else: warn &"Attempting to apply encounter to non-captain: {entity}"
    of EffectKind.ChangeFlag:
      if entity.hasData(Flags):
        entity[Flags].flags[effect.flag] = entity[Flags].flags.getOrDefault(effect.flag) + effect.by
      else: warn &"Attempting to change flags on non-flagged entity: {entity}"
    of EffectKind.SetFlag:
      if entity.hasData(Flags):
        entity[Flags].flags[effect.flag] = entity[Flags].flags.getOrDefault(effect.flag) + effect.to
      else: warn &"Attempting to set flags on non-flagged entity: {entity}"
    of EffectKind.Quest:
      if entity.hasData(Captain):
        entity[Captain].quests.add(effect.quest)
      else: warn &"Attempting to set flags on non-flagged entity: {entity}"

proc isOptionAvailable*(world: LiveWorld, entity: Entity, opt: EncounterOption): bool =
  for r in opt.requirements:
    if not checkCondition(world, entity, r):
      return false
  true

proc visibleOptions*(world: LiveWorld, entity: Entity, encounter: Taxon) : seq[EncounterOption] =
  var results : seq[EncounterOption]
  let enc = library(EncounterNode)[encounter]
  for opt in enc.options:
    if not opt.hidden or isOptionAvailable(world, entity, opt):
      results.add(opt)

  results

proc availableOptions*(world: LiveWorld, entity: Entity, encounter: Taxon) : seq[EncounterOption] =
  var results : seq[EncounterOption]
  let enc = library(EncounterNode)[encounter]
  for opt in enc.options:
    if isOptionAvailable(world, entity, opt):
      results.add(opt)

  results

proc attributeValue*(world: LiveWorld, entity: Entity, attr: Taxon) : int =
  if entity.hasData(Captain):
    # todo: bonuses from gear, officers, etc
    entity[Captain].attributes.getOrDefault(attr)
  else:
    0

## Rolls the given number of dice and returns the number of successes
## based on the threshold given for what counts as success (default 5)
## returns the rolls and the number of successes
proc roll*(r: var Randomizer, dice: int, threshold: int = 5): (seq[int],int) =
  var successes = 0
  var rolls: seq[int]
  for i in 0 ..< dice:
    let roll = nextInt(r, 6) + 1
    if roll >= threshold:
      successes.inc
    rolls.add(roll)
  (rolls, successes)


proc successesToResult*(difficulty: int, successes: int): ChallengeResult =
  if successes < difficulty - 2:
    ChallengeResult.CriticalFailure
  elif successes < difficulty:
    ChallengeResult.Failure
  elif successes < difficulty + 2:
    ChallengeResult.Success
  else:
    ChallengeResult.CriticalSuccess


proc performChallenge*(world: LiveWorld, entity: Entity, challenge: Challenge): ChallengeCheck =
  case challenge.kind:
    of ChallengeKind.Attribute:
      if entity.hasData(Captain):
        let attr = attributeValue(world, entity, challenge.attribute)
        var r = randomizer(world)
        let (rolls, successes) = roll(r, attr)
        let check = ChallengeCheck(
          difficulty: challenge.difficulty,
          rolls: rolls,
          successes: successes,
          result: successesToResult(challenge.difficulty, successes)
        )
        world.addFullEvent(ChallengeCheckEvent(challenge: challenge, check: check))
        check
      else:
        warn &"Attribute challenge being performed by non-captain makes no sense: {entity}"
        ChallengeCheck()




proc chooseFromPossibleOutcomes(world: LiveWorld, outcomes: seq[EncounterOutcome]) : EncounterOutcome =
  if outcomes.isEmpty:
    warn &"Choosing from outcomes but none were specified"
    EncounterOutcome()
  else:
    var totalWeight = 0
    for o in outcomes:
      if o.weight != 0:
        totalWeight += o.weight
      else:
        totalWeight += 1

    var r = randomizer(world)
    var w = nextInt(r, totalWeight)
    for o in outcomes:
      if o.weight != 0:
        w -= o.weight
      else:
        w -= 1

      if w <= 0:
        return o

    outcomes[0]


proc min(a: ChallengeResult, b: ChallengeResult) : ChallengeResult =
  if ord(a) < ord(b): a
  else: b

proc determineOutcome*(world: LiveWorld, entity: Entity, enc: EncounterOption): EncounterOutcome =
  let possibleOutcomes = if enc.challenges.isEmpty:
    enc.onSuccess
  else:
    var challengeResult = ChallengeResult.CriticalSuccess
    for c in enc.challenges:
      challengeResult = min(challengeResult, performChallenge(world, entity, c).result)
    case challengeResult:
      of ChallengeResult.CriticalSuccess:
        if enc.onCriticalSuccess.nonEmpty:
          enc.onCriticalSuccess
        else:
          enc.onSuccess
      of ChallengeResult.Success:
        enc.onSuccess
      of ChallengeResult.CriticalFailure:
        if enc.onCriticalFailure.nonEmpty:
          enc.onCriticalFailure
        elif enc.onFailure.nonEmpty:
          enc.onFailure
        else:
          warn &"Option has challenge but only onSuccess outcomes: {enc}"
          enc.onSuccess
      of ChallengeResult.Failure:
        if enc.onFailure.nonEmpty:
          enc.onFailure
        else:
          warn &"Option has challenge but only onSuccess outcomes: {enc}"
          enc.onSuccess

  chooseFromPossibleOutcomes(world, possibleOutcomes)

