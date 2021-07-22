import engines
import worlds
import tiles
import events
import prelude
import logic
import game/shadowcasting
import entities
import noto
import glm
import tiles
import game/grids
import graphics/color
import arxmath

import graphics/images

const VisionResolution* = 2
const ShadowResolution* = 2

type
  VisionComponent* = ref object of LiveGameComponent
    shadowGrid*: ShadowGrid[64]
    precomputed*: array[4,ref ShadowGrid[64]]
    precomputedPositions*: array[4, Vec2i]
    needsRecompute: bool

  LightingComponent* = ref object of LiveGameComponent
    lastComputedRegion*: Entity



proc computeVision(g: VisionComponent, world: LiveWorld, entity: Entity, offset: Vec2i, vision: ref ShadowGrid[64]) =
  if not entity.hasData(Player):
    err &"Full vision updates only make sense for entities with Player data: {debugIdentifier(world, entity)}"
    return

  let PD = entity[Player]
  let phys = entity[Physical]
  vision.reset()
  g.shadowGrid.reset()

  let reg = phys.region[Region]
  let z = phys.position.z

  let attenuationRange = PD.visionRange.float32
  proc attenuation(d : float) : float =
    let pcnt = d / attenuationRange
    if pcnt > 1.0:
      0.0
    elif pcnt > 0.95:
      1.0 - (pcnt - 0.95) / 0.05
    else:
      1.0

  proc obstruction(x: int, y : int) : float32 =
    if x > -RegionHalfSize and x < RegionHalfSize and y > -RegionHalfSize and y < RegionHalfSize:
      opacity(reg, x,y,z).float32 / 255.0f32
    else:
      1.0f32
    # if reg.tile(x,y,z).wallLayers.nonEmpty:
    #   return 1.0
    #
    # for ent in reg.tile(x,y,z).entities:
    #   if ent[Physical].occupiesTile:
    #     return 1.0
    #
    # return 0.0

  shadowcast(g.shadowGrid, vision[], phys.position.xy + offset, VisionResolution, attenuation, obstruction)


proc updateVision(g: VisionComponent, world: LiveWorld, entity: Entity) =
  if not entity.hasData(Player):
    err &"Full vision updates only make sense for entities with Player data: {debugIdentifier(world, entity)}"
    return

  let PD = entity[Player]
  let phys = entity[Physical]

  for i in 0 ..< 4:
    if g.precomputedPositions[i] == phys.position.xy:
      swap(PD.vision, g.precomputed[i])
      g.precomputedPositions[i] = vec2i(-1000,-1000)
      world.addFullEvent(VisionChangedEvent(entity: entity))
      return

  computeVision(g, world, entity, vec2i(0,0), PD.vision)

  world.addFullEvent(VisionChangedEvent(entity: entity))


method update(g: VisionComponent, world: LiveWorld) =
  let player = player(world)

  for i in 0 ..< 4:
    let delta = CardinalVectors2D[i]
    if g.precomputedPositions[i] != player[Physical].position.xy + delta:
      computeVision(g, world, player, delta, g.precomputed[i])
      g.precomputedPositions[i] = player[Physical].position.xy + delta
      break


method initialize(g: VisionComponent, world: LiveWorld) =
  g.name = "VisionComponent"
  for i in 0 ..< 4:
    g.precomputed[i] = new ShadowGrid[64]
    g.precomputedPositions[i] = vec2i(-100000,-10000)
  updateVision(g, world, player(world))


proc inVisionRange(world: LiveWorld, otherPos: Vec3i) : bool =
  let p = player(world)
  let pos = p[Physical].position
  pos.z == otherPos.z and otherPos.xy.distance(pos.xy) <= p[Player].visionRange.float

proc inVisionRange(world: LiveWorld, entity: Entity) : bool =
  if entity.hasData(Physical):
    let otherPos = entity[Physical].position
    inVisionRange(world, otherPos)
  else:
    false



method onEvent(g: VisionComponent, world: LiveWorld, event: Event) =
  if player(world).isSentinel: return

  var triggerUpdate = false
  var clearPrecomputations = true

  postMatcher(event):
    extract(CreatureMovedEvent, entity, region, fromPosition, toPosition):
      if entity == player(world):
        triggerUpdate = true
        clearPrecomputations = false
    extract(OpacityUpdatedEvent):
      triggerUpdate = true
    extract(OpacityInitializedEvent):
      triggerUpdate = true
    # extract(RegionInitializedEvent, region):
    #   triggerUpdate = true
    # extract(EntityDestroyedEvent, entity):
    #   triggerUpdate = inVisionRange(world, entity)
    # extract(TileLayerDestroyedEvent, tilePosition):
    #   triggerUpdate = inVisionRange(world, tilePosition)
    # extract(ItemPlacedEvent, placedEntity):
    #   triggerUpdate = inVisionRange(world, placedEntity)
    # extract(ItemMovedToInventoryEvent, entity):
    #   triggerUpdate = inVisionRange(world, entity)

  if triggerUpdate:
    if clearPrecomputations:
      for i in 0 ..< 4:
        g.precomputedPositions[i] = vec2i(-1000,-1000)
    updateVision(g, world, player(world))







proc updateGlobalIllumination(g: LightingComponent, world: LiveWorld, regionEnt: Entity, area: Option[Recti] = none(Recti), layer: Option[int] = none(int)) =
  let region = regionEnt[Region]
  let z = MainLayer
  proc obstruction(x: int, y : int) : float32 =
    if x > -RegionHalfSize and x < RegionHalfSize and y > -RegionHalfSize and y < RegionHalfSize:
      opacity(region, x,y,z).float32 / 255.0f32
    else:
      1.0f32

  if area.isSome:
    warn "Need to implement partial illumination update"
  else:
    if area.isSome and area.get.width <= 3 and area.get.height <= 3:
      let a = area.get
      for x in a.x ..< a.x + a.width:
        for y in a.y ..< a.y + a.height:
          suncast(region.globalIllumination, vec2i(0,0), some(vec2i(x,y)), ShadowResolution, region.globalShadowLength.int32, obstruction)
    else:
      suncast(region.globalIllumination, vec2i(0,0), none(Vec2i), ShadowResolution, region.globalShadowLength.int32, obstruction)

method update(g: LightingComponent, world: LiveWorld) =
  discard


method initialize(g: LightingComponent, world: LiveWorld) =
  g.name = "LightingComponent"


method onEvent(g: LightingComponent, world: LiveWorld, event: Event) =
  if player(world).isSentinel: return

  var triggerUpdate = false
  var clearPrecomputations = true

  postMatcher(event):
    extract(OpacityUpdatedEvent, region, area, layer):
      if region[Region].initialized:
        updateGlobalIllumination(g, world, region, some(area), some(layer))
    extract(OpacityInitializedEvent, region):
      if region[Region].initialized:
        updateGlobalIllumination(g, world, region, none(Recti), none(int))
