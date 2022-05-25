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


proc createBubble*(world: LiveWorld, archT: Taxon) : Entity
proc placeBubble*(world: LiveWorld, stage: Entity, bubble: Entity, placement : BubblePlacement)


iterator activeStages*(world: LiveWorld): Entity =
  var seen = false
  for ent in world.entitiesWithData(Stage):
    if ent[Stage].active:
      if seen:
        err &"There is more than one active stage? But how?"
      yield ent
      seen = true

iterator activeStagesD*(world: LiveWorld): ref Stage =
  for ent in world.entitiesWithData(Stage):
    if ent[Stage].active:
      yield ent[Stage]


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


proc doDamage*(world: LiveWorld, attacker: Entity, defender: Entity, rawAmount: int) =
  let vulnAmount = if hasModifier(defender[Combatant], CombatantModKind.Vulnerable): (rawAmount * 3) div 2 else: rawAmount
  let weakAmount = if hasModifier(attacker[Combatant], CombatantModKind.Weak): (vulnAmount * 3) div 4 else: vulnAmount
  let amount = weakAmount


  let unblocked = max(0, amount - defender[Combatant].blockAmount)
  world.eventStmts(DamageDealtEvent(attacker: attacker, defender: defender, damage: unblocked, blockedDamage: amount - unblocked)):
    defender[Combatant].blockAmount = max(0, defender[Combatant].blockAmount - amount)
    defender[Combatant].health.reduceBy(unblocked)

proc gainBlock*(world: LiveWorld, defender: Entity, amount: int) =
  world.eventStmts(BlockGainedEvent(entity: defender, blockAmount: amount)):
    defender[Combatant].blockAmount += amount

proc applyModifier*(world: LiveWorld, entity: Entity, modifier: CombatantMod) =
  world.eventStmts(ModifierAppliedEvent(entity: entity, modifier: modifier)):
    var found = false
    for m in entity[Combatant].modifiers.mitems:
      if m.kind == modifier.kind:
        m.number += modifier.number
        found = true
        break
    if not found:
      entity[Combatant].modifiers.add(modifier)

proc applyModifier*(world: LiveWorld, entity: Entity, modifier: BubbleMod) =
  var found = false
  for m in entity[Bubble].modifiers.mitems:
    if m.kind == modifier.kind:
      m.number += modifier.number
      found = true
      break
  if not found:
    entity[Bubble].modifiers.add(modifier)


proc defaultEffectFor*(action: PlayerActionKind) : seq[PlayerEffect] =
  case action:
    of PlayerActionKind.Attack: @[PlayerEffect(kind: PlayerEffectKind.Attack, amount: 1)]
    of PlayerActionKind.Block: @[PlayerEffect(kind: PlayerEffectKind.Block, amount: 1)]
    of PlayerActionKind.Skill: @[PlayerEffect(kind: PlayerEffectKind.Mod, modifier: combatantMod(CombatantModKind.Strength, 1))]

proc performEffect*(world: LiveWorld, entity: Entity, target: Entity, effect: PlayerEffect) =
  let cd = entity[Combatant]
  case effect.kind:
    of PlayerEffectKind.Attack:
      doDamage(world, entity, target, effect.amount + sumModifiers(cd, CombatantModKind.Strength))
    of PlayerEffectKind.Block:
      gainBlock(world, entity, effect.amount + sumModifiers(cd, CombatantModKind.Dexterity))
    of PlayerEffectKind.Mod:
      applyModifier(world, entity, effect.modifier)
    of PlayerEffectKind.EnemyMod:
      applyModifier(world, target, effect.modifier)
    of PlayerEffectKind.Bubble:
      for stage in activeStages(world):
        let bubble = createBubble(world, effect.bubbleArchetype)
        placeBubble(world, stage, bubble, effect.bubblePlacement)

proc performAction*(world: LiveWorld, entity: Entity, action: PlayerActionKind) =
  let pd = entity[Player]
  let cd = entity[Combatant]
  let effects = pd.effects.getOrDefault(action, defaultEffectFor(action))
  for effect in effects:
    for stage in activeStages(world):
      performEffect(world, entity, stage[Stage].enemy, effect)


proc advanceAction*(world: LiveWorld, action: PlayerActionKind, amount: int) =
  let p = player(world)
  let pd = p[Player]
  pd.actionProgress[action] = pd.actionProgress.getOrDefault(action) + amount
  if pd.actionProgress[action] >= pd.actionProgressRequired.getOrDefault(action):
    performAction(world, p, action)
    pd.actionProgress[action] = 0

