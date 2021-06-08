import entities
import events
import survival_core
import worlds
import glm
import game/randomness
import game/library
import tables
import algorithm
import sequtils
import worlds/taxonomy
import tiles
import core
import sets
import prelude
import worlds/taxonomy
import worlds/identity
import tables

const MaxGatherTickIncrement = Ticks(100)

type PlantCreationParameters* = object
  # optionally specified growth stage to create at, defaults to a random stage distributed evenly across total age
  growthStage*: Option[Taxon]


proc player*(world: LiveWorld) : Entity =
  for ent in world.entitiesWithData(Player):
    return ent
  SentinelEntity


proc createResourcesFromYields*(world: LiveWorld, ent: Entity, yields: seq[ResourceYield], source: Taxon) =
  withWorld(world):
    var rand = randomizer(world, 19)
    if not ent.hasData(Gatherable):
      ent.attachData(Gatherable())
    let gatherable = ent.data(Gatherable)
    for rsrcYield in yields:
      let gatherableRsrc = GatherableResource(
        resource: rsrcYield.resource,
        source: source,
        quantity: reduceable(rsrcYield.amountRange.rollInt(rand))
      )
      gatherable.resources.add(gatherableRsrc)



proc createPlant*(world: LiveWorld, region: Entity, kind: Taxon, position: Vec3i, params: PlantCreationParameters = PlantCreationParameters()): Entity {.discardable.} =
  result = world.createEntity()
  world.eventStmts(PlantCreatedEvent(entity: result, plantKind: kind, position: position)):
    var rand = randomizer(world, 92)
    let plantInfo = library(PlantKind)[kind]

    var age: Ticks
    let stage = if params.growthStage.isSome:
      let s = params.growthStage.get
      age = plantInfo.growthStages[s].startAge
      s
    else:
      age = Ticks(rand.nextInt(plantInfo.lifespan.int))
      var chosenStage: Taxon
      for (stage, stageInfo) in toSeq(plantInfo.growthStages.pairs).sortedByIt(it[1].startAge.int):
        if stageInfo.startAge <= age:
          chosenStage = stage
      chosenStage


    let growthStageInfo = plantInfo.growthStages[stage]
    result.attachData(Plant(
      growthStage: stage
    ))
    result.attachData(Physical(
      images: growthStageInfo.images,
      position: position,
      createdAt: world[TimeData].currentTime - age,
      health: vital(plantInfo.health.rollInt(rand)).withRecoveryTime(plantInfo.healthRecoveryTime),
      region: region,
      occupiesTile: growthStageInfo.occupiesTile
    ))
    result.attachData(Identity(kind: kind))
    createResourcesFromYields(world, result, growthStageInfo.resources, kind)

    region[Region].entities.incl(result)
    region.tile(position.x,position.y,MainLayer).entities.add(result)


proc advanceWorld*(world: LiveWorld, byTicks: Ticks) =
  let time = world[TimeData]
  let startTime = time.currentTime
  for i in 0 ..< byTicks.int:
    world.eventStmts(WorldAdvancedEvent(tick: startTime + i)):
      time.currentTime = startTime + i


proc tileOn*(world: LiveWorld, entity: Entity): var Tile =
  withWorld(world):
    ifHasData(world, entity, Physical, phys):
      return tile(phys.region[Region], phys.position.x, phys.position.y, phys.position.z)

    err "tileOn(...) called with entity that was not on a specific tile, returning sentinel"
    let regionEnt = toSeq(world.entitiesWithData(Region))[0]
    tile(regionEnt, 0, 0, 0)

proc tileMoveTime*(tile: Tile) : Ticks =
  let tileLib = library(TileKind)
  for floorLayer in tile.floorLayers:
    let tileInfo = tileLib[floorLayer.tileKind]
    result += tileInfo.moveCost

proc primaryDirectionFrom(a,b : Vec2i) : Direction =
  if a == b:
    Direction.Center
  else:
    let dx = b.x - a.x
    let dy = b.y - a.y
    if abs(dx) > abs(dy):
      if dx > 0:
        Direction.Right
      else:
        Direction.Left
    else:
      if dy > 0:
        Direction.Up
      else:
        Direction.Down

proc moveEntity*(world: LiveWorld, creature: Entity, toPos: Vec3i) =
  withWorld(world):
    if creature.hasData(Physical):
      let phys = creature.data(Physical)
      let fromPos = phys.position
      let toTile = phys.region.tile(toPos.x, toPos.y, toPos.z)

      if creature.hasData(Creature):
        let moveTime =
          creature[Creature].baseMoveTime +
          tileMoveTime(toTile)

        world.eventStmts(CreatureMovedEvent(entity: creature, region: phys.region, fromPosition: fromPos, toPosition: toPos)):
          creature[Physical].position = toPos
          creature[Physical].facing = primaryDirectionFrom(fromPos.xy, toPos.xy)
          advanceWorld(world, moveTime)
    else:
      warn "Cannot move entity without physical data"

