import engines

import graphics/canvas
import graphics/color
import options
import prelude
import reflect
import resources
import graphics/image_extras
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
  g.canvas = createCanvas[SimpleVertex,uint32]("shaders/simple", 2048)
  g.canvas.drawOrder = 10
  g.needsUpdate = true

method onEvent*(g: WorldGraphicsComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
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

    var qb = QuadBuilder()
    let rlayer = layer(activeRegion, world, MainLayer)
    for x in -RegionHalfSize ..< RegionHalfSize:
      for y in -RegionHalfSize ..< RegionHalfSize:
        let t = tile(rlayer, x, y)

        qb.dimensions = vec2f(24.0f,24.0f)
        qb.position = vec3f(x.float * 24.0f, y.float * 24.0f, 0.0f)
        if t.floorLayers.nonEmpty:
          let tileInfo = tileLib[t.floorLayers[^1].tileKind]
          qb.texture = tileInfo.images[0]
          qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
          qb.drawTo(g.canvas)

        if t.wallLayers.nonEmpty:
          let wallInfo = tileLib[t.wallLayers[^1].tileKind]
          qb.texture = wallInfo.wallImages[0]
          qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
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
                qb.dimensions = vec2f(24.0f,24.0f)
                qb.position = vec3f(phys.position.x.float * 24.0f, phys.position.y.float * 24.0f - offset.float, 0.0f)
              qb.texture = phys.images[0]
              qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
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
   ifOfType(WorldInitializedEvent, event):
     g.needsUpdate = true


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
    if g.lastDrawn < world.currentTime:
      render(g, world, display)
      g.canvas.swap()
      g.lastDrawn = world.currentTime

      for player in world.entitiesWithData(Player):
        let pos = player.data(Physical).position
        display[CameraData].camera.moveTo(vec3f(pos.x.float * 24.0f, pos.y.float * 24.0f, 0.0f))

    @[g.canvas.drawCommand(display)]

