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
import worlds/identity
import game/flags
import core/quadtree
import arxmath

{.experimental.}

const MaxGatherTickIncrement = Ticks(100)
const CraftingRange = 2

type PlantCreationParameters* = object
  # optionally specified growth stage to create at, defaults to a random stage distributed evenly across total age
  growthStage*: Option[Taxon]


type ActionChoice* = object
  target* : Target
  tool*: Entity
  action*: Taxon

type PossibleAttack* = object
  source*: Entity
  attack*: AttackType



# /+===================================================+\
# ||               Predefinitions                      ||
# \+===================================================+/
proc destroySurvivalEntity*(world: LiveWorld, ent: Entity, bypassDestructiveCreation: bool = false)
proc eat*(world: LiveWorld, actor: Entity, target: Entity) : bool {.discardable.}
proc placeEntity*(world: LiveWorld, entity: Entity, atPosition: Vec3i, capsuled: bool = false) : bool {.discardable.}
proc canEat*(world: LiveWorld, actor: Entity, target: Entity): bool {.gcsafe.}



## Shifts a [0.0,1.0] fractional range such that values <= minFract resolve to 0.0 and value >= maxFract resolve to 1.0
## with values between the two interpolating smoothly between. i.e. shifting 0.3 to [0.2,0.4] would result in a value of
## 0.5, since it is half way between the shifted start and end points
proc shiftFraction*(fract: float, minFract: float, maxFract: float) : float =
  clamp((fract - minFract) / (maxFract - minFract), 0.0, 1.0)

## How many times the given interval has been hit between startTime (inclusive) and endTime (exclusive)
## i.e. if the interval is every 10 ticks, then there will be 2 between 13 and 40 (landing on 20 and 30)
proc intervalsIn*(startTime: Ticks, endTime: Ticks, interval: Ticks) : int =
  if interval.int == 0: return 0

  let startIntervalIdx = startTime.int div interval.int
  let endIntervalIdx = (endTime.int - 1) div interval.int
  max(endIntervalIdx - startIntervalIdx, 0)

# Updates the vital stat based on the recovery/loss frequency and returns the minimum resolution required to update accurately
proc updateRecoveryAndLoss*(v: var Vital, startTime: Ticks, curTime: Ticks) =
  if v.lossTime.isSome:
    v.value.reduceBy(intervalsIn(startTime, curTime, v.lossTime.get))
  if v.recoveryTime.isSome:
    v.value.recoverBy(intervalsIn(startTime, curTime, v.recoveryTime.get))

proc player*(world: LiveWorld) : Entity =
  for ent in world.entitiesWithData(Player):
    return ent
  SentinelEntity

proc displayName*(world: LiveWorld, entity: Entity): string =
  let idopt = entity.dataOpt(Identity)
  ifPresent(idOpt):
    if it.name.isSome:
      return it.name.get
    else:
      return it.kind.displayName
  "Unknown"

proc displayName*(world: LiveWorld, target: Target) : string =
  case target.kind:
    of TargetKind.Entity:
      displayName(world, target.entity)
    of TargetKind.TileLayer:
      layersAt(world, target.region, target.tilePos, target.layer)[target.index].tileKind.taxon.displayName
      # tile(target).layers(target.layer)[target.index].tileKind.taxon.displayName
    of TargetKind.Tile:
      &"Tile at {target.tilePos}"

proc distance*(world: LiveWorld, a: Vec3i, t: Target): Option[float] =
  let tp = positionOf(world, t)
  if tp.isSome:
    some(distance(a, tp.get))
  else:
    none(float)

proc distance*(world: LiveWorld, a,b: Entity): float =
  if a.hasData(Physical) and b.hasData(Physical):
    distance(a[Physical].position, b[Physical].position)
  else:
    warn &"Trying to compute distance between entities when not both are physical ({debugIdentifier(world, a)}, {debugIdentifier(world, b)})"
    100000.0


proc effectivePosition*(world: LiveWorld, e: Entity): Vec3i =
  let physOpt = e.dataOpt(Physical)
  if physOpt.isSome:
    if physOpt.get.heldBy.isSome:
      effectivePosition(world, physOpt.get.heldBy.get)
    else:
      physOpt.get.position
  else:
    warn &"effectivePosition(...) called for non-physical entity"
    vec3i(10000,10000,10000)

proc effectivePosition*(world: LiveWorld, phys: ref Physical): Vec3i =
  if phys.heldBy.isSome:
    effectivePosition(world, phys.heldBy.get)
  else:
    phys.position

proc addToRegion*(world: LiveWorld, e: Entity, region: Entity) =
  e[Physical].region = region
  region[Region].entities.incl(e)

proc isEquipped*(world: LiveWorld, e: Entity): bool =
  let physOpt = e.dataOpt(Physical)
  if physOpt.isSome and physOpt.get.heldBy.isSome:
    let holder = physOpt.get.heldBy.get
    let creatureOpt = holder.dataOpt(Creature)
    if creatureOpt.isSome:
      return allEquippedItems(creatureOpt.get).contains(e)
  false

proc isHeld*(world: LiveWorld, e: Entity): bool =
  let physOpt = e.dataOpt(Physical)
  ifPresent(physOpt):
    return it.heldBy.isSome
  false

proc isEquippable*(world: LiveWorld, e: Entity): bool =
  let itemOpt = e.dataOpt(Item)
  ifPresent(itemOpt):
    if it.actions.nonEmpty:
      return true
    elif e.hasData(LightSource):
      return true
  false


proc isVisibleTo*(region: ref Region, start: Vec3i, dest: Vec3i) : bool =
  var obstructed = false
  for px,py in bresenham(start.x, start.y, dest.x, dest.y):
    if (start.x == px and start.y == py) or (dest.x == px and dest.y == py):
      continue
    else:
      if opacity(region, px, py, start.z) > 200:
        obstructed = true
        break
  not obstructed


# check whether the entity is visible or not to the active entity. Uses a var Option[bool] so that it can
# cache the results. Used so that we only check visibility if an entity is actually of interest, but only
# do so once if it is interesting for multiple reasons
proc isVisibleTo*(region: ref Region, start: Vec3i, dest: Vec3i, v: var Option[bool]) : bool =
  if v.isNone:
    v = some(isVisibleTo(region, start, dest))
  v.get()


proc createResourcesFromYields*(world: LiveWorld, yields: seq[ResourceYield], source: Taxon) : seq[GatherableResource] =
  withWorld(world):
    var rand = randomizer(world, 19)
    for rsrcYield in yields:
      let gatherableRsrc = GatherableResource(
        resource: rsrcYield.resource,
        source: source,
        quantity: reduceable(rsrcYield.quantity.nextValue(rand).int16),
        image: rsrcYield.image
      )
      result.add(gatherableRsrc)

proc createGatherableDataFromYields*(world: LiveWorld, ent: Entity, yields: seq[ResourceYield], source: Taxon) =
  withWorld(world):
    if not ent.hasData(Gatherable):
      ent.attachData(Gatherable())
    ent.data(Gatherable).resources.add(createResourcesFromYields(world, yields, source))