proc moveEntityDelta*(world: LiveWorld, creature: Entity, delta: Vec3i) =
  if creature.hasData(Physical):
    moveEntity(world, creature, creature[Physical].position + delta)


proc createItem*(world: LiveWorld, region: Entity, itemKind: Taxon) : Entity =
  let lib = library(ItemKind)
  let ik = lib[itemKind]

  var rand = randomizer(world)

  let ent = world.createEntity()
  world.eventStmts(ItemCreatedEvent(entity: ent, itemKind: itemKind)):
    ent.attachData(Item(
      durability : reduceable(ik.durability.rollInt(rand)),
      decay: reduceable(ik.decay),
      breaksInto: ik.breaksInto,
      decaysInto: ik.decaysInto,
      actions: ik.actions
    ))

    ifPresent(ik.food):
      ent.attachData(Food(
        hunger: it.hunger.rollInt(rand).int32,
        stamina: it.stamina.rollInt(rand).int32,
        hydration: it.hydration.rollInt(rand).int32,
        sanity: it.sanity.rollInt(rand).int32,
        health: it.health.rollInt(rand).int32
      ))

    if ik.fuel > Ticks(0):
      ent.attachData(Combustable(
        fuel: ik.fuel
      ))

    ifPresent(ik.light):
      ent.attachData(it)

    ent.attachData(Physical(
      region: region,
      occupiesTile: ik.occupiesTile,
      weight: ik.weight.rollInt(rand).int32,
      images: ik.images,
      health: vital(ik.health.rollInt(rand)),
      createdAt: world[TimeData].currentTime
    ))

    ent.attachData(Identity(kind: itemKind))

  ent

proc placeItem*(world: LiveWorld, item: Entity, atPosition: Vec3i, capsuled: bool) =
  world.eventStmts(ItemPlacedEvent(entity: item, position: atPosition, capsuled: capsuled)):
    let phys = item[Physical]
    phys.position = atPosition
    phys.capsuled = capsuled
    tileOn(world, item).entities.add(item)

    let itemData = item[Item]
    ifPresent(itemData.heldBy):
      it[Inventory].items.excl(item)

proc removeItemFromInventoryInternal(world: LiveWorld, item: Entity) =
  if item.hasData(Item):
    let itemData = item[Item]
    ifPresent(itemData.heldBy):
      it[Inventory].items.excl(item)


proc moveItemToInventory*(world: LiveWorld, item: Entity, toInventory: Entity) =
  let phys = item[Physical]
  let itemData = item[Item]

  var fromInventory: Option[Entity] = itemData.heldBy

  world.eventStmts(ItemMovedToInventoryEvent(entity: item, fromInventory: fromInventory, toInventory: toInventory)):
    ifPresent(fromInventory):
      world.eventStmts(ItemRemovedFromInventoryEvent(entity: item, fromInventory: it)):
        it[Inventory].items.excl(item)
    if fromInventory.isNone:
      tileOn(world, item).entities.deleteValue(item)
    # note, check weight limits beforehand
    toInventory[Inventory].items.incl(item)
    itemData.heldBy = some(toInventory)


proc resourceYieldFor*(world: LiveWorld, entity: Entity, rsrc: GatherableResource): ResourceYield =
  let allYields = if rsrc.source.isA(† Plant):
    let pk = plantKind(rsrc.source)
    let stage = entity[Plant].growthStage
    pk.growthStages.getOrDefault(stage).resources
  elif rsrc.source.isA(† Creature):
    let ck = creatureKind(rsrc.source)
    if entity.hasData(Creature):
      ck.liveResources
    else:
      warn "resourceYieldFor(...) does not yet support corpses"
      @[]
  else:
    warn &"resourceYieldFor(...) called with unsupported resource source: {rsrc.source}"
    @[]

  for rYield in allYields:
    if rYield.resource == rsrc.resource:
      return rYield

  warn "resourceYieldFor(...) found no matching resource in source"

proc effectiveGatherLevelFor*(rYield: ResourceYield, actions: Table[Taxon, int]) : Option[(Taxon, float)] =
  var bestMethod = († UnknownThing, 0.0)
  echo "Determining effective gather level for ", rYield, " | ", actions
  for rMethod in rYield.gatherMethods:
    for action in rMethod.actions:
      echo "Examining ", rMethod, " ", action
      # todo: incorporate minimum tool level
      let levelForAction = actions.getOrDefault(action)
      let effLevel = levelForAction.float / rMethod.difficulty.float

      if bestMethod[1] < effLevel:
        bestMethod = (action, effLevel)

  if bestMethod[1] > 0.0:
    some(bestMethod)
  else:
    none((Taxon,float))

