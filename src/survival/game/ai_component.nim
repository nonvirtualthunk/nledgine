import survival/game/entities
import survival/game/logic
import survival/game/search
import core/quadtree
import core/search as core_search
import arxmath
import survival/game/survival_core
import survival/game/tiles
import game/randomness
import math
import worlds
import engines
import glm
import prelude
import survival/game/events
import game/flags
import sets
import game/library
import core

# /+============================================+\
# ||                   AI Component             ||
# \+============================================+/
type
  AIComponent* = ref object of LiveGameComponent
    # last updated
    lastUpdatedTick*: Ticks
    # empty default flag data
    emptyFlags*: ref Flags
    # table of foods items that are edible, organized by the kind of creature in question
    edibleItemsByCreature*: Table[Taxon, HashSet[Taxon]]
    # entities that may be a valid source of food (i.e. berry bushes may be a source of food for berry eating creatures, rabbits may be a source of food for carnivores)
    foodSourcesByCreature*: Table[Taxon, HashSet[Taxon]]


method initialize(g: AIComponent, world: LiveWorld) =
  g.name = "AIComponent"
  g.lastUpdatedTick = world[TimeData].currentTime
  g.emptyFlags = new Flags


  var foods : Table[Taxon, ref ItemKind]
  # compute the edibility matrix for food x creature
  for it, itemKind in library(ItemKind):
    if itemKind.food.isSome: # if it's not food, it can't be edible
      foods[it] = itemKind

  for ct, creatureKind in library(CreatureKind):
    # Food item edibility
    var edibleSet: HashSet[Taxon]
    for it, foodItemKind in foods:
      if canEat(creatureKind, foodItemKind.flags):
        edibleSet.incl(it)
    g.edibleItemsByCreature[ct] = edibleSet

    var foodSources: HashSet[Taxon]
    # Plant and animals as possible sources of food
    for pt, plantKind in library(PlantKind):
      block plantBlock:
        for gt, growthStage in plantKind.growthStages:
          for rsrcYield in growthStage.resources:
            # if the resource given by this yield is an edible item, this is a possible food source
            if edibleSet.contains(rsrcYield.resource):
              foodSources.incl(pt)
              break plantBlock

    g.foodSourcesByCreature[ct] = foodSources


  info &"Item edibility:\n{g.edibleItemsByCreature}"
  info &"Food sources:\n{g.foodSourcesByCreature}"

method update(g: AIComponent, world: LiveWorld) =
  discard

func neighborFunc(t: Vec3i, r: var seq[Vec3i]) =
  for n in neighbors(t):
    r.add(n)