proc pickIntent*(world: LiveWorld, enemy: Entity) =
  var r = randomizer(world, 12)
  enemy[Enemy].activeIntent = pickFrom(r, enemy[Enemy].intents)[1]
  world.postEvent(IntentChangedEvent(entity: enemy))

proc advanceEnemyAction*(world: LiveWorld, enemy: Entity, amount: int) =
  let ed = enemy[Enemy]
  ed.activeIntent.duration.reduceBy(amount)
  if ed.activeIntent.duration.currentValue <= 0:
    for eff in ed.activeIntent.effects:
      performEffect(world, enemy, player(world), eff)
    pickIntent(world, enemy)



proc fireBubbleWithoutCannon*(world : LiveWorld, stage: Entity, bubble: Entity, position: Vec2f, velocity: Vec2f) =
  let sd = stage[Stage]
  let bd = bubble[Bubble]
  bd.position = position
  bd.velocity = velocity
  sd.bubbles.add(bubble)

  let fw = sumModifiers(player(world)[Combatant], CombatantModKind.Footwork)
  if fw > 0: gainBlock(world, player(world), fw)


proc fireBubble*(world : LiveWorld, stage: Entity, cannon: Entity) =
  let cd = cannon[Cannon]
  let sd = stage[Stage]
  if sd.activeMagazine.nonEmpty:
    let bubble = sd.activeMagazine.bubbles[0]
    let bd = bubble[Bubble]
    bd.position = cd.position
    bd.velocity = cd.direction * cd.maxVelocity * cd.currentVelocityScale
    sd.activeMagazine.bubbles.delete(0)
    sd.bubbles.add(bubble)
    sd.fired.add(bubble)

    let fw = sumModifiers(player(world)[Combatant], CombatantModKind.Footwork)
    if fw > 0: gainBlock(world, player(world), fw)


proc checkFinishedFiredBubbles(world: LiveWorld, stage: Entity, bubble: Entity) =
  let sd = stage[Stage]
  for i in 0 ..< sd.fired.len:
    if sd.fired[i] == bubble:
      let bd = bubble[Bubble]
      for eff in bd.onFireEffects:
        performEffect(world, player(world), sd.enemy, eff)
      attachModifiers(world, bubble, player(world), bd.inPlayPlayerMods)
      advanceEnemyAction(world, sd.enemy, 1)
      sd.fired.delete(i)
      break


proc bubbleStopped*(world: LiveWorld, stage: Entity, bubble: Entity) =
  world.addFullEvent(BubbleStoppedEvent(stage: stage, bubble: bubble))
  checkFinishedFiredBubbles(world, stage, bubble)

proc hasIntersection*(p1: Vec2f, r1: float32, p2: Vec2f, r2: float32) : bool =
  (p2 - p1).lengthSafe <= r1 + r2


iterator allColors*(a: ref Bubble): BubbleColor =
  yield a.color
  for c in a.secondaryColors:
    yield c

proc haveSharedColor*(a, b: ref Bubble) : bool =
  if hasModifier(a, BubbleModKind.Chromophilic) or hasModifier(b, BubbleModKind.Chromophilic):
    true
  else:
    for ac in allColors(a):
      for bc in allColors(b):
        if ac == bc:
          return true
    false


proc popBubble*(world: LiveWorld, stage: Entity, bubble: Entity) =
  checkFinishedFiredBubbles(world, stage, bubble)

  let bd = bubble[Bubble]
  stage[Stage].bubbles.delValue(bubble)
  if not hasModifier(bd, BubbleModKind.Exhaust):
    stage[Stage].activeMagazine.bubbles.add(bubble)
  bd.number = bd.maxNumber
  bd.bounceCount = 0
  detachModifiers(world, bubble, player(world))
  advanceAction(world, colorToAction(bubble[Bubble].color), bubble[Bubble].potency)
  for eff in bd.onPopEffects:
    for stage in activeStages(world):
      performEffect(world, player(world), stage[Stage].enemy, eff)
  world.addFullEvent(BubblePoppedEvent(bubble: bubble, stage: stage))


