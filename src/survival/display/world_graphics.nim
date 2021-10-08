import engines

import graphics/canvas
import graphics/color
import options
import prelude
import reflect
import resources
import graphics/images
import glm
import random
import times
import tables
import game/library
import survival/game/tiles
import sequtils
import survival/game/events
import survival/game/entities
import worlds
import sets
import noto
import windowingsystem/windowingsystem
import graphics/camera_component
import graphics/cameras
import core
import survival/game/survival_core
import survival/game/logic
import worlds/identity
import survival/game/vision
import game/shadowcasting
import arxmath
import math
import core/metrics
import graphics/tileset
import nimgl/[glfw, opengl]
import core/poisson_disk
import core/quadtree

type
  WorldGraphicsComponent* = ref object of GraphicsComponent
    canvas: Canvas[SimpleVertex,uint32]
    needsUpdate: bool
    renderTimer: Timer
    tileset: Tileset
    poisson: PoissonDiskSampling
    defaultVision: ref ShadowGrid[64]
    
  DynamicEntityGraphicsComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    needsUpdate: bool
    lastDrawn: WorldEventClock

  SurvivalCameraData* = object
    povEntity*: Entity

  GlobalIlluminationSettings* = object
    region*: ref Region
    ambientLight*: float
    ambientLightColor*: RGBA
    maxShadowLength*: int
    shadowFract*: float
    minGlobalIlluminationInShadow*: float


defineDisplayReflection(SurvivalCameraData)



proc globalIlluminationSettings*(world: LiveWorld, activeRegion : Entity) : GlobalIlluminationSettings =
  result.region = activeRegion[Region]

  let (timeOfDay,dayNightFract) = timeOfDay(world, activeRegion)
  # let sigmoided = if dayNightFract < 0.5:
  #   let x = dayNightFract * 2.0f
  #   1.0f/(1.0f+pow(2.0f,((-x*12.0f+6.0f))))
  # else:
  #   let x = (dayNightFract - 0.5f)*2.0f
  #   1.0f - (1.0f/(1.0f+pow(2.0f,((-x*12.0f+6.0f)))))
  let sigmoided = if dayNightFract < 0.5f:
    dayNightFract * 2.0f
  else:
    1.0f - (dayNightFract - 0.5f) * 2.0f

  result.ambientLight = case timeOfDay:
    of DayNight.Day: sigmoided * 0.9 + 0.1d
    of DayNight.Night: 0.1

  result.maxShadowLength = result.region.globalShadowLength
  case timeOfDay:
    of DayNight.Day:
      let daySin = sigmoided # [0,1)
      result.shadowFract = daySin
      result.ambientLightColor = mix(rgba(255,210,180,255), rgba(255,255,255,255), result.shadowFract)
    of DayNight.Night:
      result.shadowFract = 0.0f32
      result.ambientLightColor = rgba(205,215,255,255)

  # The minimum amount that a global shadow can reduce the ambient illumination to
  result.minGlobalIlluminationInShadow = 0.3f


proc globalIlluminationAt*(gis: GlobalIlluminationSettings, wx: int, wy: int, sx: int, sy: int) : float32 =
  if gis.shadowFract > 0.0:
    let raw = gis.region.globalIllumination.atWorldCoord(wx, wy, 0, 0, sx, sy, ShadowResolution).float32 / 255.0f32
    # Adjust by time of day making shadows longer or shorter
    let adjusted = raw / (1.0 - gis.shadowFract)
    let illum = gis.minGlobalIlluminationInShadow + clamp(adjusted, 0.0f32, 1.0f32) * (1.0f32 - gis.minGlobalIlluminationInShadow)
    gis.ambientLight * illum
  else:
    gis.ambientLight

# proc globalIlluminationNormAt*(gis: GlobalIlluminationSettings, wx: int, wy: int, sx: int, sy: int) : float32 =
#   if gis.shadowFract > 0.0:
#     let raw = gis.region.globalIllumination.atWorldCoord(wx, wy, 0, 0, sx, sy, ShadowResolution).float32 / 255.0f32
#     # Adjust by time of day making shadows longer or shorter
#     let adjusted = raw / (1.0 - gis.shadowFract)
#     let illum = gis.minGlobalIlluminationInShadow + clamp(adjusted, 0.0f32, 1.0f32) * (1.0f32 - gis.minGlobalIlluminationInShadow)
#     gis.ambientLight * illum
#   else:
#     gis.ambientLight