proc performTask(g: AIComponent, world: LiveWorld, actor: Entity, creature: ref Creature, phys: ref Physical, region: ref Region, ai: ref CreatureAI, task: var CreatureTask) : CreatureTaskResult =
  let actorKind = actor[Identity].kind
  let ck = creatureKind(actorKind)
  case task.kind:
    of CreatureTaskKind.MoveTo:
      let target = task.target
      if isHeld(world, actor):
        let pos = effectivePosition(world, actor)
        let exitPos = if passable(world, region, pos):
            some(pos)
          else:
            # Todo: if a path can't be found from any of these exit choices, choose a different one
            var possibleExits: seq[Vec3i]
            for n in neighbors(pos):
              if passable(world, region, n):
                possibleExits.add(n)
            minBy(possibleExits, (n) => distance(world, n, target).get(0))

        if exitPos.isSome:
          placeEntity(world, actor, exitPos.get)
          taskContinues()
        else:
          taskInvalid("Could not find appropriate exit from holding entity")
      else:
        if task.activePath.isNone:
          let pf = createPathfinder(world, actor)
          task.activePath = findPath(pf, pathRequest(world, phys.position, target, task.moveAdjacentTo))

        # if we weren't able to find a path
        if task.activePath.isNone:
          taskInvalid()
        else:
          let path = task.activePath.get
          let currentStep = indexWhereIt(path.steps, it == phys.position)
          if currentStep == -1:
            warn &"We are off of our exploration path, resetting path to allow for another attempt"
            task.activePath = none(Path)
            taskContinues()
          elif currentStep == path.steps.len - 1:
            if isEntityTarget(task.target):
              if task.target.entity.hasData(Burrow):
                moveEntityToInventory(world, actor, task.target.entity)
            taskSucceeded()
          else:
            let nextStep = currentStep + 1
            if moveEntity(world, actor, path.steps[nextStep]):
              taskContinues()
            else:
              warn &"Could not move into tile needed for movement task, resetting path to replan"
              task.activePath = none(Path)
              taskContinues()
    of CreatureTaskKind.EatFrom:
      var ate = false
      for item in actor[Inventory].items:
        if canEat(world, actor, item):
          if not ai.burrow.isSentinel:
            ai.burrow[Burrow].nutrientsGathered += item[Food].hunger
          eat(world, actor, item)
          ate = true

      if ate:
        taskSucceeded()
      else:
        if distance(positionOf(world, task.target).get(vec3i(-1000,-1000,-1000)), phys.position) < 2.0f:
          if isEntityTarget(task.target):
            let targetEnt = task.target.entity
            var nutrients = 0
            if canEat(world, actor, targetEnt):
              moveEntityToInventory(world, item = targetEnt, toInventory = actor)
              taskContinues()
            else:
              let rsrcs = gatherableResourcesFor(world, task.target)
              var edibleResources: seq[GatherableResource]
              for rsrc in rsrcs:
                if rsrc.quantity.currentValue > 0 and g.edibleItemsByCreature[actorKind].contains(rsrc.resource):
                  edibleResources.add(rsrc)
              var actions : Table[Taxon, ActionUse]
              for action, v in ck.innateActions: actions[action] = ActionUse(kind: action, value: v, source: actor)
              let gatherResult = gatherFrom(world, actor, task.target, edibleResources, actions)
              if gatherResult.actionsUsed.isEmpty:
                warn &"Wasn't able to use an action to effect gathering of resource"
                warn &"\tactions: {actions}\n\tedible resources: {edibleResources}"
                taskFailed()
              else:
                taskContinues()
          else:
            warn &"Eating from tiles is not yet implemented"
            taskInvalid()
        else:
          warn &"We are not close enough to the target to eat from it {task.target}, {phys.position}, {actor}"
          taskInvalid()
    of CreatureTaskKind.Wait:
      let effWaitTicks = min(creature.remainingTime.int, task.waitTime.int)
      advanceCreatureTime(world, actor, effWaitTicks.Ticks)
      task.waitTime -= effWaitTicks.Ticks
      if task.waitTime <= 0.Ticks:
        taskSucceeded()
      else:
        taskContinues()
    of CreatureTaskKind.Attack:
      attack(world, actor, task.target, allEquippedItems(actor[Creature]))
      taskSucceeded()


proc distanceBasedPriority(dist: float, maxPrioDist: int, minPrioDist: int) : float =
  if dist < maxPrioDist.float:
    1.0
  elif dist >= minPrioDist.float:
    0.0
  else:
    1.0 - ((dist - maxPrioDist.float) / (minPrioDist.float - maxPrioDist.float))

