import engines
import worlds
import arxmath
import entities
import game/library
import prelude
import events
import core/metrics
import noto
import glm
import nimgl/glfw
import logic
import tables
import sets
import windowingsystem/windowingsystem
import core

type
  PhysicsComponent = ref object of LiveGameComponent
    mark*: float64
    collisionPairs*: HashSet[(Entity, Entity)]

  BubbleComponent = ref object of LiveGameComponent

  StageComponent = ref object of LiveGameComponent
    rewardWidget*: Widget

proc physicsComponent*() : PhysicsComponent =
  result = new PhysicsComponent

proc bubbleComponent*() : BubbleComponent =
  result = new BubbleComponent

method initialize(g: PhysicsComponent, world: LiveWorld) =
  g.name = "PhysicsComponent"

method initialize(g: BubbleComponent, world: LiveWorld) =
  g.name = "BubbleComponent"

method update(g: PhysicsComponent, world: LiveWorld) =
  let curTime = glfWGetTime()
  if g.mark == 0.0:
    g.mark = curTime - 0.0166666666667

  let deltaTime = curTime - g.mark
  g.mark = curTime


  for stage in activeStages(world):
    let sd = stage[Stage]

    for bi in 0 ..< sd.bubbles.len:
      let bubble = sd.bubbles[bi]
      let b = bubble[Bubble]
      let spd = b.velocity.lengthSafe
      if spd > 0.001:
        var newPos = b.position + b.velocity * deltaTime
        var wallCollision : Option[Wall]
        for axis in axes2d():
          var hit = false
          if newPos[axis] + b.radius >= sd.bounds.max(axis):
            wallCollision = if axis == Axis.X: some(Wall.Right) else: some(Wall.Top)
            hit = true
          elif newPos[axis] - b.radius <= sd.bounds.min(axis):
            wallCollision = if axis == Axis.X: some(Wall.Left) else: some(Wall.Bottom)
            hit = true

          if hit:
            b.velocity[axis] = (b.velocity[axis] * -1.0f32)

        if wallCollision.isSome:
          if b.lastHitWall != wallCollision:
            world.postEvent(WallCollisionEvent(stage: stage, bubble: bubble, wall: wallCollision.get))
        b.lastHitWall = wallCollision

        newPos = b.position + b.velocity * deltaTime

        b.position += b.velocity * deltaTime
        world.addFullEvent(BubbleMovedEvent(stage: stage, bubble: bubble))

        let dir = b.velocity.normalizeSafe
        # b.velocity -= b.velocity.normalizeSafe * max(b.velocity.lengthSafe * b.velocity.lengthSafe, 1000.0f32) * sd.drag * deltaTime

        if spd > 0.001:
          let yf = (b.position.y - sd.bounds.min(Axis.Y)) / sd.bounds.height
          let dragMult = if yf < 0.7f32 and b.velocity.y < 0.0f: 1.0f32 + (1.0f32 - yf / 0.7f32) * 8f32 else: 1.0f32
          let newSpd = max(spd - sd.linearDrag * dragMult * deltaTime, 0.0f32)
          b.velocity = dir * newSpd
          if newSpd <= 0.001:
            bubbleStopped(world, stage, bubble)




    var collisionPairs : HashSet[(Entity,Entity)]

    for bi in 0 ..< sd.bubbles.len:
      let bd = sd.bubbles[bi][Bubble]
      for obi in bi + 1 ..< sd.bubbles.len:
        let obd = sd.bubbles[obi][Bubble]
        if hasIntersection(bd.position, bd.radius, obd.position, obd.radius):
          if sd.bubbles[bi].id < sd.bubbles[obi].id:
            collisionPairs.incl((sd.bubbles[bi], sd.bubbles[obi]))
          else:
            collisionPairs.incl((sd.bubbles[obi], sd.bubbles[bi]))

          let distanceOfIntersection = (bd.position - obd.position).lengthSafe - (bd.radius + obd.radius)
          let n = (bd.position - obd.position).normalizeSafe
          let rv = bd.velocity - obd.velocity
          let velAlongNormal = rv.dot(n)
          if velAlongNormal <= 0:
            # con = true
            let j = ((1.0f + min(bd.elasticity, obd.elasticity)) * -1.0f * velAlongNormal) / (1.0/1.0 + 1.0/1.0)
            let impulse = n * j
            let ignoreBDV = hasModifier(bd, BubbleModKind.Juggernaut) and bd.velocity.lengthSafe > obd.velocity.lengthSafe
            let ignoreOBDV = hasModifier(obd, BubbleModKind.Juggernaut) and obd.velocity.lengthSafe > bd.velocity.lengthSafe

            let immovableB = hasModifier(bd, BubbleModKind.Immovable) and bd.velocity.lengthSafe < 0.05
            let immovableO = hasModifier(obd, BubbleModKind.Immovable) and obd.velocity.lengthSafe < 0.05
            if immovableB:
              obd.velocity -= impulse * 2.0
              obd.position += n * distanceOfIntersection * 1.1
            elif immovableO:
              bd.velocity += impulse * 2.0
              bd.position -= n * distanceOfIntersection * 1.1
            else:
              if not ignoreBDV:
                bd.velocity += impulse * (1.0/1.0)
              if not ignoreOBDV:
                obd.velocity -= impulse * (1.0/1.0)
              bd.position -= n * distanceOfIntersection * 0.55
              obd.position += n * distanceOfIntersection * 0.55

    var changedCollisionPairs = false
    for pair in collisionPairs:
      if not g.collisionPairs.contains(pair):
        world.postEvent(BubbleCollisionEvent(stage: stage, bubbles: pair))
        changedCollisionPairs = true

    for oldPair in g.collisionPairs:
      if not collisionPairs.contains(oldPair):
        world.postEvent(BubbleCollisionEndEvent(stage: stage, bubbles: oldPair))
        changedCollisionPairs = true

    if changedCollisionPairs:
      g.collisionPairs = collisionPairs

    for bi in 0 ..< sd.bubbles.len:
      let bd = sd.bubbles[bi][Bubble]
      for axis in axes2d():
        bd.position[axis] = min(bd.position[axis], sd.bounds.max(axis) - bd.radius)
        bd.position[axis] = max(bd.position[axis], sd.bounds.min(axis) + bd.radius)


