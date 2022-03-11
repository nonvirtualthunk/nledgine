import data
import game_prelude
import game/randomness
import game/flags
import noto
import game/cards





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
        entity[Captain].encounterStack.add(EncounterElement(node: some(effect.encounterNode)))
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
    of ChallengeKind.Combat:
      warn &"Combat challenges need to be resolved outside of a simple performChallenge(...) call"
      ChallengeCheck()




proc chooseFromPossibleOutcomes*(world: LiveWorld, outcomes: seq[EncounterOutcome]) : int =
  if outcomes.isEmpty:
    warn &"Choosing from outcomes but none were specified"
    -1
  else:
    var totalWeight = 0
    for o in outcomes:
      if o.weight != 0:
        totalWeight += o.weight
      else:
        totalWeight += 1

    var r = randomizer(world)
    var w = nextInt(r, totalWeight)
    for i in 0 ..< outcomes.len:
      let o = outcomes[i]
      if o.weight != 0:
        w -= o.weight
      else:
        w -= 1

      if w <= 0:
        return i

    0


proc min(a: ChallengeResult, b: ChallengeResult) : ChallengeResult =
  if ord(a) < ord(b): a
  else: b

proc determineChallengeResult*(world: LiveWorld, entity: Entity, enc: EncounterOption): ChallengeResult =
  let rawResult = if enc.challenges.isEmpty:
    ChallengeResult.Success
  else:
    var challengeResult = ChallengeResult.CriticalSuccess
    for c in enc.challenges:
      challengeResult = min(challengeResult, performChallenge(world, entity, c).result)
    challengeResult

proc determineOutcome*(world: LiveWorld, entity: Entity, enc: EncounterOption, challengeResult: ChallengeResult): EncounterOutcome =
  let possibleOutcomes = outcomes(enc, challengeResult)

  let outcomeIndex = chooseFromPossibleOutcomes(world, possibleOutcomes)
  possibleOutcomes[outcomeIndex]



proc createCard*(world: LiveWorld, cardType: Taxon) : Entity =
  let archetype = library(CardArchetype)[cardType]
  let card = world.createEntity()
  card.attachData(Card(
    archetype: cardType,
    effectGroups: archetype.effectGroups
  ))
  card.attachData(Identity(
    kind: cardType,
    name: some(archetype.name)
  ))
  card





#=========================================================================================#
#                                 Tactical
#=========================================================================================#

proc tacticalBoard*(world: LiveWorld) : ref TacticalBoard =
  var board: Entity
  for ent in world.entitiesWithData(TacticalBoard):
    board = ent
  if board.isSentinel:
    board = world.createEntity()
    board.attachData(TacticalBoard())
  board[TacticalBoard]

proc oppositeSide*(side: TacticalSide) : TacticalSide =
  case side:
    of TacticalSide.Enemy: TacticalSide.Friendly
    of TacticalSide.Friendly: TacticalSide.Enemy

proc positionOf*(board: ref TacticalBoard, entity: Entity): (TacticalSide, int, int) =
  for side in enumValues(TacticalSide):
    for k, col in board.sides[side.ord]:
      for i in 0 ..< col.combatants.len:
        if col.combatants[i] == entity:
          return (side, k, i)
  warn &"positionOf(...) called for entity not present on board: {entity}"
  (TacticalSide.Enemy, 0, 0)

proc mcolumnAt*(board: ref TacticalBoard, x: int, side: TacticalSide): var Column =
  board.sides[side.ord].mgetOrPut(x, Column())

proc columnAt*(board: ref TacticalBoard, x: int, side: TacticalSide): Column =
  board.sides[side.ord].getOrDefault(x)

proc nonEmpty*(col: Column): bool = col.combatants.nonEmpty
proc isEmpty*(col: Column): bool = col.combatants.isEmpty


proc closestOccupiedColumnTo*(board: ref TacticalBoard, x: int, side: TacticalSide): int =
  for dx in 0 ..< 100:
    if columnAt(board, x - dx, side).nonEmpty:
      return x - dx
    elif columnAt(board, x + dx, side).nonEmpty:
      return x + dx
  warn &"Could not find occupied column: {x}, {side}"

