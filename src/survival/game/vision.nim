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

type
  VisionComponent* = ref object of LiveGameComponent
    shadowGrid*: ShadowGrid[64]
    precomputed*: array[4,ref ShadowGrid[64]]
    precomputedPositions*: array[4, Vec2i]
    needsRecompute: bool

  LightingComponent* = ref object of LiveGameComponent
    lastComputedRegion*: Entity
    shadowGrid*: ShadowGrid[64]



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




type
  LocalIlluminationSource = object
    position*: Vec3i
    brightness*: int
    color*: RGBA
    lightGrid*: ref ShadowGrid[LocalLightRadius]

  LocalIllumination = object
    sources*: seq[LocalIlluminationSource]


proc localIlluminationBrightnessAndColor*(world: LiveWorld, e: Entity): (int, RGBA) =
  if isSurvivalEntityDestroyed(world, e):
    return (0, rgba(255,255,255,255))

  let lsOpt = e.dataOpt(LightSource)
  if e.hasData(Fire) and e[Fire].active:
    if lsOpt.isSome and lsOpt.get.fireLightSource:
      (lsOpt.get.brightness, lsOpt.get.lightColor)
    else:
      (12, rgba(255,200,150,255))
  elif lsOpt.isSome and not lsOpt.get.fireLightSource:
    (lsOpt.get.brightness, lsOpt.get.lightColor)
  else:
    (0, rgba(255,255,255,255))

proc localIlluminationSource*(world: LiveWorld, e: Entity): Option[LocalIlluminationSource] =
  if e.hasData(Physical):
    let lsOpt = e.dataOpt(LightSource)
    let (brightness, color) = localIlluminationBrightnessAndColor(world, e)

    if brightness > 0 and lsOpt.isSome:
      some(LocalIlluminationSource(position: effectivePosition(world, e), brightness: brightness, color: color, lightGrid: lsOpt.get.lightGrid))
    elif brightness > 0:
      some(LocalIlluminationSource(position: effectivePosition(world, e), brightness: brightness, color: color))
    else:
      none(LocalIlluminationSource)
  else:
    none(LocalIlluminationSource)

## Note: only returns _computed_ local illumination sources. A fire that has not yet had its lighting computed will not show up here
## this is appropriate for computing the effective illumination at a point, but not for doing the illumination itself
proc localIlluminationSources*(world:  LiveWorld, regionEnt: Entity, viewCenter: Vec3i, visionRange: int, filterByDistance: bool = true) : LocalIllumination =
  for e in world.entitiesWithData(LightSource):
    let phys = e[Physical]
    let pos = effectivePosition(world, e)
    if phys.region == regionEnt and (not filterByDistance or viewCenter.z == pos.z):
      let rx = pos.x - viewCenter.x
      let ry = pos.y - viewCenter.y
      let liOpt = localIlluminationSource(world, e)
      if liOpt.isSome:
        let brightness = liOpt.get.brightness
        if not filterByDistance or (rx.abs <= brightness + visionRange and ry.abs <= brightness + visionRange):
          if liOpt.get.lightGrid != nil:
            result.sources.add(liOpt.get)

proc allLocalIlluminationSources*(world: LiveWorld, regionEnt: Entity): LocalIllumination =
  localIlluminationSources(world, regionEnt, vec3i(0,0,0), 10000, false)


proc localIlluminationAt*(li: LocalIllumination, x: int, y: int, sx: int, sy: int, strengthOut: var float32, liColorOut: var RGBA) =
  if li.sources.isEmpty:
    liColorOut.r = 0u8
    liColorOut.g = 0u8
    liColorOut.b = 0u8
    strengthOut = 0.0f32
  else:
    if li.sources.len == 1:
      let src = li.sources[0]
      let rx = x - src.position.x
      let ry = y - src.position.y
      if rx > -LocalLightRadiusWorldResolution and ry < LocalLightRadiusWorldResolution and ry > -LocalLightRadiusWorldResolution and ry < LocalLightRadiusWorldResolution:
        strengthOut = src.lightGrid[rx * ShadowResolution + sx,ry * ShadowResolution + sy].float32 / 255.0f32
        liColorOut = src.color
    else:
      var sumR = 0.0f32
      var sumG = 0.0f32
      var sumB = 0.0f32

      var sum = 0.0f32
      strengthOut = 0.0f32

      for src in li.sources:
        let rx = x - src.position.x
        let ry = y - src.position.y
        if rx > -LocalLightRadiusWorldResolution and ry < LocalLightRadiusWorldResolution and ry > -LocalLightRadiusWorldResolution and ry < LocalLightRadiusWorldResolution:
          let l = src.lightGrid[rx * ShadowResolution + sx,ry * ShadowResolution + sy].float32 / 255.0f32
          sum += l
          strengthOut = max(strengthOut, l)
          sumR += src.color.ri.float32 * l
          sumG += src.color.gi.float32 * l
          sumB += src.color.bi.float32 * l

      if sum > 0.0f32:
        liColorOut.ri = clamp((sumR / sum).uint8, 0, 255)
        liColorOut.gi = clamp((sumG / sum).uint8, 0, 255)
        liColorOut.bi = clamp((sumB / sum).uint8, 0, 255)



