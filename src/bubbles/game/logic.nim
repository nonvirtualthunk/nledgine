import entities
import game/library
import glm
import worlds
import sets
import algorithm
import prelude
import noto
import core
import game/randomness
import resources
import arxmath


iterator activeStages*(world: LiveWorld): Entity =
  for ent in world.entitiesWithData(Stage):
    if ent[Stage].active:
      yield ent


proc player*(world: LiveWorld): Entity =
  for p in world.entitiesWithData(Player):
    return p
  SentinelEntity



proc colorToAction*(color: BubbleColor): PlayerActionKind =
  case color:
    of BubbleColor.Red: PlayerActionKind.Attack
    of BubbleColor.Blue: PlayerActionKind.Block
    of BubbleColor.Green: PlayerActionKind.Skill
    else: PlayerActionKind.Attack


proc doDamage*(world: LiveWorld, attacker: Entity, defender: Entity, amount: int) =
  let unblocked = max(0, amount - defender[Combatant].blockAmount)
  world.eventStmts(DamageDealtEvent(attacker: attacker, defender: defender, damage: unblocked, blockedDamage: amount - unblocked)):
    defender[Combatant].blockAmount = max(0, defender[Combatant].blockAmount - amount)
    defender[Combatant].health.reduceBy(unblocked)

proc gainBlock*(world: LiveWorld, defender: Entity, amount: int) =
  world.eventStmts(BlockGainedEvent(entity: defender, blockAmount: amount)):
    defender[Combatant].blockAmount += amount


proc performAction*(world: LiveWorld, entity: Entity, action: PlayerActionKind) =
  case action:
    of PlayerActionKind.Attack:
      for stage in activeStages(world):
        doDamage(world, entity, stage[Stage].enemy, 1)
    of PlayerActionKind.Skill:
      for stage in activeStages(world):
        doDamage(world, entity, stage[Stage].enemy, 1)
      gainBlock(world, entity, 1)
    of PlayerActionKind.Block:
      gainBlock(world, entity, 1)


proc advanceAction*(world: LiveWorld, action: PlayerActionKind, amount: int) =
  let p = player(world)
  let pd = p[Player]
  pd.actionProgress[action] = pd.actionProgress.getOrDefault(action) + amount
  if pd.actionProgress[action] >= pd.actionProgressRequired.getOrDefault(action):
    performAction(world, p, action)
    pd.actionProgress[action] = 0


proc fireBubble*(world : LiveWorld, stage: Entity, cannon: Entity) =
  let cd = cannon[Cannon]
  if stage[Stage].magazine.nonEmpty:
    let bubble = stage[Stage].magazine[0]
    bubble[Bubble].position = cd.position
    bubble[Bubble].velocity = cd.direction * cd.maxVelocity * cd.currentVelocityScale
    stage[Stage].magazine.delete(0)
    stage[Stage].bubbles.add(bubble)


proc hasIntersection*(p1: Vec2f, r1: float32, p2: Vec2f, r2: float32) : bool =
  (p2 - p1).lengthSafe <= r1 + r2


proc collideBubbles*(world: LiveWorld, stage: Entity, bubbleA: Entity, bubbleB: Entity) =
  for bubble in @[bubbleA, bubbleB]:
    if not isDestroyed(world, bubble):
      let bd = bubble[Bubble]
      if bubbleA[Bubble].color == bubbleB[Bubble].color:
        bd.number = (bd.number - 1).max(0)

      if bd.number == 0:
        stage[Stage].bubbles.delValue(bubble)
        # world.destroyEntity(bubble)
        stage[Stage].magazine.add(bubble)
        bd.number = bd.maxNumber
        world.addFullEvent(BubblePoppedEvent(bubble: bubble, stage: stage))



proc createEnemy*(world: LiveWorld, stage: Entity): Entity =
  let sd = stage[Stage]
  var r = randomizer(world)
  let enemy = world.createEntity()

  case r.nextInt(3):
    of 0:
      enemy.attachData(Enemy(
        intents: @[
          Intent(kind: IntentKind.Attack, amount: 2, duration: reduceable(8)),
          Intent(kind: IntentKind.Block, amount: 1, duration: reduceable(3)),
          Intent(kind: IntentKind.Attack, amount: 1, duration: reduceable(5))
        ]
      ))
      enemy.attachData(Combatant(
        health: reduceable(4),
        name: "Goblin",
        image: image("bubbles/images/enemies/goblin.png")
      ))
    of 1:
      enemy.attachData(Enemy(
        intents: @[
          Intent(kind: IntentKind.Attack, amount: 1, duration: reduceable(6)),
          Intent(kind: IntentKind.Attack, amount: 1, duration: reduceable(5))
        ]
      ))
      enemy.attachData(Combatant(
        health: reduceable(3),
        name: "Rat",
        image: image("bubbles/images/enemies/rat.png")
      ))
    else:
      enemy.attachData(Enemy(
        intents: @[
          Intent(kind: IntentKind.Attack, amount: 1, duration: reduceable(6)),
          Intent(kind: IntentKind.Attack, amount: 1, duration: reduceable(5)),
          Intent(kind: IntentKind.Block, amount: 1, duration: reduceable(2)),
        ]
      ))
      enemy.attachData(Combatant(
        health: reduceable(3),
        name: "Bat",
        image: image("bubbles/images/enemies/bat.png")
      ))
  enemy[Enemy].activeIntent = pickFrom(r, enemy[Enemy].intents)[1]
  world.postEvent(EnemyCreatedEvent(entity: enemy))
  enemy