proc closestOccupiedColumnInDirection*(board: ref TacticalBoard, x: int, side: TacticalSide, dx: int): Option[int] =
  for d in 1 ..< 20:
    if columnAt(board, x + d * dx, side).nonEmpty:
      return some(x + d * dx)
  none(int)


proc entitiesOnSide*(board: ref TacticalBoard, side: TacticalSide): seq[Entity] =
  for k,c in board.sides[side.ord]:
    result.add(c.combatants)


proc activate*(world: LiveWorld, board: ref TacticalBoard, entity: Entity) =
  board.activated = entity

proc applyFlag*(world: LiveWorld, src: Entity, entity: Entity, flag: Taxon, flagAmount: int) =
  entity[Flags].changeFlagValue(flag, flagAmount)

proc characterDied*(world: LiveWorld, entity: Entity) =
  entity[Character].dead = true
  let board = tacticalBoard(world)
  for t in board.sides.mitems:
    for k, col in t.mpairs:
      if col.combatants.contains(entity):
        col.combatants.deleteValue(entity)

proc doDamage*(world: LiveWorld, src: Entity, entity: Entity, damage: int) =
  let board = tacticalBoard(world)
  let (side, x, y) = positionOf(board, entity)
  let blockAmount = columnAt(board, x, side).blockAmount
  mcolumnAt(board, x, side).blockAmount = (blockAmount - damage).max(0)
  let remainingDamage = damage - blockAmount
  if remainingDamage > 0:
    entity[Character].health.reduceBy(damage)
  if entity[Character].health.currentValue <= 0:
    characterDied(world, entity)

template isDead*(ent: Entity) : bool = ent[Character].dead

proc gainBlock*(world: LiveWorld, src: Entity, entity: Entity, blockAmount: int) =
  let board = tacticalBoard(world)
  let (side, x, y) = positionOf(board, entity)
  mcolumnAt(board, x, side).blockAmount += blockAmount


proc canPayResource*(world: LiveWorld, entity: Entity, resource: Taxon, amount: int): bool =
  if not entity.hasData(ResourcePools):
    warn &"canPayResource(...) called for entity without resource pools {entity}"
    return false
  let rp = entity[ResourcePools]
  if not rp.resources.contains(resource):
    warn &"canPayResource(...) called for entity without the appropriate resource {entity}"
    return false
  rp.resources[resource].currentValue >= amount

proc payResource*(world: LiveWorld, entity: Entity, resource: Taxon, amount: int) : bool {.discardable.} =
  if canPayResource(world, entity, resource, amount):
    entity[ResourcePools].resources[resource].reduceBy(amount)
    true
  else:
    false

proc recoverResource*(world: LiveWorld, entity: Entity, resource: Taxon, amount: int) =
  if canPayResource(world, entity, resource, -100000):
    entity[ResourcePools].resources[resource].recoverBy(amount)

proc canPayCost*(world: LiveWorld, entity: Entity, cost: CardCost): bool =
  case cost.kind:
    of CardCostKind.Energy:
      canPayResource(world, entity, † ResourcePools.Energy, cost.energyAmount)

proc applyCardCost*(world: LiveWorld, entity: Entity, cost: CardCost): bool {.discardable.} =
  if canPayCost(world, entity, cost):
    case cost.kind:
      of CardCostKind.Energy: payResource(world, entity, † ResourcePools.Energy, cost.energyAmount)
    true
  else:
    false