proc destroyEntity*(world: LiveWorld, entity: Entity) =
  world.eventStmts(EntityDestroyedEvent(entity: entity)):
    ifHasData(entity, Physical, phys):
      tileOn(world, entity).entities.deleteValue(entity)
      removeItemFromInventoryInternal(world, entity)
      phys.region[Region].entities.excl(entity)


proc interact*(world: LiveWorld, entity: Entity, target: Entity, actions: Table[Taxon, int]) : bool {.discardable.} =
  var ticks = Ticks(0)

  let region = regionEnt(world, entity)


  if target.hasData(Gatherable):
    var gatheredItems : seq[Entity]
    var gatherRemaining = false
    var actionsUsed: seq[Taxon]

    let gatherable = target[Gatherable]
    for rsrc in gatherable.resources.mitems:
      if rsrc.quantity.currentValue > 0:
        let rYield = resourceYieldFor(world, target, rsrc)
        let bestMethod = effectiveGatherLevelFor(rYield, actions)
        bestMethod.ifPresent:
          let actionToUse = bestMethod.get()[0]
          if not actionsUsed.contains(actionToUse):
            actionsUsed.add(actionToUse)
          let progressPerTick = bestMethod.get()[1]
          let (ticksPerDelta, delta) = if progressPerTick < 0.99999:
            (floor(1.0 / progressPerTick + 0.0001).int, 1)
          else:
            if progressPerTick - floor(progressPerTick) > 0.2:
              warn &"Progress per tick at a non-integer: {progressPerTick}"
            (1, progressPerTick.int)

          if ticksPerDelta >= 1 and delta >= 1:
            while ticks < MaxGatherTickIncrement and rsrc.quantity.currentValue() > 0:
              ticks += ticksPerDelta
              rsrc.progress += delta
              if rsrc.progress > rYield.gatherTime:
                rsrc.quantity.reduceBy(1)
                rsrc.progress = Ticks(0)
                gatheredItems.add(createItem(world, region, rsrc.resource))
            gatherRemaining = rsrc.quantity.currentValue() > 0
            if not gatherRemaining and rYield.destructive:
              for remainingRsrc in gatherable.resources:
                let remainingYield = resourceYieldFor(world, target, remainingRsrc)
                if remainingYield.gatheredOnDestruction:
                  for i in 0 ..< remainingRsrc.quantity.currentValue():
                    gatheredItems.add(createItem(world, region, remainingRsrc.resource))
              destroyEntity(world, target)
              break
          else:
            warn &"No ticks per delta or no delta: {ticksPerDelta}, {delta}"

    if actionsUsed.nonEmpty:
      result = true
      world.eventStmts(GatheredEvent(entity: entity, items: gatheredItems, actions: actionsUsed, fromEntity: some(target), gatherRemaining: gatherRemaining)):
        for item in gatheredItems:
          moveItemToInventory(world, item, entity)

    # if we're interacting with something pyhsical then turn to face it
    if entity.hasData(Physical) and target.hasData(Physical):
      entity[Physical].facing = primaryDirectionFrom(entity[Physical].position.xy, target[Physical].position.xy)
    advanceWorld(world, ticks)





proc facedPosition*(world: LiveWorld, entity: Entity) : Vec3i =
  if entity.hasData(Physical):
    let phys = entity[Physical]
    phys.position + vector3iFor(phys.facing)
  else:
    warn &"facedPosition has no meaning for a non-physical entity"
    vec3i(0,0,0)

proc interact*(world: LiveWorld, entity: Entity, tools: seq[Entity], target: Entity) : bool {.discardable.} =
  var actions: Table[Taxon, int]
  proc addPossibleAction(action: Taxon, value: int) =
    actions[action] = max(actions.getOrDefault(action), value)

  if tools.isEmpty:
    addPossibleAction(† Actions.Gather, 1)

  for tool in tools:
    if tool.hasData(Item):
      for action, value in tool[Item].actions:
        addPossibleAction(action, value)
    elif tool.hasData(Player):
      addPossibleAction(† Actions.Gather, 1)

  echo "Interaction possibilities: ", actions
  interact(world, entity, target, actions)

proc interact*(world: LiveWorld, entity: Entity, tools: seq[Entity], targetPos: Vec3i) : bool {.discardable.} =
  for target in entitiesAt(entity[Physical].region[Region], targetPos):
    echo "Checking to interact with target : ", target[Identity].kind
    if interact(world, entity, tools, target):
      return true

  # TODO: Gather from tiles
  let tile = tile(region)
  if tile.wallLayers.nonEmpty:
    tile.wallLayers


when isMainModule:
  let lib = library(PlantKind)
  let oakTaxon = taxon("Plants", "OakTree")
  let oak = lib[oakTaxon]

  info $oak
  let world = createLiveWorld()
  withWorld(world):
    world.attachData(RandomizationWorldData())
    for i in 0 ..< 10:
      let plantEnt = createPlant(world, SentinelEntity, oakTaxon, vec3i(0,0,0), PlantCreationParameters())
      world.printEntityData(plantEnt)