proc fractionalToAbsolutePosition*(sd: ref Stage, xf: float, yf: float) : Vec2f =
  let x = sd.bounds.x + sd.bounds.width * xf
  let y = sd.bounds.y + sd.bounds.height * yf
  vec2f(x,y)

proc createStage*(world: LiveWorld, player: Entity, stageDesc: StageDescription) : Entity =
  let cannon = world.createEntity()

  let bounds = player[Player].playArea

  let absoluteCannonPosition = vec2f(bounds.x, bounds.y) + bounds.dimensions * stageDesc.cannonPosition
  cannon.attachData(Cannon(
    position: absoluteCannonPosition,
    maxVelocity: stageDesc.cannonVelocity,
    currentVelocityScale: 1.0f32,
    direction: vec2f(0,1)
  ))

  var r = randomizer(world)
  var magazine : seq[Entity]

  for bubble in player[Player].bubbles:
    let copy = world.copyEntity(bubble)
    copy[Bubble].number = copy[Bubble].maxNumber
    magazine.insert(copy, r.nextInt(magazine.len+1))

  let stage = world.createEntity()
  stage.attachData(Stage(
    active: stageDesc.makeActive,
    bubbles: @[],
    magazine: magazine,
    cannon: cannon,
    bounds: bounds,
    linearDrag: stageDesc.linearDrag,
    level: stageDesc.level,
    progressRequired: stageDesc.progressRequired
  ))

  let sd = stage[Stage]
  let prePlacedBubbles = 3
  for i in 0 ..< prePlacedBubbles:
    if sd.magazine.isEmpty: continue

    let bubble = sd.magazine[0]
    sd.bubbles.add(bubble)
    sd.magazine.delete(0)

    let spacing = (1.float32/prePlacedBubbles.float32)
    bubble[Bubble].position = fractionalToAbsolutePosition(sd, spacing * (i.float32 + 0.5f32), 0.75f32)

  stage[Stage].enemy = createEnemy(world, stage)

  stage


proc createRewardBubble*(world: LiveWorld) : Entity =
  let bubble = createBubble(world)
  let bd = bubble[Bubble]
  var r = randomizer(world)
  bd.color = pickFrom(r, enumValuesSeq(BubbleColor))[1]
  if r.nextInt(6) >= 4: bd.modifiers.add(bubbleMod(BubbleModKind.Big))
  if r.nextInt(6) >= 4: bd.modifiers.add(bubbleMod(BubbleModKind.Bouncy))
  if r.nextInt(6) >= 4: bd.modifiers.add(bubbleMod(BubbleModKind.HighNumber))
  if r.nextInt(6) >= 4: bd.modifiers.add(bubbleMod(BubbleModKind.Chromophobic))
  world.postEvent(BubbleRewardCreatedEvent(bubble: bubble))
  bubble


proc completeStage*(world: LiveWorld, stage: Entity) =
  let player = player(world)
  let sd = stage[Stage]
  sd.active = false
  player[Player].completedLevel = sd.level

  player[Player].pendingRewards.add(Reward(
    bubbles: @[createRewardBubble(world), createRewardBubble(world), createRewardBubble(world)]
  ))


proc advanceStage*(world: LiveWorld) =
  let player = player(world)
  var desc = StageDescription(
               linearDrag: 90.0f32,
               cannonPosition: vec2f(0.5f, 0.1f),
               cannonVelocity: 700.0f32,
               progressRequired: some(8),
               makeActive: true,
               level: player[Player].completedLevel + 1
             )

  case desc.level:
    of 1:
      desc.progressRequired = some(8)
    of 2:
      desc.progressRequired = some(10)
      desc.cannonVelocity = 800.float32
    of 3:
      desc.progressRequired = some(15)
      desc.cannonPosition = vec2f(-0.25f, 0.1f)
    of 4:
      desc.progressRequired = some(20)
    else:
      desc.progressRequired = some(25)

  info &"Creating stage {desc}"
  let nextStage = createStage(world, player, desc)


proc chooseReward*(world: LiveWorld, rewardIndex: int) =
  let p = player(world)[Player]
  if p.pendingRewards.nonEmpty:
    let bubble = p.pendingRewards[0].bubbles[rewardIndex]
    if not p.bubbles.anyMatchIt(it[Bubble].color == bubble[Bubble].color):
      # if we don't have any of that color yet, create a basic bubble of that color
      let pairBubble = createBubble(world)
      pairBubble[Bubble].color = bubble[Bubble].color
      p.bubbles.add(pairBubble)
    p.bubbles.add(bubble)
    p.pendingRewards.delete(0)
    advanceStage(world)
  else:
    err &"chooseReward(...) called with no pending rewards"