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

type
  WorldGraphicsComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    needsUpdate: bool
    
  DynamicEntityGraphicsComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    needsUpdate: bool
    lastDrawn: WorldEventClock

  PlayerCameraComponent* = ref object of GraphicsComponent

method initialize(g: WorldGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.name = "WorldGraphicsComponent"
  g.canvas = createSimpleCanvas("shaders/simple")
  g.canvas.drawOrder = 10

  display[WindowingSystem].desktop.showing = bindable(false)

method onEvent*(g: WorldGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   ifOfType(WorldInitializedEvent, event):
     g.needsUpdate = true


proc render(g: WorldGraphicsComponent, view: WorldView, display: DisplayWorld) =
  withView(view):
    let tileLib = library(TileKind)

    var r : Rand = initRand(programStartTime.toTime.toUnix)

    var activeRegion : Entity

    let player = toSeq(view.entitiesWithData(Player))[0]
    for region in view.entitiesWithData(Region):
      if region[Region].entities.contains(player):
        activeRegion = region
        break

    if activeRegion.isSentinel:
      err "Sentinel entity for region in world display?"

    withView(view):
      var qb = QuadBuilder()
      let rlayer = layer(activeRegion, view, MainLayer)
      for x in -RegionHalfSize ..< RegionHalfSize:
        for y in -RegionHalfSize ..< RegionHalfSize:
          let tent = tileEnt(rlayer, x, y)
          let t = tile(rlayer, x, y)

          if t.floorLayers.nonEmpty:
            let tileInfo = tileLib[t.floorLayers[^1].tileKind]
            qb.dimensions = vec2f(24.0f,24.0f)
            qb.position = vec3f(x.float * 24.0f, y.float * 24.0f, 0.0f)
            qb.texture = tileInfo.images[0]
            qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
            qb.drawTo(g.canvas)


method update(g: WorldGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.needsUpdate:
    render(g, world.view, display)
    g.canvas.swap()
    g.needsUpdate = false

  @[g.canvas.drawCommand(display)]





method initialize(g: DynamicEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "DynamicEntityGraphicsComponent"
   g.canvas = createSimpleCanvas("shaders/simple")
   g.canvas.drawOrder = 15
   g.lastDrawn = WorldEventClock(-2)

method onEvent*(g: DynamicEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   ifOfType(WorldInitializedEvent, event):
     g.needsUpdate = true


proc render(g: DynamicEntityGraphicsComponent, view: WorldView, display: DisplayWorld) =
  withView(view):
    let tileLib = library(TileKind)

    var r : Rand = initRand(programStartTime.toTime.toUnix)

    var activeRegion : Entity

    let player = toSeq(view.entitiesWithData(Player))[0]
    for region in view.entitiesWithData(Region):
      if region[Region].entities.contains(player):
        activeRegion = region
        break

    if activeRegion.isSentinel:
      err "Sentinel entity for region in world display?"

    withView(view):
      var qb = QuadBuilder()
      for ent in activeRegion[Region].entities:
        if ent.hasData(Physical):
          let phys = ent.data(Physical)
          qb.dimensions = vec2f(24.0f,24.0f)
          qb.position = vec3f(phys.position.x.float * 24.0f, phys.position.y.float * 24.0f, 0.0f)
          qb.texture = phys.images[0]
          qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
          qb.drawTo(g.canvas)


method update(g: DynamicEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  withWorld(world):
    if g.lastDrawn < world.currentTime:
      render(g, world.view, display)
      g.canvas.swap()
      g.lastDrawn = world.currentTime

      for player in world.view.entitiesWithData(Player):
        let pos = player.data(Physical).position
        display[CameraData].camera.moveTo(vec3f(pos.x.float * 24.0f, pos.y.float * 24.0f, 0.0f))

    @[g.canvas.drawCommand(display)]




method initialize(g: PlayerCameraComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.name = "PlayerCameraComponent"


method onEvent*(g: PlayerCameraComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(KeyRelease, key):
      let delta = case key:
        of KeyCode.W: vec2i(0,1)
        of KeyCode.A: vec2i(-1,0)
        of KeyCode.S: vec2i(0,-1)
        of KeyCode.D: vec2i(1,0)
        else: vec2(0,0)

      if delta.x != 0 or delta.y != 0:
        world.eventStmts(GameEvent()):
          for player in world.view.entitiesWithData(Player):
            player.modify(Physical.position += vec3i(delta.x, delta.y, 0))



method update(g: PlayerCameraComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  withWorld(world):

    @[]