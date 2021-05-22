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



proc createPlant*(world: LiveWorld, kind: Taxon, position: Vec3i, params: PlantCreationParameters = PlantCreationParameters()): Entity =
  result = world.createEntity()
  world.eventStmts(PlantCreatedEvent(entity: result, plantKind: kind, position: position)):
    var rand = randomizer(world)
    let plantInfo = library(PlantKind)[kind]

    var age: Ticks
    let stage = if params.growthStage.isSome:
      let s = params.growthStage.get
      age = plantInfo.growthStages[s]
      s
    else:
      age = Ticks(rand.nextInt(plantInfo.lifespan.int))
      var chosenStage: Taxon
      for (stage, ticks) in toSeq(plantInfo.growthStages.pairs).sortedByIt(it[1].int):
        if ticks < age:
          chosenStage = stage
      chosenStage


    result.attachData(Plant(
      growthStage: stage
    ))
    result.attachData(Physical(
      images: plantInfo.imagesByGrowthStage[stage],
      position: position,
      createdAt: world[TimeData].currentTime - age,
      health: reduceable(plantInfo.health.rollInt(rand)),
      healthRecoveryTime: plantInfo.healthRecoveryTime,
    ))
    createResourcesFromYields(world, result, plantInfo.resourcesByGrowthStage.getOrDefault(stage), kind)





when isMainModule:
  let lib = library(PlantKind)
  let oakTaxon = taxon("PlantKinds", "OakTree")
  let oak = lib[oakTaxon]

  info $oak
  let world = createLiveWorld()
  withWorld(world):
    world.attachData(RandomizationWorldData())
    for i in 0 ..< 10:
      let plantEnt = createPlant(world, oakTaxon, vec3i(0,0,0), PlantCreationParameters())
      world.printEntityData(plantEnt)