method onEvent(g: PhysicsComponent, world: LiveWorld, event: Event) =
  discard


method onEvent(g: BubbleComponent, world: LiveWorld, event: Event) =
  postMatcher(event):
    extract(BubbleCollisionEndEvent,stage, bubbles):
      collideBubbles(world, stage, bubbles[0], bubbles[1])
      bubbles[0][Bubble].bounceCount.inc
      bubbles[1][Bubble].bounceCount.inc
    extract(WallCollisionEvent, stage, bubble):
      bubble[Bubble].bounceCount.inc
      if bubble[Bubble].hasModifier(BubbleModKind.WallAverse):
        bubble[Bubble].number = min(bubble[Bubble].number + 1, 9)
    extract(BubbleStoppedEvent, bubble):
      bubble[Bubble].bounceCount = 0
      bubble[Bubble].lastHitWall = none(Wall)


proc stageComponent*() : StageComponent =
  result = new StageComponent

method initialize(g: StageComponent, world: LiveWorld) =
  g.name = "StageComponent"

method onEvent(g: StageComponent, world: LiveWorld, event: Event) =
  postMatcher(event):
    extract(DamageDealtEvent, attacker, defender):
      if defender[Combatant].health.currentValue <= 0:
        if defender.hasData(Player):
          err &"YOU HAVE LOST"
        else:
          info &"Stage complete"
          for stage in activeStages(world):
            completeStage(world, stage)
    #   let sd = stage[Stage]
    #   if sd.active:
    #     sd.progress.inc
    #     if sd.progressRequired.isSome and sd.progressRequired.get <= sd.progress:
    #       completeStage(world, stage)


method update(g: StageComponent, world: LiveWorld) =
  discard