proc applyCardEffect*(world: LiveWorld, entity: Entity, effect: CardEffect) =
  if isDead(entity): return

  let board = tacticalBoard(world)
  let (side, x, y) = positionOf(board, entity)
  let targets : seq[Entity] = case effect.target.kind:
    of CardEffectTargetKind.Self: @[entity]
    of CardEffectTargetKind.Enemy:
      let closestOppositeX = closestOccupiedColumnTo(board, x, oppositeSide(side))
      @[columnAt(board, closestOppositeX, oppositeSide(side)).combatants[0]]
    of CardEffectTargetKind.Enemies:
      entitiesOnSide(board, oppositeSide(side))
    of CardEffectTargetKind.Allies:
      entitiesOnSide(board, side)
    of CardEffectTargetKind.Direction:
      case effect.target.direction:
        of TacticalDirection.Left:
          let leftX = closestOccupiedColumnInDirection(board, x, side, -1)
          if leftX.isSome: @[columnAt(board, leftX.get, side).combatants[0]]
          else: @[]
        of TacticalDirection.Right:
          let rightX = closestOccupiedColumnInDirection(board, x, side, 1)
          if rightX.isSome: @[columnAt(board, rightX.get, side).combatants[0]]
          else: @[]
        of TacticalDirection.Forward:
          if y > 0: @[columnAt(board, x, side).combatants[y-1]]
          else: @[]
        of TacticalDirection.Back:
          let col = columnAt(board, x, side)
          if col.combatants.len > y + 1: @[col.combatants[y + 1]]
          else: @[]

  world.eventStmts(CardEffectResolvedEvent(effect: effect, entity: entity, targets: targets)):
    case effect.kind:
      of CardEffectKind.Activate:
        if targets.nonEmpty:
          activate(world, board, targets[0])
      of CardEffectKind.ApplyFlag:
        for t in targets:
          applyFlag(world, entity, t, effect.flag, effect.flagAmount)
      of CardEffectKind.WorldEffect:
        warn &"World effects on card effects not yet implemented"
      of CardEffectKind.Damage:
        for t in targets:
          doDamage(world, entity, t, effect.damageAmount)
      of CardEffectKind.Block:
        for t in targets:
          gainBlock(world, entity, t, effect.blockAmount)
      of CardEffectKind.Move:
        warn &"Move effects not yet implemented"


proc formDeck*(world: LiveWorld, captain:Entity) =
  let deck = captain[Captain].deck
  clearDeck(world, deck)

  var cardSources = @[captain]
  cardSources.add(captain[Captain].activeOfficers)
  for src in cardSources:
    let cards = src[CardCollection].activeCards
    for card in cards:
      addCardTo(world, deck, card, † CardLocations.DrawPile)

  shuffle(world, deck, † CardLocations.DrawPile)


proc drawCard*(world: LiveWorld, deck: Entity) =
  let d = deck[Deck]
  # if we're out of draw, shuffle our discard back into the draw pile
  if d.drawPile.isEmpty:
    moveAllCardsFrom(world, deck, † CardLocations.DiscardPile, † CardLocations.DrawPile, CardMovePosition.Shuffle)
  # if we now have any cards to draw
  if d.drawPile.nonEmpty:
    let cardToDraw = d.drawPile[^1]
    moveCardTo(world, deck, cardToDraw, † CardLocations.Hand)

proc chooseIntent*(world: LiveWorld, enemy: Entity) =
  let ec = enemy[EnemyCombatant]
  var sumWeight = 0.0
  for k, action in ec.actions:
    sumWeight += max(action.weight, 1.0)
  var r = randomizer(world)
  var v = r.nextFloat(sumWeight)
  for k, action in ec.actions:
    if v <= action.weight:
      if ec.intent.nonEmpty:
        ec.lastIntent = some(ec.intent)
      ec.intent = k
      break
    v -= action.weight


proc startTurn*(col: var Column) =
  col.blockAmount = 0

proc startCaptainTurn*(world: LiveWorld, captain: Entity) =
  let deck = captain[Captain].deck
  moveAllCardsFrom(world, deck, † CardLocations.Hand, † CardLocations.DiscardPile)

  for i in 0 ..< 5: drawCard(world, deck)

  let board = tacticalBoard(world)
  for x, col in board.sides[TacticalSide.Friendly.ord].mpairs: startTurn(col)
  # TODO: increment/decrement flags and suchlike

proc endCaptainTurn*(world: LiveWorld, captain: Entity) =
  tacticalBoard(world).friendlyTurn = false


proc startEnemyTurn*(world: LiveWorld) =
  let board = tacticalBoard(world)
  for x, col in board.sides[TacticalSide.Enemy.ord].mpairs: startTurn(col)

proc performEnemyTurn*(world: LiveWorld, enemy: Entity) =
  let ec : ref EnemyCombatant = enemy[EnemyCombatant]
  let action = ec.actions[ec.intent]
  for effect in action.effects:
    applyCardEffect(world, enemy, effect)
  chooseIntent(world, enemy)

