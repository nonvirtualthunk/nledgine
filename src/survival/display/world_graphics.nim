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

type
  WorldGraphicsComponent* = ref object of GraphicsComponent
    canvas: Canvas[SimpleVertex,uint32]
    needsUpdate: bool
    
  DynamicEntityGraphicsComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    needsUpdate: bool
    lastDrawn: WorldEventClock

  PlayerControlComponent* = ref object of GraphicsComponent

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

        for ent in t.entities:
          if ent.hasData(Physical):
            let phys = ent.data(Physical)
            if not phys.dynamic:
              qb.dimensions = vec2f(24.0f,24.0f)
              qb.position = vec3f(phys.position.x.float * 24.0f, phys.position.y.float * 24.0f, 0.0f)
              qb.texture = phys.images[0]
              qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
              qb.drawTo(g.canvas)



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




method initialize(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "PlayerControlComponent"

  let ws = display[WindowingSystem]
  ws.desktop.background.draw = bindable(false)
  var overlay = nineWayImage(imageLike("ui/woodBorder.png"))
  overlay.drawCenter = false
  ws.desktop.overlays = @[overlay]

  ws.desktop.createChild("hud", "VitalsWidget")


method onEvent*(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(KeyPress, key):
      let delta = case key:
        of KeyCode.W: vec2i(0,1)
        of KeyCode.A: vec2i(-1,0)
        of KeyCode.S: vec2i(0,-1)
        of KeyCode.D: vec2i(1,0)
        else: vec2(0,0)

      if delta.x != 0 or delta.y != 0:
        withWorld(world):
          for player in world.entitiesWithData(Player):
            let phys = player[Physical]
            let toPos = phys.position + vec3i(delta.x, delta.y, 0)
            let toTile = tile(phys.region, toPos.x, toPos.y, toPos.z)

            var interactingWithEntity = false
            for ent in toTile.entities:
              ifHasData(ent, Physical, phys):
                if phys.occupiesTile:
                  interactingWithEntity = true
                  info "Destroying entity: "
                  world.printEntityData(ent)
                  if ent.hasData(Gatherable):
                    let gatherable = ent.data(Gatherable)
                    for res in gatherable.resources:
                      for i in 0 ..< res.quantity.currentValue:
                        let item = createItem(world, phys.region, res.resource)
                        moveItemToInventory(world, item, player)

                  destroyEntity(world, ent)
                  break


            if not interactingWithEntity:
              moveEntityDelta(world, player, vec3i(delta.x, delta.y, 0))





method update(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  withWorld(world):
    let ws = display[WindowingSystem]
    for player in world.entitiesWithData(Player):
      let phys = player[Physical]
      let creature = player[Creature]

      ws.desktop.bindValue("player", {
        "health" : phys.health.currentValue,
        "maxHealth" : phys.health.maxValue,
        "stamina" : creature.stamina.currentValue,
        "maxStamina" : creature.stamina.maxValue,
        "hydration" : creature.hydration.currentValue,
        "maxHydration" : creature.hydration.maxValue,
        "hunger" : creature.hunger.currentValue,
        "maxHunger" : creature.hunger.maxValue,
      }.toTable())
    @[]