proc chooseNewGoal(g: AIComponent, world: LiveWorld, actor: Entity, creature: ref Creature, phys: ref Physical, region: ref Region, ai: ref CreatureAI, currentTime: Ticks) =
  ai.activeGoal = CreatureGoals.Explore
  # Note, should probably check actual food items directly, everything else can be checked on
  # kind alone


  let actorKind = actor[Identity].kind
  if actorKind.isA(† Creature):
    let ck = creatureKind(actorKind)

    var situationalPriority: Table[CreatureGoals, float]

    let examinationRange = max(creature.visionRange, 1)

    let (dayNight, fract) = timeOfDay(world, phys.region)
    case ck.schedule:
      of CreatureSchedule.Diurnal:
        situationalPriority[CreatureGoals.Home] = if dayNight == DayNight.Night:
          1.0f
        else:
          shiftFraction(fract, 0.75, 1.0)
      of CreatureSchedule.Nocturnal:
        situationalPriority[CreatureGoals.Home] = if dayNight == DayNight.Day:
          1.0f
        else:
          shiftFraction(fract, 0.75, 1.0)
      of CreatureSchedule.Crepuscular:
        if fract > 0.15 and fract < 0.85:
          situationalPriority[CreatureGoals.Home] = 1.0f # TODO: ramping priority like with diurnal/nocturnal

    # If the burrow has been destroyed then home is no longer a valid option
    if isSurvivalEntityDestroyed(world, ai.burrow):
      situationalPriority[CreatureGoals.Home] = 0.0f

    if heldBy(world, actor) == some(ai.burrow) and situationalPriority.getOrDefault(CreatureGoals.Home) > 0.0:
      discard
    else:
      # if we're not safe in our home burrow, or it isn't sleep-at-home time, look for other things to do
      for examineEnt in entitiesNear(world, actor, examinationRange):
        var visible: Option[bool]
        let examinedKind = examineEnt[Identity].kind
        if currentTime - ai.completedGoals.getOrDefault(CreatureGoals.Eat, DistantPastInTicks) > DayDuration and
           currentTime - ai.failedGoals.getOrDefault(CreatureGoals.Eat, DistantPastInTicks) > LongActionTime * 4 and
            not situationalPriority.hasKey(CreatureGoals.Eat):
          # info "Considering looking for edible food"
          if g.edibleItemsByCreature[actorKind].contains(examinedKind) or  # check for known edibility
              g.foodSourcesByCreature[actorKind].contains(examinedKind) or  # check for known is-a-food-source
              (examinedKind.isA(† Item) and examineEnt.hasData(Food) and canEat(world, actor, examineEnt)): # check to see if it's an actual item with food contents
            # info "\tEdible food nearby"
            if isVisibleTo(region, phys.position, examineEnt[Physical].position, visible):
              # info "\t\tAnd visible too!"
              situationalPriority[CreatureGoals.Eat] = 1.0f

        if examineEnt.hasData(Creature):
          # TODO: Proper assessment of predator/prey relationships
          # TODO: Monsters
          if examineEnt.hasData(Player):
            if isVisibleTo(region, phys.position, examineEnt[Physical].position, visible):
              let dist = distance(examineEnt[Physical].position, phys.position)

              situationalPriority[CreatureGoals.Flee] = 0.5 + distanceBasedPriority(dist, ck.panicRange, examinationRange) * 0.5
              situationalPriority[CreatureGoals.Attack] = 0.5 + distanceBasedPriority(dist, ck.aggressionRange, examinationRange) * 0.5

      if situationalPriority.len == 0:
        situationalPriority[CreatureGoals.Explore] = 1.0f
      else:
        situationalPriority[CreatureGoals.Explore] = 0.5f

      if currentTime - ai.completedGoals.getOrDefault(CreatureGoals.Examine) > LongActionTime * 2:
        situationalPriority[CreatureGoals.Examine] = 1.0f

    var bestPriority = 0.0f
    var chosenGoal = CreatureGoals.Explore
    for goal, situational in situationalPriority:
      let base = ck.priorities.getOrDefault(goal) * situational
      if base * situational > bestPriority:
        chosenGoal = goal
        bestPriority = base * situational

    info &"Situational priorities for {debugIdentifier(world, actor)}:\n\t{situationalPriority}\n\tchosen goal: {chosenGoal}"

    if ai.activeGoal != chosenGoal:
      ai.activeGoal = chosenGoal
      ai.tasks.clear()
  else:
    warn &"Uncertain how to choose new goals for something that is not a creature {actorKind}"