proc performEnemyTurn*(world: LiveWorld) =
  let board = tacticalBoard(world)
  for x, col in board.sides[TacticalSide.Enemy]:
    for enemy in col.combatants:
      performEnemyTurn(world, enemy)


proc resetTacticalBoard*(world: LiveWorld) =
  let board = tacticalBoard(world)
  for i in 0 ..< 2:
    board.sides[i].clear()

proc setupTacticalBoard*(world: LiveWorld, captain: Entity, enemies: seq[Entity]) =
  resetTacticalBoard(world)
  formDeck(world, captain)

  let board = tacticalBoard(world)
  for x in 0 ..< enemies.len:
    board.sides[TacticalSide.Enemy][x] = Column(combatants: @[enemies[x]])

  let friends = @[captain] & captain[Captain].activeOfficers

  let offset = (board.sides[TacticalSide.Enemy].len - friends.len) div 2
  for x in 0 ..< friends.len:
    board.sides[TacticalSide.Friendly][x + offset] = Column(combatants: @[friends[x]])

  startCaptainTurn(world, captain)




proc createEnemy*(world: LiveWorld, enemyKind: Taxon): Entity =
  let enemy = world.createEntity()

  let arch = library(EnemyArchetype).getOrDefault(enemyKind, † Enemies.Slime)
  var r = randomizer(world)

  enemy.attachData(EnemyCombatant(
    actions: arch.actions,
    xp: arch.xp
  ))
  enemy.attachData(Character(
    name: arch.name,
    health: reduceable(arch.health.rollInt(r))
  ))
  enemy.attachData(Flags())

  chooseIntent(world, enemy)

  enemy



proc placeOnBoard*(world: LiveWorld, ent: Entity, side: TacticalSide, x: Option[int] = none(int)) =
  let board : ref TacticalBoard = tacticalBoard(world)
  # if x isn't specified, walk from 0 rightward until you find something
  if x.isNone:
    var x = 0
    while x < 100:
      if columnAt(board, x, side).combatants.isEmpty:
        mcolumnAt(board, x, side).combatants.add(ent)
        break
      x.inc
  else:
    mcolumnAt(board, x.get, side).combatants.add(ent)

proc placeEnemyOnBoard*(world: LiveWorld, enemy: Entity) =
  placeOnBoard(world, enemy, TacticalSide.Enemy)

proc playCard*(world: LiveWorld, captain: Entity, card: Entity, activeGroup: int = 0) =
  world.eventStmts(CardPlayedEvent(entity: captain, card: card)):
    let effectGroup = card[Card].effectGroups[activeGroup]
    var costFailed: bool = false
    for cost in effectGroup.costs:
      if not applyCardCost(world, captain, cost):
        costFailed = true
        break

    if costFailed:
      warn &"Could not pay costs for card, not playing: {effectGroup}"
    else:
      for effect in effectGroup.effects:
        applyCardEffect(world, captain, effect)













#=========================================================================================#
#                                 Setup
#=========================================================================================#

proc createCaptain*(world: LiveWorld, name : string = "Captain") : Entity =
  let captain = world.createEntity()

  let deck = world.createEntity()
  deck.attachData(Deck())

  captain.attachData(Captain(
    deck: deck,
    attributes: {
      † Attributes.Iron : 2,
      † Attributes.Silver : 2,
      † Attributes.Mask : 2,
      † Attributes.Lens : 2,
      † Attributes.Art : 2,
      † Attributes.Spirit : 2,
    }.toTable,
    money: 20
  ))
  captain.attachData(Character(
    name: name,
    health: reduceable(50)
  ))
  captain.attachData(Flags())
  captain.attachData(Identity(
    name: some(name),
    kind: † Characters.Captain
  ))

  var cards: seq[Entity]
  for i in 0 ..< 5:
    cards.add(createCard(world, † Cards.Strike))
    cards.add(createCard(world, † Cards.Defend))

  captain.attachData(CardCollection(
    cards: cards,
    activeCards: cards
  ))

  captain

# proc createOfficer*(world: LiveWorld, ident: Taxon) : Entity =
#   let officer = world.createEntity()
#
#   officer.attachData(Character(
#     name: "Unnamed Officer",
#     health: reduceable(50)
#   ))
#   officer.attachData(Identity(
#     name:
#   officer.attachData(Flags())