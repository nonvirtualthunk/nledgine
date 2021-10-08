import engines
import worlds
import tiles
import arxmath
import entities
import game/library
import prelude
import events
import core/metrics
import noto
import glm

type
  TileComponent* = ref object of LiveGameComponent

proc tileComponent*() : TileComponent =
  result = new TileComponent
  result.initializePriority = 100

proc computeOpacity(world: LiveWorld, tile: ptr Tile, tileLib: Library[TileKind]) : uint8 =
  if tile.wallLayers.nonEmpty:
    255.uint8
  else:
    for ent in tile.entities:
      if ent[Physical].blocksLight:
        return 255.uint8
    0.uint8



proc initializeFlags(world: LiveWorld, regionEnt: Entity) =
  let t = relTime()
  let region = regionEnt[Region]
  if not region.opacityInitialized:
    let tileLib = library(TileKind)
    world.eventStmts(OpacityInitializedEvent(region: regionEnt)):
      for z in 0 ..< RegionLayers:
        for x in -RegionHalfSize ..< RegionHalfSize:
          for y in -RegionHalfSize ..< RegionHalfSize:
            let tile = tilePtr(region, x,y,z)
            region.setOpacity(x,y,z, computeOpacity(world, tile, tileLib))
    region.opacityInitialized = true
    info &"Flag initialization time : {(relTime() - t)}"

proc updateFlags(world: LiveWorld, regionEnt: Entity, pos: Vec3i) =
  let region = regionEnt[Region]
  let tileLib = library(TileKind)
  let curOpacity = opacity(region, pos.x, pos.y, pos.z)
  let newOpacity = computeOpacity(world, region.tilePtr(pos.x,pos.y,pos.z), tileLib)
  if curOpacity != newOpacity:
    world.eventStmts(OpacityUpdatedEvent(region: regionEnt, area: recti(pos.x, pos.y, 1, 1), layer: pos.z, oldOpacity: curOpacity, newOpacity: newOpacity)):
      region.setOpacity(pos.x,pos.y,pos.z, newOpacity)

proc updateFlagsAtEntity(world: LiveWorld, ent: Entity) =
  if ent.hasData(Physical):
    updateFlags(world, ent[Physical].region, ent[Physical].position)

proc initializeFlags(world: LiveWorld) =
  for regionEnt in world.entitiesWithData(Region):
    initializeFlags(world, regionEnt)

method initialize(g: TileComponent, world: LiveWorld) =
  g.name = "TileComponent"
  initializeFlags(world)

method update(g: TileComponent, world: LiveWorld) =
  discard

method onEvent(g: TileComponent, world: LiveWorld, event: Event) =
  postMatcher(event):
    extract(RegionInitializedEvent, region):
      initializeFlags(world, region)
    extract(TileChangedEvent, region, tilePosition):
      updateFlags(world, region, tilePosition)
    extract(EntityDestroyedEvent, entity):
      if entity.hasData(Physical):
        updateFlags(world, entity[Physical].region, entity[Physical].position)
    extract(TileLayerDestroyedEvent, region, tilePosition):
      updateFlags(world, region, tilePosition)
    extract(EntityPlacedEvent, entity):
      updateFlagsAtEntity(world, entity)
    extract(EntityMovedToInventoryEvent, entity):
      updateFlagsAtEntity(world, entity)



