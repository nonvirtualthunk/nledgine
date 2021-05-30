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

type PlantCreationParameters* = object
  # optionally specified growth stage to create at, defaults to a random stage distributed evenly across total age
  growthStage*: Option[Taxon]


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
          advanceWorld(world, moveTime)
          creature[Physical].position = toPos
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

    info "Item created:"
    world.printEntityData(ent)

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
      it[Inventory].items.excl(item)
    if fromInventory.isNone:
      tileOn(world, item).entities.deleteValue(item)
    # note, check weight limits beforehand
    toInventory[Inventory].items.incl(item)
    itemData.heldBy = some(toInventory)



proc destroyEntity*(world: LiveWorld, entity: Entity) =
  world.eventStmts(EntityDestroyedEvent(entity: entity)):
    ifHasData(entity, Physical, phys):
      tileOn(world, entity).entities.deleteValue(entity)
      removeItemFromInventoryInternal(world, entity)
      phys.region[Region].entities.excl(entity)


when isMainModule:
  let lib = library(PlantKind)
  let oakTaxon = taxon("PlantKinds", "OakTree")
  let oak = lib[oakTaxon]

  info $oak
  let world = createLiveWorld()
  withWorld(world):
    world.attachData(RandomizationWorldData())
    for i in 0 ..< 10:
      let plantEnt = createPlant(world, SentinelEntity, oakTaxon, vec3i(0,0,0), PlantCreationParameters())
      world.printEntityData(plantEnt)