proc collideBubbles*(world: LiveWorld, stage: Entity, bubbleA: Entity, bubbleB: Entity) =
  let shareColor = haveSharedColor(bubbleA[Bubble], bubbleB[Bubble])

  let bda = bubbleA[Bubble]
  let bdb = bubbleB[Bubble]
  let exchange = [hasModifier(bda, BubbleModKind.Exchange), hasModifier(bdb, BubbleModKind.Exchange)]
  let selfish = [hasModifier(bda, BubbleModKind.Selfish), hasModifier(bdb, BubbleModKind.Selfish)]

  let countDownBy = if shareColor:
    if exchange[0] and exchange[1]:
      0
    else:
      max(bubbleA[Bubble].payload, bubbleB[Bubble].payload)
  else:
    0

  var i = 0
  for bubble in @[bubbleA, bubbleB]:
    if not isDestroyed(world, bubble):
      let bd = bubble[Bubble]
      if exchange[(i+1) mod 2]: # if the _other_ one has exchange, this one gets an increase instead
        bd.number = min(bd.number + countDownBy, 9)
      elif selfish[(i+1) mod 2]:
        discard
      else:
        bd.number = max(bd.number - countDownBy, 0)

      if hasModifier(bd, BubbleModKind.Chromophobic) and not shareColor:
        bd.number = min(bd.number + 1, 9)

      if bd.number == 0:
        popBubble(world, stage, bubble)
    i.inc


proc createEnemy*(world: LiveWorld, archT: Taxon): Entity =
  let enemy = world.createEntity()
  let arch = library(EnemyArchetype)[archT]
  enemy.attachData(arch.enemyData)
  enemy.attachData(arch.combatantData)
  enemy


proc createEnemy*(world: LiveWorld, stage: Entity): Entity =
  let sd = stage[Stage]
  var r = randomizer(world)
  let enemy = createEnemy(world, † Enemies.Slime)


  pickIntent(world, enemy)
  world.postEvent(EnemyCreatedEvent(entity: enemy))
  enemy


proc fractionalToAbsolutePosition*(sd: ref Stage, xf: float, yf: float) : Vec2f =
  let x = sd.bounds.x + sd.bounds.width * xf
  let y = sd.bounds.y + sd.bounds.height * yf
  vec2f(x,y)

proc fractionalToAbsolutePosition*(sd: ref Stage, v: Vec2f) : Vec2f = fractionalToAbsolutePosition(sd, v.x, v.y)

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
  var magazines : seq[Magazine]
  for i in 0 ..< 3: magazines.add(new Magazine)

  var i = 0
  for bubble in player[Player].bubbles:
    let magazine = magazines[i mod magazines.len]
    let copy = world.copyEntity(bubble)
    copy[Bubble].number = copy[Bubble].maxNumber
    magazine.bubbles.insert(copy, r.nextInt(magazine.bubbles.len+1))
    i.inc

  let stage = world.createEntity()
  stage.attachData(Stage(
    active: stageDesc.makeActive,
    bubbles: @[],
    magazines: magazines,
    activeMagazine: magazines[0],
    cannon: cannon,
    bounds: bounds,
    linearDrag: stageDesc.linearDrag,
    level: stageDesc.level,
    progressRequired: stageDesc.progressRequired
  ))

  let sd = stage[Stage]
  let prePlacedBubbles = 3
  for i in 0 ..< prePlacedBubbles:
    let magazine = sd.magazines[i mod sd.magazines.len]
    if magazine.isEmpty: continue

    let bubble = magazine.takeBubble()
    sd.bubbles.add(bubble)

    let spacing = (1.float32/prePlacedBubbles.float32)
    bubble[Bubble].position = fractionalToAbsolutePosition(sd, spacing * (i.float32 + 0.5f32), 0.75f32)

  stage[Stage].enemy = createEnemy(world, stage)

  stage


proc allColors*(): seq[BubbleColor] = enumValuesSeq(BubbleColor)

proc createBubble*(world: LiveWorld, archT: Taxon) : Entity =
  result = createBubble(world)
  let bd : ref Bubble = result[Bubble]
  let arch = library(BubbleArchetype)[archT]
  bd.name = arch.name
  bd.image = arch.image
  bd.numeralColor = arch.numeralColor
  bd.maxNumber = arch.maxNumber
  bd.number = bd.maxNumber
  bd.archetype = archT
  bd.color = arch.color
  bd.secondaryColors = arch.secondaryColors
  bd.modifiers = arch.modifiers
  bd.onPopEffects = arch.onPopEffects
  bd.onFireEffects = arch.onFireEffects
  bd.inPlayPlayerMods = arch.inPlayPlayerMods
  bd.onCollideEffects = arch.onCollideEffects