proc updateGlobalIllumination(g: LightingComponent, world: LiveWorld, regionEnt: Entity, area: Option[Recti] = none(Recti), layer: Option[int] = none(int)) =
  let region = regionEnt[Region]
  let z = MainLayer
  proc obstruction(x: int, y : int) : float32 =
    if x > -RegionHalfSize and x < RegionHalfSize and y > -RegionHalfSize and y < RegionHalfSize:
      opacity(region, x,y,z).float32 / 255.0f32
    else:
      1.0f32

  if area.isSome and area.get.width <= 3 and area.get.height <= 3:
    let a = area.get
    for x in a.x ..< a.x + a.width:
      for y in a.y ..< a.y + a.height:
        suncast(region.globalIllumination, vec2i(0,0), some(vec2i(x,y)), ShadowResolution, region.globalShadowLength.int32, obstruction)
  else:
    suncast(region.globalIllumination, vec2i(0,0), none(Vec2i), ShadowResolution, region.globalShadowLength.int32, obstruction)



proc updateLocalIllumination(g: LightingComponent, world: LiveWorld, regionEnt: Entity, lightEnt: Entity) =
  # first, check if this is actually a light source of some kind
  let (brightness, _) = localIlluminationBrightnessAndColor(world, lightEnt)

  let e = lightEnt
  # if there is no brightness either this is not a light source, or it's a light source that has just gone out
  if brightness == 0:
    # if it has just gone out, then clear its lighting
    if e.hasData(LightSource):
      world.eventStmts(LocalLightingChangedEvent(lightEntity: e)):
        let ls = e[LightSource]
        if ls.lightGrid != nil:
          ls.lightGrid.reset()
  elif e.hasData(Physical):
    let region = regionEnt[Region]
    let z = lightEnt[Physical].position.z
    proc obstruction(x: int, y : int) : float32 =
      if x > -RegionHalfSize and x < RegionHalfSize and y > -RegionHalfSize and y < RegionHalfSize:
        opacity(region, x,y,z).float32 / 255.0f32
      else:
        1.0f32

    let position = effectivePosition(world, e)

    if not e.hasData(LightSource):
      e.attachData(LightSource)
    let ls = e[LightSource]
    if ls.lightGrid == nil:
      ls.lightGrid = new ShadowGrid[64]

    let brightnessf = brightness.float
    proc attenuation(d : float) : float =
      let pcnt = d / brightnessf
      max(1.0 - pcnt, 0.0)

    world.eventStmts(LocalLightingChangedEvent(lightEntity: e)):
      shadowcast(g.shadowGrid, ls.lightGrid[], position.xy, ShadowResolution, attenuation, obstruction)
  else:
    warn &"Non-physical light source: {debugIdentifier(world, e)}?"


proc updateLocalIllumination(g: LightingComponent, world: LiveWorld, regionEnt: Entity, area: Option[Recti] = none(Recti), layer: Option[int] = none(int)) =
  for e in entitiesWithEitherData(world, LightSource, Fire):
    updateLocalIllumination(g, world, regionEnt, e)

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
        updateLocalIllumination(g, world, region, some(area), some(layer))
    extract(OpacityInitializedEvent, region):
      if region[Region].initialized:
        updateGlobalIllumination(g, world, region, none(Recti), none(int))
        updateLocalIllumination(g, world, region, none(Recti), none(int))
    extract(IgnitedEvent, target):
      case target.kind:
        of TargetKind.Entity:
          updateLocalIllumination(g, world, target.entity[Physical].region, target.entity)
        else:
          warn &"Igniting non-entity targets not yet supported in lighting component {target}"
    extract(ExtinguishedEvent, extinguishedEntity):
      updateLocalIllumination(g, world, extinguishedEntity[Physical].region, extinguishedEntity)
    extract(EntityDestroyedEvent, entity):
      if entity.hasData(Physical):
        updateLocalIllumination(g, world, entity[Physical].region, entity)
    extract(CreatureMovedEvent, entity):
      updateLocalIllumination(g, world, entity[Physical].region, entity)
      for e in allEquippedItems(entity[Creature]):
        updateLocalIllumination(g, world, entity[Physical].region, e)