proc reduceDurability*(world: LiveWorld, ent: Entity, reduceBy: int) =
  if ent.hasData(Item):
    let item = ent[Item]
    if item.durability.maxValue == 0:
      info &"reduceDurability() called with item that does not use durability. May not be an issue {debugIdentifier(world, ent)}"
    else:
      let evt = DurabilityReducedEvent(entity: ent, reducedBy: reduceBy, newDurability: max(0, ent[Item].durability.currentValue - reduceBy))
      world.eventStmts(evt):

        item.durability.reduceBy(reduceBy)
        if item.durability.currentValue <= 0:
          destroySurvivalEntity(world, ent)
  else:
    info &"reduceDurability() called on non-item: {ent}"



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
      # var oldestStage: Ticks
      # for stage, stageInfo in plantInfo.growthStages:
      #   oldestStage = max(oldestStage, stageInfo.startAge)

      # Take the lower of the overall lifespan, or twice the start age of the oldest stage. This is to give us proportions based on
      # overall time spent in each stage without being universally mature for things that live for like 10 years. In practice we
      # would want to account for the relative survival rate at each stage, but this'll do for now
      # Disabled temporarily, gave too many tree saplings, will need to consider how to address that. Might be worth just putting a
      # percentage in each growth stage in the plant definition :\
      # age = Ticks(rand.nextInt(min(plantInfo.lifespan.int, oldestStage.int * 2)))
      age = Ticks(rand.nextInt(plantInfo.lifespan.int))
      var chosenStage: Taxon
      for stage, stageInfo in plantInfo.growthStages:
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
      occupiesTile: growthStageInfo.occupiesTile,
      blocksLight: growthStageInfo.blocksLight
    ))
    result.attachData(Identity(kind: kind))
    createGatherableDataFromYields(world, result, growthStageInfo.resources, kind)

    addToRegion(world, result, region)
    placeEntity(world, result, vec3i(position.x, position.y, MainLayer))


proc advanceCreatureTime*(world: LiveWorld, creature: Entity, byTicks: Ticks) =
  if creature.hasData(Player):
    let time = world[TimeData]
    let startTime = time.currentTime
    # for i in 0 ..< byTicks.int:
    #   world.eventStmts(WorldAdvancedEvent(tick: startTime + i)):
    #     time.currentTime = startTime + i
    world.eventStmts(WorldAdvancedEvent(tick: startTime + byTicks)):
      time.currentTime = startTime + byTicks
  else:
    creature[Creature].remainingTime -= byTicks


proc tileOn*(world: LiveWorld, entity: Entity): var Tile =
  withWorld(world):
    ifHasData(world, entity, Physical, phys):
      return tile(phys.region[Region], phys.position.x, phys.position.y, phys.position.z)

    err "tileOn(...) called with entity that was not on a specific tile, returning sentinel"
    let regionEnt = toSeq(world.entitiesWithData(Region))[0]
    tile(regionEnt, 0, 0, 0)

proc tileMoveTime*(tile: Tile) : Ticks =
  let tileLib = library(TileKind)
  if tile.floorLayers.nonEmpty:
    let tileInfo = tileLib[tile.floorLayers[^1].tileKind]
    tileInfo.moveCost
  else:
    1.Ticks
  # for floorLayer in tile.floorLayers:
  #   let tileInfo = tileLib[floorLayer.tileKind]
  #   result += tileInfo.moveCost

proc moveTime*(world: LiveWorld, entity: Entity, region: ref Region, pos: Vec3i): Ticks =
  entity[Creature].baseMoveTime + tileMoveTime(tile(region, pos.x, pos.y, pos.z))

proc moveTime*(creature: ref Creature, region: ref Region, pos: Vec3i): Ticks =
  creature.baseMoveTime + tileMoveTime(tile(region, pos.x, pos.y, pos.z))

proc removeItemFromGroundInternal*(world: LiveWorld, item: Entity) =
  if item.hasData(Physical):
    tileOn(world, item).entities = tileOn(world, item).entities.withoutValue(item)

proc primaryDirectionFrom*(a,b : Vec2i) : Direction =
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

iterator entitiesNear*(world: LiveWorld, entity: Entity, range: int): Entity =
  if entity.hasData(Physical):
    let phys = entity[Physical]
    let reg = phys.region[Region]
    let pos = effectivePosition(world, entity)
    for v in reg.entityQuadTree.getNear(pos.x, pos.y, range):
      # We don't need to use effectivePosition here, moving into an inventory should remove an entity from the quad tree
      # if we need to include held items we expand the inventories of any top level nearby entities
      let vPhys = v[Physical]
      if not vPhys.destroyed and distance(vPhys.position, pos) <= range.float:
        yield v

proc passable*(world: LiveWorld, tile: ptr Tile) : bool =
  if tile.wallLayers.nonEmpty:
    return false
  for ent in tile.entities:
    if ent[Physical].occupiesTile:
      return false
  true


proc passable*(world: LiveWorld, region: Entity, position: Vec3i) : bool =
  passable(world, tilePtr(region[Region], position))

proc passable*(world: LiveWorld, region: ref Region, position: Vec3i) : bool =
  passable(world, tilePtr(region, position))


iterator neighbors*(v: Vec3i) : Vec3i =
  yield vec3i(v.x+1,v.y,v.z)
  yield vec3i(v.x,v.y+1,v.z)
  yield vec3i(v.x-1,v.y,v.z)
  yield vec3i(v.x,v.y-1,v.z)

proc moveEntity*(world: LiveWorld, creature: Entity, toPos: Vec3i) : bool {.discardable.} =
  if not passable(world, creature[Physical].region, toPos):
    return false

  withWorld(world):
    if creature.hasData(Physical):
      let phys = creature.data(Physical)
      if phys.heldBy.isSome:
        warn &"Should explicitly remove an entity from being held before moving it. Performing implicit removal from inventory {debugIdentifier(world, creature)}"
        placeEntity(world, creature, effectivePosition(world, phys.heldBy.get))

      let fromPos = phys.position
      let region = phys.region[Region]

      let toTile = region.tileRef(toPos)
      let fromTile = region.tileRef(phys.position)

      if creature.hasData(Creature):
        let mt = moveTime(world, creature, region, toPos)

        world.eventStmts(CreatureMovedEvent(entity: creature, region: phys.region, fromPosition: fromPos, toPosition: toPos)):
          fromTile.entities = fromTile.entities.withoutValue(creature)
          toTile.entities.add(creature)
          creature[Physical].position = toPos
          creature[Physical].facing = primaryDirectionFrom(fromPos.xy, toPos.xy)
          region.entityQuadTree.move(fromPos.x, fromPos.y, toPos.x, toPos.y, creature)

          advanceCreatureTime(world, creature, mt)
    else:
      warn "Cannot move entity without physical data"
  true

proc moveEntityDelta*(world: LiveWorld, creature: Entity, delta: Vec3i) : bool {.discardable.} =
  if creature.hasData(Physical):
    moveEntity(world, creature, effectivePosition(world, creature) + delta)