method initialize(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "WorldGraphicsComponent"
  g.canvas = createCanvas[SimpleVertex,uint32]("shaders/simple", 2048, "WorldGraphics")
  g.canvas.renderSettings.depthTestEnabled = true
  g.canvas.renderSettings.depthFunc = GL_LEQUAL
  g.canvas.syncCamera = false
  g.canvas.drawOrder = 10
  g.needsUpdate = true
  g.renderTimer = Timer(name: "WorldGraphicsComponent.render")
  g.timers = @[g.renderTimer]
  g.poisson = generatePoissonDiskSample(RegionSize, RegionSize)

  let tileLib = library(TileKind)
  var tiles : seq[ref TilesetTile]
  tiles.setLen(maxID(tileLib).uint32 + 1)
  for id, v in tileLib.pairsById:
    tiles[id.uint32] = new TilesetTile
    tiles[id.uint32][] = v.tileset
  g.tileset = createTileset(tiles)

const TileSize = 32.0f32

proc render(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld) =
  let timing = g.renderTimer.start()
  withWorld(world):
    let tileLib = library(TileKind)

    var r : Rand = initRand(programStartTime.toTime.toUnix)

    let cam = display[SurvivalCameraData]

    let povEnt = cam.povEntity
    let activeRegion = regionFor(world, povEnt)
    let reg = activeRegion[Region]

    let nearbyEntities = reg.entityQuadTree.getNear(povEnt[Physical].position.x, povEnt[Physical].position.y, 5)
    var nearbyEntitiesSet : HashSet[Entity]
    for e in nearbyEntities:
      nearbyEntitiesSet.incl(e)

    let vision = if povEnt.hasData(Player):
      povEnt[Player].vision
    else:
      if g.defaultVision.isNil:
        g.defaultVision = new ShadowGrid[64]
        g.defaultVision.fill(255)
      g.defaultVision

    let povEntPos = povEnt[Physical].position
    let visionRange = povEnt[Creature].visionRange
    let visionRange2 = visionRange * visionRange

    let gis = globalIlluminationSettings(world, activeRegion)
    let lis = localIlluminationSources(world, activeRegion, povEntPos, povEnt[Creature].visionRange)

    var localLightColor : RGBA
    var localLightStrength: float32

    let voidTile = tileLib.libTaxon(† TileKinds.Void)

    var tks: array[4, int]

    let subDim = TileSize / VisionResolution.float32
    var tileRenderer = createTilesetRenderer(TileSize, g.tileset, g.canvas)

    var qb = QuadBuilder()
    var tb = TriBuilder()
    let rlayer = layer(activeRegion, world, MainLayer)
    for x in max(povEntPos.x - visionRange - 1, -RegionHalfSize + 1) .. min(povEntPos.x + visionRange + 1, RegionHalfSize - 1):
      for y in countdown(min(povEntPos.y + visionRange + 1, RegionHalfSize - 1), max(povEntPos.y - visionRange - 1, -RegionHalfSize + 1)):
        let dx = x - povEntPos.x
        let dy = y - povEntPos.y
        let d2 = dx*dx + dy*dy
        if d2.float > visionRange2.float32 + 1.0f: continue

        # normal vector, relative to the povEnt, guaranteed to be entirely along either the x or y axis
        let normal = if dx.abs > dy.abs: vec2i(sgn(-dx),0) else: vec2i(0, sgn(-dy))

        let t = tilePtr(rlayer, x, y)
        let floorKind = if t.floorLayers.nonEmpty: t.floorLayers[^1].tileKind
                        else: voidTile

        var maxGlobalLight = 0.0
        var maxLocalLight = 0.0
        var maxVision = 0.0
        for sy in 0 ..< VisionResolution:
          for sx in 0 ..< VisionResolution:
            let sxp = sx.float32 / VisionResolution.float32
            let syp = sy.float32 / VisionResolution.float32
            let v = pow(vision.atWorldCoord(x, y, povEntPos.x, povEntPos.y, sx, sy, VisionResolution).float / 255.0, 2.0)
            if v > 0.0:
              let n = vec2i(sx * 2 - 1, sy * 2 - 1)
              maxVision = max(maxVision, v)
              let gi = gis.globalIlluminationAt(x,y,sx,sy)
              maxGlobalLight = max(maxGlobalLight, gi)
              localIlluminationAt(lis, x, y, sx, sy, localLightStrength, localLightColor)
              maxLocalLight = max(maxLocalLight, localLightStrength)

              let p = vec2f(x.float32 * TileSize + sx.float32 * subDim, y.float32 * TileSize + sy.float32 * subDim)


              let axtile = tilePtr(rlayer, x + n.x, y)
              let aytile = tilePtr(rlayer, x, y + n.y)
              let adtile = tilePtr(rlayer, x + n.x, y + n.y)

              qb.textureSubRect = rect(sxp, syp, 1.0f32 / VisionResolution.float32, 1.0f32 / VisionResolution.float32)
              qb.dimensions = vec2f(subDim, subDim)
              qb.position = vec3f(p.x, p.y, g.tileset.tiles[floorKind].layer.float32)
              qb.texture = g.tileset.tiles[floorKind].center
              qb.color = mix(gis.ambientLightColor, localLightColor, gi, localLightStrength) * max(gi, localLightStrength)
              qb.color.a = v
              qb.drawTo(g.canvas)

              tks[0] = if axtile.floorLayers.nonEmpty: axtile.floorLayers[^1].tileKind.id.int else: voidTile.id.int
              tks[1] = if aytile.floorLayers.nonEmpty: aytile.floorLayers[^1].tileKind.id.int else: voidTile.id.int
              tks[2] = floorKind.id.int
              tks[3] = if adtile.floorLayers.nonEmpty: adtile.floorLayers[^1].tileKind.id.int else: voidTile.id.int

              tb.color = qb.color
              renderTileEdges(tileRenderer, qb, tb, tks, x, y, sx, sy)

              if t.wallLayers.nonEmpty:
                let normGI = gis.globalIlluminationAt(x, y, sx  + normal.x, sy + normal.y)
                localIlluminationAt(lis, x + normal.x, y + normal.y, sx, sy, localLightStrength, localLightColor)
                let wallInfo = tileLib[t.wallLayers[^1].tileKind]
                qb.texture = wallInfo.wallImages[0]
                qb.color = mix(gis.ambientLightColor, localLightColor, normGI, localLightStrength) * max(normGI, localLightStrength)
                qb.color.a = v
                qb.drawTo(g.canvas)


        let maxLight = max(maxGlobalLight, maxLocalLight)
        let premixedColor = mix(gis.ambientLightColor, localLightColor, maxGlobalLight, maxLocalLight)

        let pi = g.poisson.pointIndexAt(x + RegionHalfSize,y + RegionHalfSize)
        if pi.isSome and pi.get mod 7 == 0:
          let p = g.poisson.points[pi.get] - vec2f(RegionHalfSize, RegionHalfSize)

          # var allSame = true
          # for dx in countup(-1,1,2):
          #   for dy in countup(-1,1,2):
          #     let ax = (p.x + dx.float32 * 0.6f32)
          #     let ay = (p.y + dy.float32 * 0.6f32)
          #     if ax.int.abs < RegionHalfSize and ay.int.abs < RegionHalfSize:
          #       let atile = tilePtr(rlayer, ax.int, ay.int)
          #       let k = if atile.floorLayers.nonEmpty: atile.floorLayers[^1].tileKind.id.int else: voidTile.id.int
          #       if k != floorKind.id.int:
          #         allSame = false
          #         break
          # if allSame:
          let tilesetTile = g.tileset.tiles[floorKind]
          if tilesetTile.decor.len > 0 and t.wallLayers.isEmpty:
            let decor = tilesetTile.decor[(pi.get div 7) mod tilesetTile.decor.len]
            qb.position = vec3f(x.float32 * TileSize + TileSize * 0.25f32, y.float32 * TileSize + TileSize * 0.25f32, tilesetTile.layer.float32 + 0.2f32)
            qb.texture = decor.asImage
            qb.textureSubRect = rectf(0.0f32,0.0f32,0.0f32,0.0f32)
            qb.color = premixedColor * max(maxLocalLight, maxGlobalLight)
            qb.color.a = maxVision
            qb.dimensions = vec2f(TileSize * 0.5f32, TileSize * 0.5f32)
            qb.drawTo(g.canvas)

        # if t.floorLayers.isEmpty and y < RegionHalfSize:
        #   let upT = tilePtr(rlayer, x, y + 1)
        #   if upT.floorLayers.nonEmpty:
        #     let upLayerKind = tileLib[upT.floorLayers[^1].tileKind]
        #     if upLayerKind.dropImages.nonEmpty:
        #       qb.position = vec3f(x.float * 24.0f, y.float * 24.0f, 0.0f)
        #       qb.texture = upLayerKind.dropImages[0]
        #       qb.textureSubRect = rect(0.0f32,0.0f32,0.0f32,0.0f32)
        #       qb.dimensions = vec2f(TileSize, TileSize)
        #       qb.color = premixedColor * maxLight
        #       qb.color.a = maxVision
        #       qb.drawTo(g.canvas)

        if maxVision > 0.01:
          var offset = 0
          for ent in t.entities:
            let phys = ent.data(Physical)
            let img = phys.images[0].asImage
            var gi = 0.0
            if phys.blocksLight:
              gi = max(gis.ambientLight, maxLight)
            else:
              gi = maxLight

            if phys.capsuled:
              qb.dimensions = vec2f(16.0f,16.0f)
              qb.position = vec3f(phys.position.x.float * TileSize + 4.0f, phys.position.y.float * TileSize + 6.0f - offset.float, 10.0f)
            else:
              qb.dimensions = vec2f(img.width, img.height)
              qb.position = vec3f(x.float * TileSize + (TileSize - img.width.float32) * 0.5f32, y.float * TileSize, 10.0f)


            qb.texture = img
            qb.color = premixedColor * gi
            # if nearbyEntitiesSet.contains(ent):
            #   qb.color.r = 0
            qb.color.a = maxVision
            qb.textureSubRect = rect(0.0f32,0.0f32,0.0f32,0.0f32)
            qb.drawTo(g.canvas)

            if ent.hasData(Gatherable):
              for rsrc in ent[Gatherable].resources:
                if rsrc.image.isSome and rsrc.quantity.currentValue > 0:
                  qb.texture = rsrc.image.get.asImage
                  qb.drawTo(g.canvas)

            if ent.hasData(Fire) and ent[Fire].active:
              qb.position = vec3f(x.float * TileSize, y.float * TileSize + 6.0f, 10.0f)
              qb.texture = image("survival/graphics/effects/fire_c_24.png")
              qb.dimensions = vec2f(24.0f,24.0f)
              qb.color = rgba(1.0f,1.0f,1.0f,maxVision)
              qb.drawTo(g.canvas)

            offset += 4

            if ent.hasData(Creature) and ent.hasData(Player):
              if phys.facing != Direction.Center:
                qb.position += vector3fFor(phys.facing) * TileSize
                qb.color = rgba(1.0f,1.0f,1.0f,0.5f)
                qb.texture = case phys.facing:
                  of Direction.Left: image("survival/icons/close_left_arrow.png")
                  of Direction.Up: image("survival/icons/close_up_arrow.png")
                  of Direction.Right: image("survival/icons/close_right_arrow.png")
                  of Direction.Down: image("survival/icons/close_down_arrow.png")
                  of Direction.Center: image("survival/icons/center.png")
                qb.drawTo(g.canvas)
  timing.finish()


method update(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.needsUpdate:
    render(g, world, display)
    g.canvas.swap()
    g.needsUpdate = false

    @[g.canvas.drawCommand(display)]
  else:
    @[]


method onEvent*(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  postMatcher(event):
    extract(WorldInitializedEvent):
      g.needsUpdate = true
    extract(EntityDestroyedEvent):
      g.needsUpdate = true
    extract(TileLayerDestroyedEvent):
      g.needsUpdate = true
    extract(EntityPlacedEvent):
      g.needsUpdate = true
    extract(EntityMovedToInventoryEvent):
      g.needsUpdate = true
    extract(VisionChangedEvent):
      g.needsUpdate = true
    extract(IgnitedEvent):
      g.needsUpdate = true
    extract(ExtinguishedEvent):
      g.needsUpdate = true
    extract(LocalLightingChangedEvent):
      g.needsUpdate = true
    extract(GameEvent):
      g.needsUpdate = true

  matcher(event):
    extract(CameraChangedEvent):
      g.needsUpdate = true



method initialize(g: DynamicEntityGraphicsComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "DynamicEntityGraphicsComponent"
  g.lastDrawn = WorldEventClock(-2)
  g.updatePriority = 10000
  if not display.hasData(SurvivalCameraData):
    display.attachData(SurvivalCameraData(povEntity: player(world)))

method onEvent*(g: DynamicEntityGraphicsComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  discard

method update(g: DynamicEntityGraphicsComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let cam = display[SurvivalCameraData]

  let pos = cam.povEntity[Physical].position
  if display[CameraData].camera.eye != vec3f(pos.x.float * TileSize, pos.y.float * TileSize, 0.0f):
    display[CameraData].camera.moveTo(vec3f(pos.x.float * TileSize, pos.y.float * TileSize, 0.0f))
    display.addEvent(CameraChangedEvent())

  @[DrawCommand(kind: DrawCommandKind.CameraUpdate, camera: display[CameraData].camera)]