# Returns false if the current goal cannot be acted on further with the available time remaining
proc updateEntity(g: AIComponent, world: LiveWorld, actor: Entity, currentTime: Ticks) : bool =
  result = true

  if not actor.hasData(CreatureAI):
    actor.attachData(CreatureAI)

  let phys = actor[Physical]
  let creature = actor[Creature]
  let ai = actor[CreatureAI]
  let regionEnt = phys.region
  let region = phys.region[Region]
  let examinationRange = max(creature.visionRange, 1)
  let actorKind = actor[Identity].kind

  if isSurvivalEntityDestroyed(world, actor) or creature.dead:
    return false

  var rand = randomizer(world)

  proc moveCostFunc(v: Vec3i) : Option[float] =
    if passable(world, region, v):
      some(moveTime(creature, region, v).int.float)
    else:
      none(float)

  # if this ai creature is held by something else, then just return false, we don't want a captured rabbit just running
  # out of the player's inventory, for example
  let aiHeldBy = heldBy(world, actor)
  if aiHeldBy.isSome:
    if aiHeldBy.get.hasData(Creature):
      return false

  if ai.tasks.nonEmpty:
    let taskResult = performTask(g, world, actor, creature, phys, region, ai, ai.tasks[0])
    case taskResult.kind:
      of CreatureTaskResultKind.Continues:
        discard
      of CreatureTaskResultKind.Succeeded:
        ai.tasks.delete(0)
        if ai.tasks.isEmpty:
          ai.completedGoals[ai.activeGoal] = currentTime
          ai.activeGoal = CreatureGoals.Think
      of CreatureTaskResultKind.Failed: # in the event of failure or invalidity, clear out tasks and reset the goal so we think again
        ai.tasks.clear()
        ai.activeGoal = CreatureGoals.Think
      of CreatureTaskResultKind.Invalid:
        ai.tasks.clear()
        ai.activeGoal = CreatureGoals.Think
  else:
    case ai.activeGoal:
      of CreatureGoals.Think:
        # decide on a new goal
        chooseNewGoal(g, world, actor, creature, phys, region, ai, currentTime)
      of CreatureGoals.Explore:
        let burrowPos = if not ai.burrow.isSentinel:
          ai.burrow[Physical].position
        else:
          phys.position

        let randomDir = rand.nextFloat(TAU) # [-pi,pi]
        let randomVec = vec2f(cos(randomDir), sin(randomDir))


        var bestTarget: Option[(Vec3i, float)]
        for (n,cost) in floodIterator(phys.position, neighborFunc, moveCostFunc, TicksPerLongAction * 2):
          let angle = arctan2((n.y - phys.position.y).float, (n.x - phys.position.x).float)
          # compute the difference between the two angles (if greater than PI we have wrapped around, and we should subtract PI to account for that)
          # var deltaAngle = abs(angle - randomDir)
          # if deltaAngle > PI:
          #   deltaAngle -= PI
          let deltaAngle = dot(randomVec, vec2f(n.x - phys.position.x, n.y - phys.position.y))

          # points for: distance, up to 10 away from the burrow, distance away from starting point, and convergence with the randomly chosen direction
          let ranking = min(distance(burrowPos, n) * 5.0, 50.0) + distance(phys.position, n) * 10.0 + deltaAngle * 20.0
          if bestTarget.isNone or bestTarget.get[1] < ranking:
            bestTarget = some((n, ranking))


        info &"Decided to explore from {phys.position} to {bestTarget}"

        if bestTarget.isSome:
          ai.tasks = @[moveTask(world, regionEnt, bestTarget.get()[0])]
        else:
          warn &"Could not find a valid place to explore to"
          ai.activeGoal = CreatureGoals.Think
          ai.failedGoals[CreatureGoals.Explore] = currentTime
      of CreatureGoals.Flee:
        var enemies: seq[Entity]
        var enemyPositions: seq[Vec3i]
        for examineEnt in entitiesNear(world, actor, actor[Creature].visionRange):
          if examineEnt.hasData(Player):
            enemies.add(examineEnt)
            enemyPositions.add(examineEnt[Physical].position)

        var bestTarget: Vec3i = phys.position
        var bestValue: float = 0.0
        for (n,cost) in floodIterator(phys.position, neighborFunc, moveCostFunc, TicksPerLongAction):
          var distMinusCost = 1000.0
          for epos in enemyPositions:
            let c = distance(n, epos) - cost * 0.01f
            # We want to maximize the distance from all enemies, so we consider the value to be the
            # worst value it has for any enemy
            distMinusCost = min(distMinusCost, c)
          if distMinusCost > bestValue:
            bestValue = distMinusCost
            bestTarget = n
        if bestTarget != phys.position:
          ai.tasks = @[moveTask(world, regionEnt, bestTarget)]
        else:
          # If we cannot flee, transition to defending
          ai.activeGoal = CreatureGoals.Defend
      of CreatureGoals.Defend:
        var enemies: seq[Entity]
        for examineEnt in entitiesNear(world, actor, 3):
          if examineEnt.hasData(Player) and distance(examineEnt[Physical].position, phys.position) <= 1.1:
            enemies.add(examineEnt)

        if enemies.nonEmpty:
          let enemy = enemies[0]
          ai.tasks = @[attackTask(enemy)]
        else:
          ai.tasks = @[waitTask(ShortActionTime)]
      of CreatureGoals.Eat:
        var foods: seq[Entity]
        for examineEnt in entitiesNear(world, actor, examinationRange):
          let examinedKind = examineEnt[Identity].kind
          if g.foodSourcesByCreature[actorKind].contains(examinedKind) or canEat(world, actor, examineEnt):
            if isVisibleTo(region, phys.position, examineEnt[Physical].position):
              foods.add(examineEnt)
        if foods.isEmpty:
          warn &"Mismatch, no food entities found when trying to perform eat goal"
          ai.activeGoal = CreatureGoals.Think
          ai.failedGoals[CreatureGoals.Eat] = currentTime
        else:
          var bestFood: Entity
          var bestValue: float

          for food in foods:
            let dist = distance(food[Physical].position, phys.position)
            var hunger = 0
            if food.hasData(Food):
              hunger = food[Food].hunger
            elif food.hasData(Gatherable):
              for rsrc in food[Gatherable].resources:
                if g.edibleItemsByCreature[actorKind].contains(rsrc.resource):
                  hunger = max(hunger, itemKind(rsrc.resource).food.get.hunger.maxRoll)
            let value = hunger.float * (1.1f - dist / examinationRange.float) # 1.1 because even the furthest away should have some weight
            if value > bestValue:
              bestValue = value
              bestFood = food

          if bestFood.isSentinel:
            warn &"Could not actually locate any food to eat"
            ai.activeGoal = CreatureGoals.Think
            ai.failedGoals[CreatureGoals.Eat] = currentTime
          else:
            ai.tasks = @[moveTask(bestFood, moveAdjacentTo = true), eatTask(bestFood)]
      of CreatureGoals.Examine:
        ai.tasks = @[waitTask(LongActionTime)]
      of CreatureGoals.Home:
        if aiHeldBy == some(ai.burrow):
          ai.tasks = @[waitTask(LongActionTime * 4)]
        else:
          ai.tasks = @[moveTask(ai.burrow, moveAdjacentTo = true)]
      of CreatureGoals.Attack:
        var targets: seq[Entity]
        for examineEnt in entitiesNear(world, actor, examinationRange):
          # TODO: Include prey, not just player? Or does that just fall under eat at the "strategic" level?
          if examineEnt.hasData(Player):
            targets.add(examineEnt)
        if targets.nonEmpty:
          var bestTarget: Entity
          var bestValue: float = 1000000.0
          for target in targets:
            let dist = distance(target[Physical].position, phys.position)
            if dist < bestValue:
              bestValue = dist
              bestTarget = target
          
          ai.tasks = @[moveTask(bestTarget, moveAdjacentTo = true), attackTask(bestTarget)]
        else:
          warn &"No targets to attack"
          ai.activeGoal = CreatureGoals.Think
          ai.failedGoals[CreatureGoals.Attack] = currentTime

        # ai.tasks = @[moveTask()]






method onEvent(g: AIComponent, world: LiveWorld, event: Event) =
  withWorld(world):
    postMatcher(event):
      extract(WorldAdvancedEvent, tick):
        let deltaT = tick - g.lastUpdatedTick
        for ent in world.entitiesWithData(Creature):
          if not ent.hasData(Player):
            var iter = 0
            ent[Creature].remainingTime += deltaT
            while ent[Creature].remainingTime.int > 0:
              if not updateEntity(g, world, ent, tick):
                break

              iter.inc
              if iter > 10:
                warn &"> 10 iterations in ai entity update, likely missed either reducing available time or marking as non-advanceable {debugIdentifier(world, ent)}"
                warn &"\t{ent[CreatureAI][]}"
                break
        g.lastUpdatedTick = tick
      extract(CreatureMovedEvent, entity):
        let curTime = world[TimeData].currentTime
        if entity.hasData(Player):
          for aiEnt in entitiesNear(world, entity, 6):
            if aiEnt.hasData(Creature) and aiEnt.hasData(CreatureAI) and not aiEnt.hasData(Player):
              chooseNewGoal(g, world, aiEnt, aiEnt[Creature], aiEnt[Physical], aiEnt[Physical].region[Region], aiEnt[CreatureAI], curTime)