proc createItem*(world: LiveWorld, region: Entity, itemKind: Taxon) : Entity =
  let lib = library(ItemKind)
  let ik : ref ItemKind = lib[itemKind]

  var rand = randomizer(world)

  let ent = world.createEntity()
  world.eventStmts(ItemCreatedEvent(entity: ent, itemKind: itemKind)):

    ent.attachData(Item(
      durability : reduceable(ik.durability.rollInt(rand)),
      decay: reduceable(ik.decay),
      breaksInto: ik.breaksInto,
      decaysInto: ik.decaysInto,
      actions: ik.actions,
      attack: ik.attack
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
      ent.attachData(Fuel(
        fuel: ik.fuel,
        maxFuel: ik.fuel
      ))

    ifPresent(ik.light): ent.attachData(it)

    ifPresent(ik.fire): ent.attachData(it)

    ifPresent(ik.burrow):
      ent.attachData(it)
      ent.attachData(Inventory(maximumWeight: 1000000))

    if ik.resources.nonEmpty: createGatherableDataFromYields(world, ent, ik.resources, itemKind)

    ent.attachData(Physical(
      region: region,
      occupiesTile: ik.occupiesTile,
      blocksLight: ik.blocksLight,
      weight: ik.weight.rollInt(rand).int32,
      images: ik.images,
      health: vital(ik.health.rollInt(rand)).withRecoveryTime(ik.healthRecoveryTime),
      createdAt: world[TimeData].currentTime
    ))

    ent.attachData(ik.flags[])


    ent.attachData(Identity(kind: itemKind))

  ent


proc createCreature*(world: LiveWorld, region: Entity, creatureKind: Taxon) : Entity =
  let lib = library(CreatureKind)
  let ck = lib[creatureKind]

  var rand = randomizer(world)

  let ent = world.createEntity()
  world.eventStmts(CreatureCreatedEvent(entity: ent, creatureKind: creatureKind)):
    ent.attachData(ck.creature)
    ent.attachData(ck.physical)
    ent[Physical].dynamic = true
    ent.attachData(ck.flags)
    ent.attachData(ck.combatAbility)
    ent.attachData(Identity(kind: creatureKind))
    ent.attachData(CreatureAI)
    ent.attachData(Inventory)

    addToRegion(world, ent, region)

  ent

# proc createBurrow*(world: LiveWorld, region: Entity, burrowKind: Taxon): Entity =
#   let lib = library(BurrowKind)
#   let arch : ref BurrowKind = lib[burrowKind]
#
#   let ent = world.createEntity()
#   world.eventStmts(BuildingCreatedEvent(entity: ent, buildingKind: burrowKind)):
#     ent.attachData(arch.burrow)
#     ent.attachData(arch.physical)
#     ent.attachData(arch.flags)
#     ent.attachData(Identity(kind: burrowKind))
#     ent.attachData(Inventory())
#     if arch.resources.nonEmpty:
#       createGatherableDataFromYields(world, ent, arch.resources, burrowKind)
#
#     addToRegion(world, ent, region)
#
#   ent

proc unequipItemFrom*(world: LiveWorld, entity: Entity, item: Entity) =
  let creature = entity[Creature]
  var toRemove: seq[Taxon]
  for k,equippedEntity in creature.equipment:
    if equippedEntity == item:
      toRemove.add(k)

  for k in toRemove:
    world.eventStmts(ItemUnequippedEvent(unequippedBy: entity, item: item, slot: k)):
      creature.equipment.del(k)

proc equipItemTo*(world: LiveWorld, entity: Entity, item: Entity, slot: Taxon) =
  let creature = entity[Creature]
  if creature.equipment.hasKey(slot):
    unequipItemFrom(world, entity, creature.equipment[slot])
  world.eventStmts(ItemEquippedEvent(equippedBy: entity, item: item, slot: slot)):
    creature.equipment[slot] = item

proc removeItemFromInventoryInternal(world: LiveWorld, item: Entity) =
  if item.hasData(Physical):
    let phys = item[Physical]
    ifPresent(phys.heldBy):
      world.eventStmts(ItemRemovedFromInventoryEvent(entity: item, fromInventory: it)):
        it[Inventory].items.excl(item)
        phys.heldBy = none(Entity)
        if it.hasData(Creature):
          unequipItemFrom(world, it, item)


proc placeEntity*(world: LiveWorld, entity: Entity, atPosition: Vec3i, capsuled: bool = false) : bool {.discardable.} =
  let region = regionFor(world, entity)

  let curEnts = entitiesAt(region[Region], atPosition)
  for ent in curEnts:
    let ephys = ent[Physical]
    if ephys.occupiesTile and not ephys.capsuled and not ephys.destroyed:
      world.addFullEvent(CouldNotPlaceEntityEvent(entity: entity, position: atPosition))
      return false

  world.eventStmts(EntityPlacedEvent(entity: entity, position: atPosition)):
    removeItemFromInventoryInternal(world, entity)
    let phys = entity[Physical]
    phys.position = atPosition
    phys.capsuled = capsuled
    tileOn(world, entity).entities.add(entity)
    region[Region].entityQuadTree.insert(phys.position.x, phys.position.y, entity)

  true


proc moveEntityToInventory*(world: LiveWorld, item: Entity, toInventory: Entity) =
  let phys = item[Physical]

  let fromInventory = phys.heldBy

  world.eventStmts(EntityMovedToInventoryEvent(entity: item, fromInventory: fromInventory, toInventory: toInventory)):
    if fromInventory.isNone:
      removeItemFromGroundInternal(world, item)
    else:
      removeItemFromInventoryInternal(world, item)
    # note, check weight limits beforehand
    toInventory[Inventory].items.incl(item)
    phys.heldBy = some(toInventory)
    # entities that are in an inventory shouldn't be tracked in the quadtree
    phys.region[Region].entityQuadTree.remove(phys.position.x, phys.position.y, item)




proc spawnCreatureFromBurrow*(world: LiveWorld, burrow: Entity) : Entity {.discardable.} =
  let burrowData = burrow[Burrow]
  world.eventStmts(BurrowSpawnEvent(burrow: burrow)):
    # Reset progress since a spawn is now occurring
    burrowData.spawnProgress = 0.Ticks
    burrowData.nutrientsGathered = 0

    let phys = burrow[Physical]
    let creature = createCreature(world, phys.region, burrowData.creatureKind)

    moveEntityToInventory(world, creature, burrow)
    # placeEntity(world, creature, phys.position)


    creature[CreatureAI].burrow = burrow

    burrowData.creatures.add(creature)
    result = creature



## Returns true if the entity given can access the item given for the purposes of crafting
proc canAccessForCrafting*(world: LiveWorld, entity: Entity, item: Entity) : bool =
  # if we're holding the item, we can definitely access it
  if item.hasData(Physical):
    if item[Physical].heldBy.isSome:
      let heldBy = item[Physical].heldBy.get
      if heldBy == entity:
        return true
      else:
        # if we can access its container we can access it
        return canAccessForCrafting(world, entity, heldBy)

    if distance(world, entity, item) <= CraftingRange:
      return true

  false

proc recursivelyExpandInventoryIncludingSelf(world: LiveWorld, entity: Entity, into : var seq[Entity]) =
  into.add(entity)

  if entity.hasData(Inventory):
    for item in entity[Inventory].items:
      recursivelyExpandInventoryIncludingSelf(world, item, into)

proc entitiesAccessibleForCrafting*(world: LiveWorld, actor: Entity): seq[Entity] =
  recursivelyExpandInventoryIncludingSelf(world, actor, result)

  for tile in tilesInRange(world, regionFor(world, actor), effectivePosition(world, actor), CraftingRange):
    for entity in tile.entities:
      if entity != actor:
        recursivelyExpandInventoryIncludingSelf(world, entity, result)

proc entitiesHeldByIncludingSelf*(world: LiveWorld, entity: Entity): seq[Entity] =
  recursivelyExpandInventoryIncludingSelf(world, entity, result)

proc entitiesHeldBy*(world: LiveWorld, entity: Entity): seq[Entity] =
  if entity.hasData(Inventory):
      for item in entity[Inventory].items:
        recursivelyExpandInventoryIncludingSelf(world, item, result)

proc heldBy*(world: LiveWorld, entity: Entity): Option[Entity] =
  let physOpt = entity.dataOpt(Physical)
  if physOpt.isSome:
    physOpt.get.heldBy
  else:
    none(Entity)



proc resourceYieldFor*(world: LiveWorld, target: Target, rsrc: GatherableResource): ResourceYield =
  let allYields = if rsrc.source.isA(† Plant):
    if target.isEntityTarget:
      let pk = plantKind(rsrc.source)
      let stage = target.entity[Plant].growthStage
      pk.growthStages.getOrDefault(stage).resources
    else:
      warn &"Tried to get a plant based yield from a non-entity target {target}"
      @[]
  elif rsrc.source.isA(† Creature):
    if target.isEntityTarget:
      let ck = creatureKind(rsrc.source)
      if target.entity.hasData(Creature):
        ck.liveResources
      else:
        warn "resourceYieldFor(...) does not yet support corpses"
        @[]
    else:
      warn &"Tried to get a creature based yield from a non-entity target {target}"
      @[]
  elif rsrc.source.isA(† TileKind):
    let tk = tileKind(rsrc.source)
    tk.resources
  elif rsrc.source.isA(† Item):
    let ik = itemKind(rsrc.source)
    ik.resources
  else:
    warn &"resourceYieldFor(...) called with unsupported resource source: {rsrc.source}"
    @[]

  for rYield in allYields:
    if rYield.resource == rsrc.resource:
      return rYield

  warn "resourceYieldFor(...) found no matching resource in source"

proc effectiveGatherLevelFor*(rYield: ResourceYield, actions: Table[Taxon, ActionUse]) : Option[(ActionUse, float)] =
  var bestMethod = (ActionUse(kind: † UnknownThing), 0.0)
  fine &"Determining effective gather level for {rYield} | {actions}"
  for rMethod in rYield.gatherMethods:
    for action in rMethod.actions:
      # todo: incorporate minimum tool level
      let possibleAct = actions.getOrDefault(action)
      let levelForAction = possibleAct.value
      let effLevel = levelForAction.float / rMethod.difficulty.float

      if bestMethod[1] < effLevel:
        bestMethod = (possibleAct, effLevel)

  if bestMethod[1] > 0.0:
    some(bestMethod)
  else:
    none((ActionUse,float))



proc isSurvivalEntityDestroyed*(world: LiveWorld, entity: Entity) : bool =
  ifHasData(entity, Physical, phys):
    return phys.destroyed
  false

proc destroyTileLayer*(world: LiveWorld, region: Entity, tilePos: Vec3i, layerKind: TileLayerKind, index: int) =
  world.eventStmts(TileLayerDestroyedEvent(region: region, tilePosition: tilePos, layerKind: layerKind, layerIndex: index)):
    let t = tilePtr(region[Region], tilePos.x, tilePos.y, tilePos.z)
    case layerKind:
      of TileLayerKind.Wall: t.wallLayers.delete(index,index)
      of TileLayerKind.Ceiling: t.ceilingLayers.delete(index,index)
      of TileLayerKind.Floor: t.floorLayers.delete(index,index)

proc destroyTarget*(world: LiveWorld, target: Target) =
  case target.kind:
    of TargetKind.Entity:
      destroySurvivalEntity(world, target.entity)
    of TargetKind.TileLayer:
      destroyTileLayer(world, regionFor(world, target), target.tilePos, target.layer, target.index)
    else:
      err &"Trying to destroy invalid target {target}"
      discard


# Place an entity in the same location as an existing entity, either inside an inventory
# or on the ground, as appropriate
proc placeEntityWith*(world: LiveWorld, ent: Entity, with: Entity) =
  if with.hasData(Physical):
    if with[Physical].heldBy.isSome:
      moveEntityToInventory(world, ent, with[Physical].heldBy.get)
    else:
      let capsuled = if ent.hasData(Creature): false else: with[Physical].capsuled
      placeEntity(world, ent, effectivePosition(world, with), capsuled)
  else:
    warn &"Placing entity with another makes no sense if the other is non-physical: {debugIdentifier(world, ent)}, {debugIdentifier(world, with)}"




# Do damage to the health of the given entity, returns true if that entity was destroyed in the process
# Note that entities are not permanently removed, since that would prevent cleanup from accessing them (i.e. creating a corpse)
# rather the `destroyed` flag is set on the entity
proc damageEntity*(world: LiveWorld, ent: Entity, damageAmount: int, damageType: Taxon, reason: string) : bool {.discardable.} =
  if damageAmount <= 0:
    return true

  if ent.hasData(Physical) and not isSurvivalEntityDestroyed(world, ent):
    world.eventStmts(DamageTakenEvent(entity: ent, damageTaken: damageAmount, reason: reason, damageType: damageType)):
      let phys = ent[Physical]
      phys.health.reduceBy(damageAmount)
      if phys.health.currentValue <= 0:
        destroySurvivalEntity(world, ent)
    true
  else:
    info &"damageEntity() called on non-physical entity: {debugIdentifier(world, ent)}"
    false


iterator possibleAttacks*(world: LiveWorld, actor: Entity, allowedEquipment: seq[Entity]): PossibleAttack =
  let kind = actor[Identity].kind
  if kind.isA(† Creature):
    let ck = creatureKind(kind)
    for v in ck.innateAttacks:
      yield PossibleAttack(attack: v, source: actor)

    for item in allowedEquipment:
      if item[Item].attack.isSome:
        yield PossibleAttack(attack: item[Item].attack.get, source: item)


proc attack*(world: LiveWorld, actor: Entity, target: Target, possibleAttack: PossibleAttack) =
  let attackType = possibleAttack.attack
  var rand = randomizer(world)
  if isTileTarget(target):
    warn &"Attacks on a general tile are not yet supported: {target}"
  else:
    world.eventStmts(AttackEvent(attacker: actor, target: target, attackType: attackType)):
      let defaultCombatAbility = new CombatAbility
      let targetEnt = target.entity
      let attackerCA = actor.dataOpt(CombatAbility).get(defaultCombatAbility)
      let targetCA = targetEnt.dataOpt(CombatAbility).get(defaultCombatAbility)

      let isHit = nextFloat(rand) < attackType.accuracy

      if isHit:
        let armor = targetCA.armor.getOrDefault(attackType.damageType, 0)
        # each point of armor gives a 50% chance to negate a point of damage, so roll `armor`d2 - `armor` to simulate dice with faces [0,1]
        let damageReducedBy = roll(dicePool(armor,2), rand).total - armor
        let damage = attackType.damageAmount - damageReducedBy
        world.eventStmts(AttackHitEvent(attacker: actor, target: target, damage: damage, armorReduction: damageReducedBy, attackType: attackType, damageType: attackType.damageType)):
          damageEntity(world, targetEnt, damage, attackType.damageType, "attack")
      else:
        world.addFullEvent(AttackMissedEvent(attacker: actor, target: target, attackType: attackType))

      advanceCreatureTime(world, actor, attackType.duration)

proc attack*(world: LiveWorld, actor: Entity, target: Target, allowedEquipment: seq[Entity]) =

  var attackType: Option[PossibleAttack]

  for possibleAttack in possibleAttacks(world, actor, allowedEquipment):
    attackType = some(possibleAttack)
    break

  if attackType.isSome:
    attack(world, actor, target, attackType.get)
  else:
    warn &"Could not find appropriate attack to use. Available: {toSeq(possibleAttacks(world, actor, allowedEquipment))}, requested: {allowedEquipment}"



type GatherResult = object
  gatheredItems* : seq[Entity]
  gatherRemaining* : bool
  actionsUsed*: seq[ActionUse]


proc gatherableResourcesFor*(world: LiveWorld, target: Target) : seq[GatherableResource] =
  case target.kind:
    of TargetKind.Entity:
      if target.entity.hasData(Gatherable):
        let gatherable = target.entity[Gatherable]
        gatherable.resources
      else:
        @[]
    of TargetKind.TileLayer:
      let tp = tilePtr(target.region[Region], target.tilePos)
      tp[].layers(target.layer)[target.index].resources
    of TargetKind.Tile:
      err &"Cannot simply gather resources from a tile as a whole, must pick individual layer: {target}"
      @[]


proc reduceGatherableResource*(world : LiveWorld, target: Target, resource : Taxon, amount: int, remainingProgress: Ticks16) =
  case target.kind:
    of TargetKind.Entity:
      if target.entity.hasData(Gatherable):
        let gatherable = target.entity[Gatherable]
        for rsrc in gatherable.resources.mitems:
          if rsrc.resource == resource:
            rsrc.quantity.reduceBy(amount.int16)
            rsrc.progress = remainingProgress
    of TargetKind.TileLayer:
      let tp = tilePtr(target.region[Region], target.tilePos)
      for rsrc in tp[].layers(target.layer)[target.index].resources.mitems:
        if rsrc.resource == resource:
          rsrc.quantity.reduceBy(amount.int16)
          rsrc.progress = remainingProgress
    of TargetKind.Tile:
      err &"Cannot simply reduce resources from a tile as a whole, must pick individual layer: {target}"




# Perofrm the gathering of the target using the provided parameters, storing outputs in `resources`
proc gatherFrom*(world: LiveWorld, actor: Entity, target: Target, resources: seq[GatherableResource], actions: Table[Taxon, ActionUse]): GatherResult {.discardable.} =
  if resources.isEmpty: return GatherResult()
  var ticks = 0.Ticks

  var possibleResources : seq[(int, int16)] # (index, resource count)
  var resourcesCountSum = 0

  let region = regionFor(world, target)
  for idx in 0 ..< resources.len:
    if resources[idx].quantity.currentValue > 0:
      let rsrc = resources[idx]
      let rYield = resourceYieldFor(world, target, rsrc)
      let bestMethod = effectiveGatherLevelFor(rYield, actions)
      bestMethod.ifPresent:
        possibleResources.add((idx, rsrc.quantity.currentValue))
        resourcesCountSum += rsrc.quantity.currentValue

  var rand = randomizer(world)
  if possibleResources.nonEmpty:
    # For tile targets the resource grabbed next is random. For entities it is in order so that i.e. the bark of a
    # tree is gathered before its wood, and berries before the bush itself
    var r = if isTileTarget(target):
      nextInt(rand,resourcesCountSum)
    else:
      0

    for (idx,count) in possibleResources:
      r -= count
      if r < 0:
        let rsrc = resources[idx]
        let rYield = resourceYieldFor(world, target, rsrc)
        let bestMethod = effectiveGatherLevelFor(rYield, actions)
        let actionToUse = bestMethod.get()[0]
        if not result.actionsUsed.contains(actionToUse):
          result.actionsUsed.add(actionToUse)

        let progressPerTick = bestMethod.get()[1]
        let (ticksPerDelta, delta) = if progressPerTick < 0.99999:
          (floor(1.0 / progressPerTick + 0.0001).int, 1)
        else:
          if progressPerTick - floor(progressPerTick) > 0.2:
            warn &"Progress per tick at a non-integer: {progressPerTick}"
          (1, progressPerTick.int)

        if ticksPerDelta >= 1 and delta >= 1:
          var gatherCount = 0
          var progress = rsrc.progress
          while ticks < MaxGatherTickIncrement and gatherCount < rsrc.quantity.currentValue():
            ticks += ticksPerDelta
            progress += delta
            if progress > rYield.gatherTime:
              gatherCount.inc
              progress = Ticks16(0)
              result.gatheredItems.add(createItem(world, region, rsrc.resource))

          result.gatherRemaining = gatherCount < rsrc.quantity.currentValue()
          reduceGatherableResource(world, target, rsrc.resource, gatherCount, progress)

          if not result.gatherRemaining and rYield.destructive:
            for remainingRsrc in resources:
              let remainingYield = resourceYieldFor(world, target, remainingRsrc)
              if remainingYield.gatheredOnDestruction:
                for i in 0 ..< remainingRsrc.quantity.currentValue():
                  result.gatheredItems.add(createItem(world, region, remainingRsrc.resource))

            destroyTarget(world, target)
            break
        else:
          warn &"No ticks per delta or no delta: {ticksPerDelta}, {delta}"

  if result.actionsUsed.nonEmpty:
    let fromEntity = case target.kind:
      of TargetKind.Entity: some(target.entity)
      else: none(Entity)
    world.eventStmts(GatheredEvent(entity: actor, items: result.gatheredItems, actions: result.actionsUsed, fromEntity: fromEntity, gatherRemaining: result.gatherRemaining)):
      for item in result.gatheredItems:
        moveEntityToInventory(world, item, actor)
      for action in result.actionsUsed:
        if action.source != actor:
          reduceDurability(world, action.source, 1)
      advanceCreatureTime(world, actor, ticks)


proc interact*(world: LiveWorld, entity: Entity, target: Target, actions: Table[Taxon, ActionUse]) : bool {.discardable.} =
  info &"Interacting with {target}"
  let region = regionEnt(world, entity)

  let gatherableResources = gatherableResourcesFor(world, target)
  if gatherableResources.nonEmpty:
    # Check for the drinkable liquid case
    for rsrc in gatherableResources:
      let kind = itemKind(rsrc.resource)
      # is a liquid, is drinkable, and we don't have something to scoop with, and we can do a general gather
      if kind.flags.flagValue(† Flags.Liquid) > 0 and actions.getOrDefault(† Actions.Scoop).value == 0 and actions.getOrDefault(† Actions.Gather).value > 0:
        let liquid = createItem(world, region, rsrc.resource)
        eat(world, entity, liquid)
        return true

    let gr = gatherFrom(world, entity, target, gatherableResources, actions)
    if gr.actionsUsed.nonEmpty:
      result = true

  # if we're interacting with something pyhsical then turn to face it
  let targetPos = positionOf(world, target)
  info &"Target Pos: {targetPos}"
  if entity.hasData(Physical) and targetPos.isSome:
    let facing = primaryDirectionFrom( effectivePosition(world, entity).xy, targetPos.get().xy)
    world.eventStmts(FacingChangedEvent(entity: entity, facing: facing)):
      entity[Physical].facing = facing





proc facedPosition*(world: LiveWorld, entity: Entity) : Vec3i =
  if entity.hasData(Physical):
    let phys = entity[Physical]
    effectivePosition(world, phys) + vector3iFor(phys.facing)
  else:
    warn &"facedPosition has no meaning for a non-physical entity"
    vec3i(0,0,0)


proc interact*(world: LiveWorld, entity: Entity, tools: seq[Entity], target: Target) : bool {.discardable.} =
  var actions: Table[Taxon, ActionUse]
  proc addPossibleAction(action: Taxon, value: int, source: Entity) =
    if actions.getOrDefault(action).value < value:
      actions[action] = ActionUse(kind: action, value: value, source: source)

  addPossibleAction(† Actions.Gather, 1, entity)

  # Todo: non-hostile interactions with creatures
  if target.kind == TargetKind.Entity and target.entity.hasData(Creature):
    attack(world, entity, target, tools)
    true
  else:
    for tool in tools:
      if tool.hasData(Item):
        for action, value in tool[Item].actions:
          addPossibleAction(action, value, tool)
      elif tool.hasData(Player):
        addPossibleAction(† Actions.Gather, 1, tool)

    interact(world, entity, target, actions)

iterator interactionTargetsAt*(world: LiveWorld, region: Entity, targetPos: Vec3i, skipNonBlocking: bool = false) : Target =
  var done = false
  for target in entitiesAt(region[Region], targetPos):
    if target.hasData(Creature):
      yield Target(kind: TargetKind.Entity, entity: target)
    else:
      let occupiesTile = target[Physical].occupiesTile
      if not skipNonBlocking or occupiesTile:
        yield Target(kind: TargetKind.Entity, entity: target)
      if occupiesTile:
        done = true
        break

  if not done:
    let tile = tile(region, targetPos.x, targetPos.y, targetPos.z)

    if tile.wallLayers.nonEmpty:
      yield Target(kind: TargetKind.TileLayer, layer: TileLayerKind.Wall, region: region, tilePos: targetPos, index: tile.wallLayers.len - 1)
    else:
      if not skipNonBlocking:
        if tile.floorLayers.nonEmpty:
          yield Target(kind: TargetKind.TileLayer, layer: TileLayerKind.Floor, region: region, tilePos: targetPos, index: tile.floorLayers.len - 1)
        if tile.ceilingLayers.nonEmpty:
          yield Target(kind: TargetKind.TileLayer, layer: TileLayerKind.Ceiling, region: region, tilePos: targetPos, index: tile.ceilingLayers.len - 1)

## skipNonBlocking indicates that we only want to interact with entities/tile layers that prevent us from moving
## i.e. we're trying to move but if something is in the way we can infer we want to interact with it
proc interact*(world: LiveWorld, entity: Entity, tools: seq[Entity], targetPos: Vec3i, skipNonBlocking: bool = false) : bool {.discardable.} =
  for target in interactionTargetsAt(world, entity[Physical].region, targetPos, skipNonBlocking):
    info &"Checking interaction target {target}"
    if interact(world, entity, tools, target):
      return true
  false

proc canIgnite*(world: LiveWorld, target: Target): bool =
  case target.kind:
    of TargetKind.Entity:
      flagValue(world, target.entity, † Flags.Inflammable) > 0 or
        (target.entity.hasData(Fire) and not target.entity[Fire].active)
    else:
      false

proc possibleActions*(world: LiveWorld, actor: Entity, considering: Entity) : seq[ActionChoice] =
  let tpos = facedPosition(world, actor)

  let consideringTarget = entityTarget(considering)
  result.add(ActionChoice(target: consideringTarget, action: † Actions.Place))
  if canEat(world, actor, considering):
    result.add(ActionChoice(target: consideringTarget, action: † Actions.Eat))
  if considering.hasData(Item) and considering[Item].actions.nonEmpty:
    let item = considering[Item]
    var yieldsByTarget : seq[(Target, seq[ResourceYield])]
    for target in interactionTargetsAt(world, actor[Physical].region, tpos):
      let gatherable = gatherableResourcesFor(world, target)
      if gatherable.nonEmpty:
        let yields : seq[ResourceYield] = gatherable.mapIt(resourceYieldFor(world, target, it))
        yieldsByTarget.add((target, yields))
      else:
        yieldsByTarget.add((target, @[]))

    for action in item.actions.keys:
      for (target, yields) in yieldsByTarget:
        if (action == † Actions.Ignite) and canIgnite(world, target):
          result.add(ActionChoice(target: target, action: action, tool: considering))
        else:
          for y in yields:
            if y.gatherMethods.anyMatchIt(it.actions.contains(action)):
              result.add(ActionChoice(target: target, action: action, tool: considering))
              break
  if isEquippable(world, considering):
    result.add(ActionChoice(target: consideringTarget, action: † Actions.Equip))
  if canIgnite(world, consideringTarget):
    for heldEnt in entitiesHeldByIncludingSelf(world, actor):
      if heldEnt.hasData(Item) and heldEnt[Item].actions.hasKey(† Actions.Ignite):
        result.add(ActionChoice(target: consideringTarget, action: † Actions.Ignite, tool: heldEnt))



proc matchesRequirement*(world: LiveWorld, actor: Entity, req: RecipeRequirement, item: Entity): bool =
  # Assume true if there are no specifiers (implicitly ought to match everything) or if the operator is an AND (it will then fail if any specifier fails)
  if req.specifiers.isEmpty:
    true
  else:
    # Special case for disallowing items that are on fire, unless fire is explicitly allowed
    if item.hasData(Fire) and item[Fire].active:
      var fireOk = false
      for specifier in req.specifiers:
        if specifier == † Flags.Fire:
          fireOk = true
          break
      if not fireOk:
        return false

    for specifier in req.specifiers:
      let matchesSpecifier = if specifier.isA(† Flag):
        if item.hasData(Flags):
          let flagValue = item[Flags].flagValue(specifier)
          if req.minimumLevel >= 0:
            flagValue > 0 and flagValue >= req.minimumLevel
          else:
            flagValue <= 0
        else:
          # Negative value indicates that the flag must not be present
          if req.minimumLevel < 0:
            true
          else:
            false
      elif specifier.isA(† Action):
        item.hasData(Item) and item[Item].actions.getOrDefault(specifier) >= max(req.minimumLevel, 1)
      else:
        item.hasData(Identity) and item[Identity].kind.isA(specifier)

      case req.operator:
        of BooleanOperator.AND:
          if not matchesSpecifier: return false
        of BooleanOperator.OR:
          if matchesSpecifier: return true
        else:
          warn &"Only AND and OR operators supported for requirement analysis in recipes"

    if req.operator == BooleanOperator.AND:
      true
    else:
      false


func eachMatchedAtLeastOnce(matchesByItem: seq[set[int8]], usedItems: set[int8], remainingReqs : set[int8], numReqs: int) : bool =
  if remainingReqs == {}:
    true
  else:
    for ri in 0 ..< numReqs:
      if remainingReqs.contains(ri.int8):
        for ii in 0 ..< matchesByItem.len:
          # we haven't already used this item and it is a match for this requirement
          if not usedItems.contains(ii.int8) and matchesByItem[ii].contains(ri.int8):
            if eachMatchedAtLeastOnce(matchesByItem, usedItems + {ii.int8}, remainingReqs - {ri.int8}, numReqs):
              return true
    false



# Assumes that you have already checked that this matches the recipe template
proc matchesRecipe*(world: LiveWorld, actor: Entity, recipe: ref Recipe, ingredients: Table[string, RecipeInputChoice]) : bool =
  let recipeTemplate = recipeTemplateFor(recipe)
  for slotKey, requirements in recipe.ingredients:
    let choice = ingredients.getOrDefault(slotKey)
    # if this recipe specifies a requirement for this slot, but there are no items in it (i.e. an optional slot) then don't match
    if choice.items.isEmpty:
      return false

    # ensure that every item chosen matches the requirements
    let isDistinct = recipeTemplate.recipeSlots[slotKey].`distinct`
    if isDistinct:
      # in the case of distinct slots we want to make sure that each of the specified requirements
      # is matched by at least one of the items
      var requirementsMatchedByItem : seq[set[int8]]
      for itemIndex in 0 ..< choice.items.len:
        requirementsMatchedByItem.add({})
        for reqIndex in 0 ..< requirements.len:
          if matchesRequirement(world, actor, requirements[reqIndex], choice.items[itemIndex]):
            requirementsMatchedByItem[itemIndex].incl(reqIndex.int8)
      return eachMatchedAtLeastOnce(requirementsMatchedByItem, {}, {0.int8 .. (requirements.len.int8-1)}, requirements.len)
    else:
      for item in choice.items:
        for req in requirements:
          if not matchesRequirement(world, actor, req, item):
            return false


  true


proc matchesSlot*(world: LiveWorld, actor: Entity, slot: RecipeSlot, item: Entity) : bool =
  matchesRequirement(world, actor, slot.requirement, item)

proc matchesRecipeTemplate*(world: LiveWorld, actor: Entity, recipeTemplate: ref RecipeTemplate, ingredients: Table[string, RecipeInputChoice]) : bool =
  for slotKey, slot in recipeTemplate.recipeSlots:
    let choice = ingredients.getOrDefault(slotKey)
    # if this recipe template marks this as required but there is nothing chosen, fail
    if choice.items.isEmpty and not slot.optional:
      return false

    # ensure that every item chosen matches the requirements
    for item in choice.items:
      if not matchesSlot(world, actor, slot, item):
        return false

  true


proc recursivelyAddSpecializations(r: ref Recipe, set: var HashSet[Taxon]) =
  if r.specializationOf != UnknownThing:
    set.incl(r.specializationOf)
    recursivelyAddSpecializations(recipe(r.specializationOf), set)


proc matchingRecipes*(world: LiveWorld, actor: Entity, recipeTemplate: ref RecipeTemplate, ingredients: Table[string, RecipeInputChoice]) : seq[ref Recipe] =
  if matchesRecipeTemplate(world, actor, recipeTemplate, ingredients):
    # track all the general recipes that have a more specific version that matches so we can ignore the general case
    var generalRecipesWithSpecificMatch : HashSet[Taxon]
    var matchingRecipes : seq[ref Recipe]

    for recipe in recipesForTemplate(recipeTemplate):
      if matchesRecipe(world, actor, recipe, ingredients):
        matchingRecipes.add(recipe)
        recursivelyAddSpecializations(recipe, generalRecipesWithSpecificMatch)

    matchingRecipes.filterIt(not generalRecipesWithSpecificMatch.contains(it.taxon))
  else:
    @[]






# Returns true if there is any recipe for which the given item would be a valid match for the listed slot key
proc matchesAnyRecipeInSlot*(world: LiveWorld, actor: Entity, recipeTemplate: ref RecipeTemplate, slot: string, item: Entity): bool =
  if not recipeTemplate.recipeSlots.hasKey(slot):
    warn &"recipe template does not have slot it advertized? {slot}"
  if recipeTemplate.recipeSlots.hasKey(slot) and matchesSlot(world, actor, recipeTemplate.recipeSlots[slot], item):
    for recipe in recipesForTemplate(recipeTemplate):
      if not recipe.ingredients.hasKey(slot):
        return true
      else:
        if recipeTemplate.recipeSlots[slot].`distinct`:
          for req in recipe.ingredients[slot]:
            if matchesRequirement(world, actor, req, item):
              return true
        else:
          var matchesAll = true
          for req in recipe.ingredients[slot]:
            if not matchesRequirement(world, actor, req, item):
              matchesAll = false
          if matchesAll:
            return true
  false



# Hypothetical indicates that we want to create what item would be crafted as a result of these parameters for the purpose of display
# or decision making. So do not destroy any of the ingredients or make random choices if relevant
proc craftItem*(world: LiveWorld, actor: Entity, recipeTaxon: Taxon, ingredients: Table[string, RecipeInputChoice], hypothetical: bool): Option[seq[Entity]] =
  # hypothetical crafting should not be done in the current region, we don't actually want something showing up, this is being created in the ether
  let region = if not hypothetical:
    regionFor(world, actor)
  else:
    SentinelEntity

  var rand = if hypothetical:
    randomizer(world, RandomizationStyle.High)
  else:
    randomizer(world)

  let recipe = recipe(recipeTaxon)
  let recipeTemplate = recipeTemplate(recipe.recipeTemplate)
  if matchesRecipe(world, actor, recipe, ingredients):
    var results : seq[Entity]
    for output in recipe.outputs:
      let outputCount = output.amount.nextValue(rand)
      for i in 0 ..< outputCount:
        let createdItem = createItem(world, region, output.item)
        if not createdItem.hasData(Flags):
          createdItem.attachData(Flags())
        for flag,v in recipeTemplate.addFlags:
          createdItem[Flags].flags[flag] = v

        results.add(createdItem)

    # Apply all of the contributions that the ingredients make to the final object
    for k, ingredient in ingredients:
      let slot = recipeTemplate.recipeSlots[k]
      if slot.kind == RecipeSlotKind.Ingredient:
        let foodCon = recipe.foodContribution.get(recipeTemplate.foodContribution)
        let durCon = recipe.durabilityContribution.get(recipeTemplate.durabilityContribution)
        let decayCon = recipe.decayContribution.get(recipeTemplate.decayContribution)
        let weightCon = recipe.weightContribution.get(recipeTemplate.weightContribution)
        var flagCon = recipe.flagContribution
        for k,v in recipeTemplate.flagContribution:
          flagCon[k] = v

        for output in results:
          for ingredient in ingredient.items:
            if output.hasData(Food) and ingredient.hasData(Food):
              let outFood = output[Food]
              let inFood = ingredient[Food]
              outFood.hunger = applyContribution(foodCon, outFood.hunger, inFood.hunger)
              outFood.stamina = applyContribution(foodCon, outFood.stamina, inFood.stamina)
              outFood.hydration = applyContribution(foodCon, outFood.hydration, inFood.hydration)
              outFood.sanity = applyContribution(foodCon, outFood.sanity, inFood.sanity)
              outFood.health = applyContribution(foodCon, outFood.health, inFood.health)
            if output.hasData(Item) and ingredient.hasData(Item):
              output[Item].durability = applyContribution(durCon, output[Item].durability, ingredient[Item].durability)
            if output.hasData(Item) and ingredient.hasData(Item):
              output[Item].decay = applyContribution(decayCon, output[Item].decay, ingredient[Item].decay)
            if output.hasData(Physical) and ingredient.hasData(Physical):
              output[Physical].weight = applyContribution(weightCon, output[Physical].weight, ingredient[Physical].weight)
            if output.hasData(Flags) and ingredient.hasData(Flags):
              let outFlags = output[Flags]
              let inFlags = ingredient[Flags]
              for k,v in flagCon:
                outFlags.flags[k] = applyContribution(v, outFlags.flags.getOrDefault(k), inFlags.rawFlagValue(k))



      if not hypothetical:
        # Ingredients are consumed, tools are used (durability), and locations just... chill
        if slot.kind == RecipeSlotKind.Ingredient:
          for item in ingredient.items:
            destroySurvivalEntity(world, item, bypassDestructiveCreation = true)
        elif slot.kind == RecipeSlotKind.Tool:
          for item in ingredient.items:
            reduceDurability(world, item, 1)

    if not hypothetical:
      # Todo: modify by skill
      advanceCreatureTime(world, actor, recipe.duration)
    some(results)
  else:
    warn &"Generally, should not try to craft an item out of ingredients that cannot make that recipe: {recipeTaxon}"
    none(seq[Entity])


proc canEat*(creatureKind: ref CreatureKind, foodFlags: ref Flags): bool =
  for cannotEatFlag in creatureKind.cannotEat:
    if flagValue(foodFlags, cannotEatFlag) > 0:
      # if any cannotEat flag is set, this cannot be eaten regardless of other considerations
      return false

  # if we've gotten past exclusions, we just need one canEat flag to match for this to be a pass
  for canEatFlag in creatureKind.canEat:
    if flagValue(foodFlags, canEatFlag) > 0:
      return true

  false

proc canEat*(creatureKind: ref CreatureKind, targetKind: Taxon): bool =
  if targetKind.isA(† Item):
    let ik = itemKind(targetKind)
    # only edible if it is, in fact, food and also has appropriate flags
    ik.food.isSome and canEat(creatureKind, ik.flags)
  else:
    false

proc canEat*(world: LiveWorld, creatureKind: ref CreatureKind, target: Entity): bool =
  target.hasData(Food) and target.hasData(Flags) and canEat(creatureKind, target[Flags])


proc canEat*(world: LiveWorld, actor: Entity, target: Entity): bool {.gcsafe.} =
  let actorKind = actor[Identity].kind
  if actorKind.isA(† Creature):
    let ck = creatureKind(actorKind)
    canEat(world, ck, target)
  else:
    warn &"Non-creatures cannot eat: {actorKind}"
    false


proc eat*(world: LiveWorld, actor: Entity, target: Entity) : bool {.discardable.} =
  if target.hasData(Food) and actor.hasData(Creature) and canEat(world, actor, target):
    let fd = target[Food]
    let cd = actor[Creature]
    let pd = actor[Physical]
    let hungerRecover = min(cd.hunger.currentlyReducedBy, fd.hunger)
    let staminaRecover = min(cd.stamina.currentlyReducedBy, fd.stamina)
    let hydrationRecover = min(cd.hydration.currentlyReducedBy, fd.hydration)
    let sanityRecover = min(cd.sanity.currentlyReducedBy, fd.sanity)
    let healthRecover = min(pd.health.currentlyReducedBy, fd.health)

    world.eventStmts(FoodEatenEvent(entity: actor, eaten: target, hungerRecovered: hungerRecover, staminaRecovered: staminaRecover, hydrationRecovered: hydrationRecover, sanityRecovered: sanityRecover, healthRecovered : healthRecover)):
      cd.hunger.recoverBy(fd.hunger)
      cd.stamina.recoverBy(fd.stamina)
      cd.hydration.recoverBy(fd.hydration)
      cd.sanity.recoverBy(fd.sanity)
      pd.health.recoverBy(fd.health)

      destroySurvivalEntity(world, target)

      advanceCreatureTime(world, actor, TicksPerShortAction.Ticks)
    true
  else:
    false


# If a target is supplied, will attempt to ignite that. If not, will attempt to ignite whatever is in front of the actor
proc ignite*(world: LiveWorld, actor: Entity, tool: Entity, targetSpecified: Option[Target]) =
  let region = regionFor(world, actor)
  let target: Target = if targetSpecified.isSome:
    targetSpecified.get
  else:
    let facedPos = facedPosition(world, actor)
    let entities = entitiesAt(world, actor[Physical].region, facedPos)
    if entities.nonEmpty:
      entityTarget(entities[^1])
    else:
      tileTarget(region, facedPos)

  case target.kind:
    of TargetKind.Entity:
      let targetEnt = target.entity

      if targetEnt.hasData(Fire):
        let fire = targetEnt[Fire]
        if not fire.active:
          world.eventStmts(IgnitedEvent(actor: actor, target: target, tool: tool)):
            fire.active = true
        else:
          world.addFullEvent(FailedToIgniteEvent(actor: actor, target: target, tool: tool, reason: "already on fire"))
      elif flagValue(world, targetEnt, † Flags.Inflammable) > 0:
        if targetEnt.hasData(Item) and targetEnt.hasData(Fuel):
          world.eventStmts(IgnitedEvent(actor: actor, target: target, tool: tool)):
            targetEnt.attachData(Fire(
              active: true,
              fuelRemaining: targetEnt[Fuel].fuel + 1,
              durabilityLossTime: some((targetEnt[Fuel].maxFuel.int div targetEnt[Item].durability.maxValue).Ticks),
              consumedWhenFuelExhausted: true
            ))
        else:
          warn &"Logic for setting a non-(item+fuel) that is inflammable (but without specific burning qualities) aflame is not fleshed out {debugIdentifier(world, targetEnt)}"
          world.eventStmts(IgnitedEvent(actor: actor, target: target, tool: tool)):
            targetEnt.attachData(Fire(
              active: true,
              fuelRemaining: 100.Ticks,
              healthLossTime: some(10.Ticks),
              durabilityLossTime: some(10.Ticks)
            ))
      else:
        world.addFullEvent(FailedToIgniteEvent(actor: actor, target: target, tool: tool, reason: "is not flammable"))
    else:
      world.addFullEvent(FailedToIgniteEvent(actor: actor, target: target, tool: tool, reason: "is not implemented yet"))

  advanceCreatureTime(world, actor, TicksPerMediumAction.Ticks)





proc destroySurvivalEntity*(world: LiveWorld, ent: Entity, bypassDestructiveCreation: bool = false) =
  if isSurvivalEntityDestroyed(world, ent):
    return

  world.eventStmts(EntityDestroyedEvent(entity: ent)):
    if ent.hasData(Physical):
      let phys = ent[Physical]
      phys.destroyed = true

      if not bypassDestructiveCreation:
        if ent.hasData(Creature):
          ent[Creature].dead = true
          # TODO: Create corpse
        elif ent.hasData(Fire) and ent[Fire].active:
          let burnsInto = ent[Fire].burnsInto.get(† Items.Ash)
          let newItem = createItem(world, phys.region, burnsInto)
          placeEntityWith(world, newItem, ent)
        elif ent.hasData(Item):
          let item = ent[Item]
          if item.breaksInto.isSome:
            let newItem = createItem(world, phys.region, item.breaksInto.get)
            placeEntityWith(world, newItem, ent)

      if ent.hasData(Inventory):
        for heldEnt in entitiesHeldBy(world, ent):
          placeEntityWith(world, heldEnt, ent)
          if heldEnt.hasData(CreatureAI):
            let ai = heldEnt[CreatureAI]
            ai.activeGoal = CreatureGoals.Think
            ai.tasks.clear()

      removeItemFromGroundInternal(world, ent)
      removeItemFromInventoryInternal(world, ent)
      phys.region[Region].entityQuadTree.remove(phys.position.x, phys.position.y, ent)
      phys.region[Region].entities.excl(ent)
    else:
      warn &"No current means of destroying non-physical entity {debugIdentifier(world, ent)}"

## Returns how far through the current day it is, 0.0 is dawn, 0.99999... is the moment before dawn of the next day
proc timeOfDayFraction*(world: LiveWorld, regionEnt: Entity): float =
  let dayLength = regionEnt[Region].lengthOfDay
  let withinDay = world[TimeData].currentTime.int mod max(dayLength.int,1)
  withinDay.float / dayLength.float

## Returns whether it is day or night, and how far through the day/night it is [0.0,1.0)
proc timeOfDay*(world: LiveWorld, regionEnt: Entity) : (DayNight, float) =
  const dayFract = 0.65
  let pcnt = timeOfDayFraction(world, regionEnt)
  if pcnt < dayFract:
    (DayNight.Day, pcnt / dayFract)
  else:
    (DayNight.Night, (pcnt - dayFract) / (1.0 - dayFract))

proc skipToTimeOfDay*(world: LiveWorld, regionEnt: Entity, dayNight: DayNight, fract: float) =
  while timeOfDay(world, regionEnt)[0] != dayNight:
    world[TimeData].currentTime += 100.Ticks

  while timeOfDay(world, regionEnt)[1] < fract:
    world[TimeData].currentTime += 10.Ticks


## Returns how many full days have passed
proc dayCount*(world: LiveWorld, regionEnt: Entity): int =
  let dayLength = regionEnt[Region].lengthOfDay
  world[TimeData].currentTime.int div max(dayLength.int,1)



when isMainModule:
  echoAssert(intervalsIn(Ticks(11), Ticks(20), Ticks(10)) == 0)
  echoAssert(intervalsIn(Ticks(11), Ticks(21), Ticks(10)) == 1)
  echoAssert(intervalsIn(Ticks(19), Ticks(20), Ticks(10)) == 0)
  echoAssert(intervalsIn(Ticks(19), Ticks(21), Ticks(10)) == 1)
  echoAssert(intervalsIn(Ticks(20), Ticks(21), Ticks(10)) == 0)
  echoAssert(intervalsIn(Ticks(20), Ticks(25), Ticks(10)) == 0)
  echoAssert(intervalsIn(Ticks(20), Ticks(35), Ticks(10)) == 1)
  echoAssert(intervalsIn(Ticks(20), Ticks(50), Ticks(10)) == 2)
  echoAssert(intervalsIn(Ticks(20), Ticks(51), Ticks(10)) == 3)

  let lib = library(PlantKind)
  let oakTaxon = taxon("Plants", "OakTree")
  let oak = lib[oakTaxon]

  let world = createLiveWorld()

  let region = world.createEntity()

  withWorld(world):
    region.attachData(Region)
    world.attachData(RandomizationWorldData())
    for i in 0 ..< 10:
      let plantEnt = createPlant(world, region, oakTaxon, vec3i(0,0,0), PlantCreationParameters())

    let log = createItem(world, region, † Items.Log)
    let axe = createItem(world, region, † Items.StoneAxe)
    let carrot = createItem(world, region, † Items.CarrotRoot)

    let recipe = recipe(† Recipes.CarvePlank)
    let recipeTemplate = recipeTemplate(recipe.recipeTemplate)

    var ingredients : Table[string, RecipeInputChoice]
    ingredients["Ingredient"] = RecipeInputChoice(items: @[log])
    ingredients["Blade"] = RecipeInputChoice(items: @[axe])

    assert matchingRecipes(world, SentinelEntity, recipeTemplate, ingredients).contains(recipe)

    assert not matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Blade", carrot)
    assert matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Blade", axe)
    assert not matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Ingredient", axe)
    assert matchesAnyRecipeInSlot(world, SentinelEntity, recipeTemplate, "Ingredient", log)

    assert matchesRecipeTemplate(world, SentinelEntity, recipeTemplate, ingredients) and matchesRecipe(world, SentinelEntity, recipe, ingredients)

    var wrongIngredients : Table[string, RecipeInputChoice]
    wrongIngredients["Ingredient"] = RecipeInputChoice(items: @[carrot])
    wrongIngredients["Blade"] = RecipeInputChoice(items: @[axe])
    assert matchesRecipeTemplate(world, SentinelEntity, recipeTemplate, ingredients) and not matchesRecipe(world, SentinelEntity, recipe, wrongIngredients)

    var wrongTool : Table[string, RecipeInputChoice]
    wrongTool["Ingredient"] = RecipeInputChoice(items: @[log])
    wrongTool["Blade"] = RecipeInputChoice(items: @[carrot])
    assert not matchesRecipeTemplate(world, SentinelEntity, recipeTemplate, wrongTool)