proc validPlacementLocation*(world: LiveWorld, sd: ref Stage, bd: ref Bubble, v: Vec2f): bool =
  var valid = true
  for b in sd.bubbles:
    let tbd = b[Bubble]
    if hasIntersection(v, bd.radius, tbd.position, tbd.radius):
      valid = false
      break
  valid

proc placeBubble*(world: LiveWorld, stage: Entity, bubble: Entity, placement : BubblePlacement) =
  let bd = bubble[Bubble]
  var r = randomizer(world)
  let sd = stage[Stage]
  case placement:
    of BubblePlacement.Random:
      while true:
        let v = fractionalToAbsolutePosition(sd, r.nextFloat(0.0, 1.0), r.nextFloat(0.6, 1.0))
        if validPlacementLocation(world, sd, bd, v):
          bd.position = v
          info &"Chosen placement: {bd[]}"
          break
      sd.bubbles.add(bubble)
    of BubblePlacement.RandomMagazine:
      world.eventStmts(BubbleAddedToMagazineEvent(stage: stage, bubble: bubble)):
        sd.magazines[r.nextInt(sd.magazines.len)].bubbles.insert(bubble, 0)
    of BubblePlacement.ActiveMagazine:
      world.eventStmts(BubbleAddedToMagazineEvent(stage: stage, bubble: bubble)):
        sd.activeMagazine.bubbles.insert(bubble, 0)
    of BubblePlacement.Fire:
      warn &"Fire bubble placement not yet implemented, doing random instead"
      placeBubble(world, stage, bubble, BubblePlacement.Random)
    of BubblePlacement.FireFromTop:
      for i in 0 ..< 100:
        let v = fractionalToAbsolutePosition(sd, 0.5 + (i.float / 100.0f) * 0.4, 0.9)
        if validPlacementLocation(world, sd, bd, v):
          fireBubbleWithoutCannon(world, stage, bubble, v, vec2f(r.nextFloat(-0.5, 0.5), -0.75).normalize * 400.0f)
          break
  world.postEvent(BubblePlacedEvent(stage: stage, bubble: bubble, placement: placement))



proc rarityToFrequency*(rarity: Rarity): int =
  case rarity:
    of Rarity.Common: 3
    of Rarity.Uncommon: 2
    of Rarity.Rare: 1
    of Rarity.None: 0


proc createRandomizedRewardBubble*(world: LiveWorld) : Entity =
  var r = randomizer(world)

  let lib = library(BubbleArchetype)
  var total = 0
  for k, v in lib:
    total += v.rarity.rarityToFrequency

  var ri = r.nextInt(total) + 1
  var chosen: Taxon
  for k, v in lib:
    ri -= v.rarity.rarityToFrequency
    if ri <= 0:
      chosen = k
      break

  info &"Chosen: {chosen}"
  let bubble = createBubble(world, chosen)

  world.postEvent(BubbleRewardCreatedEvent(bubble: bubble))
  bubble


proc completeStage*(world: LiveWorld, stage: Entity) =
  let player = player(world)
  let sd = stage[Stage]
  sd.active = false
  player[Player].completedLevel = sd.level

  for k,v in player[Player].actionProgress.mpairs:
    v = 0
  player[Combatant].blockAmount = 0
  player[Combatant].modifiers.clear()
  player[Combatant].externalModifiers.clear()

  player[Player].pendingRewards.add(Reward(
    bubbles: @[createRandomizedRewardBubble(world), createRandomizedRewardBubble(world), createRandomizedRewardBubble(world)]
  ))


proc advanceStage*(world: LiveWorld) =
  let player = player(world)
  var desc = StageDescription(
               linearDrag: 90.0f32,
               cannonPosition: vec2f(0.5f, 0.25f),
               cannonVelocity: 600.0f32,
               progressRequired: some(8),
               makeActive: true,
               level: player[Player].completedLevel + 1
             )

  case desc.level:
    of 1:
      desc.progressRequired = some(8)
    of 2:
      desc.progressRequired = some(10)
      desc.cannonVelocity = 700.float32
    of 3:
      desc.progressRequired = some(15)
      desc.cannonPosition = vec2f(0.25f, 0.25f)
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