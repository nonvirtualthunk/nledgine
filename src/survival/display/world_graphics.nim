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

type
  WorldGraphicsComponent* = ref object of GraphicsComponent
    canvas: Canvas[SimpleVertex,uint32]
    needsUpdate: bool
    
  DynamicEntityGraphicsComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    needsUpdate: bool
    lastDrawn: WorldEventClock



method initialize(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "WorldGraphicsComponent"
  g.canvas = createCanvas[SimpleVertex,uint32]("shaders/simple", 2048, "WorldGraphics")
  g.canvas.syncCamera = false
  g.canvas.drawOrder = 10
  g.needsUpdate = true

method onEvent*(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  postMatcher(event):
    extract(WorldInitializedEvent):
      g.needsUpdate = true
    extract(EntityDestroyedEvent):
      g.needsUpdate = true
    extract(TileLayerDestroyedEvent):
      g.needsUpdate = true
    extract(ItemPlacedEvent):
      g.needsUpdate = true
    extract(ItemMovedToInventoryEvent):
      g.needsUpdate = true
    extract(VisionChangedEvent):
      g.needsUpdate = true
    extract(IgnitedEvent):
      g.needsUpdate = true
    extract(ExtinguishedEvent):
      g.needsUpdate = true


proc render(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld) =
  withWorld(world):
    let tileLib = library(TileKind)

    var r : Rand = initRand(programStartTime.toTime.toUnix)

    var activeRegion : Entity

    let player = toSeq(world.entitiesWithData(Player))[0]
    for region in world.entitiesWithData(Region):
      if region[Region].entities.contains(player):
        activeRegion = region
        break

    if activeRegion.isSentinel:
      err "Sentinel entity for region in world display?"

    let vision = player[Player].vision
    let playerPos = player[Physical].position
    let visionRange = player[Player].visionRange


    var qb = QuadBuilder()
    let rlayer = layer(activeRegion, world, MainLayer)
    for x in playerPos.x - visionRange - 1 .. playerPos.x + visionRange + 1:
      for y in countdown(playerPos.y + visionRange + 1, playerPos.y - visionRange - 1):
        let dx = x - playerPos.x
        let dy = y - playerPos.y
        let d2 = dx*dx + dy*dy
        if d2 == 0 or sqrt(d2.float) <= visionRange.float32 + 1.0f:
          discard
        else:
          continue

        let t = tilePtr(rlayer, x, y)

        let subDim = 24.0f32 / VisionResolution.float32

        var maxVision = 0.0
        for sy in 0 ..< VisionResolution:
          for sx in 0 ..< VisionResolution:
            let sxp = sx.float32 / VisionResolution.float32
            let syp = sy.float32 / VisionResolution.float32
            let v = pow(vision.atWorldCoord(x, y, playerPos.x, playerPos.y, sx, sy, VisionResolution).float / 255.0, 2.0)
            maxVision = max(maxVision, v)

            if v > 0.0:
              let p = vec2f(x.float * 24.0f + sx.float * subDim, y.float * 24.0f + sy.float * subDim)

              qb.textureSubRect = rect(sxp, syp, 1.0f32 / VisionResolution.float32, 1.0f32 / VisionResolution.float32)
              qb.dimensions = vec2f(subDim, subDim)
              qb.position = vec3f(p.x, p.y, 0.0f)
              if t.floorLayers.nonEmpty:
                let tileInfo = tileLib[t.floorLayers[^1].tileKind]
                qb.texture = tileInfo.images[0]
                qb.color = rgba(1.0f,1.0f,1.0f,v)
                qb.drawTo(g.canvas)

              if t.wallLayers.nonEmpty:
                let wallInfo = tileLib[t.wallLayers[^1].tileKind]
                qb.texture = wallInfo.wallImages[0]
                qb.color = rgba(1.0f,1.0f,1.0f,v)
                qb.drawTo(g.canvas)

        var offset = 0
        for ent in t.entities:
          if ent.hasData(Physical):
            let phys = ent.data(Physical)
            if not phys.dynamic:

              if phys.capsuled:
                qb.dimensions = vec2f(16.0f,16.0f)
                qb.position = vec3f(phys.position.x.float * 24.0f + 4.0f, phys.position.y.float * 24.0f + 6.0f - offset.float, 0.0f)
              else:
                qb.dimensions = vec2f(24.0f, 24.0f)
                qb.position = vec3f(x.float * 24.0f, y.float * 24.0f, 0.0f)

              qb.texture = phys.images[0]
              qb.color = rgba(1.0f,1.0f,1.0f, maxVision)
              qb.textureSubRect = rect(0.0f32,0.0f32,0.0f32,0.0f32)
              qb.drawTo(g.canvas)

              if ent.hasData(Fire) and ent[Fire].active:
                qb.position = vec3f(x.float * 24.0f, y.float * 24.0f + 6.0f, 0.0f)
                qb.texture = image("survival/graphics/effects/fire_c_24.png")
                qb.dimensions = vec2f(24.0f,24.0f)
                qb.color = rgba(1.0f,1.0f,1.0f,maxVision)
                qb.drawTo(g.canvas)

              offset += 4


method update(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.needsUpdate:
    render(g, world, display)
    g.canvas.swap()
    g.needsUpdate = false

  @[g.canvas.drawCommand(display)]





method initialize(g: DynamicEntityGraphicsComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "DynamicEntityGraphicsComponent"
  g.canvas = createSimpleCanvas("shaders/simple")
  g.canvas.drawOrder = 15
  g.lastDrawn = WorldEventClock(-2)

method onEvent*(g: DynamicEntityGraphicsComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  discard
    


proc render(g: DynamicEntityGraphicsComponent, world: LiveWorld, display: DisplayWorld) =
  withWorld(world):
   let tileLib = library(TileKind)

   var r : Rand = initRand(programStartTime.toTime.toUnix)

   var activeRegion : Entity

   let player = toSeq(world.entitiesWithData(Player))[0]
   for region in world.entitiesWithData(Region):
     if region[Region].entities.contains(player):
       activeRegion = region
       break

   if activeRegion.isSentinel:
     err "Sentinel entity for region in world display?"

   var qb = QuadBuilder()
   for ent in activeRegion[Region].dynamicEntities:
     if ent.hasData(Physical):
       let phys = ent.data(Physical)
       qb.dimensions = vec2f(24.0f,24.0f)
       qb.position = vec3f(phys.position.x.float * 24.0f, phys.position.y.float * 24.0f, 0.0f)
       qb.texture = phys.images[0]
       qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
       qb.drawTo(g.canvas)

       if ent.hasData(Creature) and ent.hasData(Player):
         if phys.facing != Direction.Center:
           qb.position += vector3fFor(phys.facing) * 24
           qb.color = rgba(1.0f,1.0f,1.0f,0.5f)
           qb.texture = case phys.facing:
             of Direction.Left: image("survival/icons/close_left_arrow.png")
             of Direction.Up: image("survival/icons/close_up_arrow.png")
             of Direction.Right: image("survival/icons/close_right_arrow.png")
             of Direction.Down: image("survival/icons/close_down_arrow.png")
             of Direction.Center: image("survival/icons/center.png")
           qb.drawTo(g.canvas)


method update(g: DynamicEntityGraphicsComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  withWorld(world):
    var commands = if g.lastDrawn < world.currentTime:
      render(g, world, display)
      g.canvas.swap()
      g.lastDrawn = world.currentTime

      for player in world.entitiesWithData(Player):
        let pos = player.data(Physical).position
        display[CameraData].camera.moveTo(vec3f(pos.x.float * 24.0f, pos.y.float * 24.0f, 0.0f))

      @[g.canvas.drawCommand(display), DrawCommand(kind: DrawCommandKind.CameraUpdate, camera: display[CameraData].camera)]
     else:
      @[]

    commands





