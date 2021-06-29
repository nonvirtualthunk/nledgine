import main
import application
import glm
import engines
import worlds
import prelude
import tables
import noto
import graphics/camera_component
import resources
import graphics/texture_block
import graphics/images
import windowingsystem/windowingsystem_component
import windowingsystem/windowing_system_core
import game/library
import core
import worlds/gamedebug
import strutils
import graphics/cameras
import graphics/image_extras
import game/grids
import graphics/canvas
import engines/debug_components
import survival/game/regions
import graphics/up_to_date_animation_component
import survival/game/entities
import survival/game/events
import survival/game/tiles
import reflect
import sets
import survival/display/world_graphics
import survival/display/player_control
import survival/game/living_components
import survival/game/vision
import survival/game/survival_core
import survival/game/logic
import game/shadowcasting
import worlds/taxonomy
import graphics/color

type
  InitializationComponent = ref object of LiveGameComponent

  InitializationGraphicsComponent = ref object of GraphicsComponent


proc initializationComponent() : InitializationComponent =
  result = new InitializationComponent
  result.initializePriority = 10000

method initialize(g: InitializationComponent, world: LiveWorld) =
  g.name = "InitializationComponent"
  world.eventStmts(WorldInitializedEvent(time: relTime().inSeconds)):
    let regionEnt = world.createEntity()
    let region = regionEnt.attachData(Region)
    generateRegion(world, regionEnt)


    let water = taxon("TileKinds", "Seawater")

    var pos = vec3i(0,0,MainLayer)
    for y in countdown(RegionHalfSize-1,0):
      let tile = region.tile(0,y,MainLayer)
      if tile.floorLayers.len > 0 and tile.floorLayers[^1].tileKind != water:
        pos = vec3i(0.int32,y.int32,MainLayer.int32)
        break

    let axe = createItem(world, regionEnt, † Items.Axe)

    let player = world.createEntity()
    player.attachData(Player(
      quickSlots: [player, axe, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity],
      visionRange: 18,
      vision: new ShadowGrid[64]
    ))
    player.attachData(Creature(
      stamina: vital(14),
      hydration: vital(22).withLossTime(Ticks(400)),
      hunger: vital(19).withLossTime(Ticks(600)),
      sanity: vital(25),
      baseMoveTime: Ticks(20),
      equipment: { † BodyParts.RightHand : axe }.toTable
    ))
    player.attachData(Physical(
      position : pos,
      images: @[imageLike("survival/graphics/creatures/player.png")],
      dynamic: true,
      health: vital(24),
      region: regionEnt,
    ))
    player.attachData(Inventory(maximumWeight: 500))
    moveItemToInventory(world, axe, player)
    moveItemToInventory(world, createItem(world, regionEnt, † Items.Log), player)
    moveItemToInventory(world, createItem(world, regionEnt, † Items.CarrotRoot), player)

    regionEnt[Region].entities.incl(player)
    regionEnt[Region].dynamicEntities.incl(player)

    world.addFullEvent(RegionInitializedEvent(region: regionEnt))



proc initializationGraphicsComponent() : InitializationGraphicsComponent =
  result = new InitializationGraphicsComponent
  result.initializePriority = 10000

method initialize(g: InitializationGraphicsComponent, display: DisplayWorld) =
  let cam = createPixelCamera(3).withMoveSpeed(0.0f).withEye(vec3f(0.0f,10000.0f,0.0f))
  display.attachData(CameraData(camera: cam))



main(GameSetup(
  windowSize: vec2i(1800, 1200),
  resizeable: false,
  windowTitle: "Survival",
  clearColor: rgba(0.15,0.15,0.15,1.0),
  liveGameComponents: @[
    BasicLiveWorldDebugComponent().ignoringEventType(WorldAdvancedEvent),
    initializationComponent(),
    CreatureComponent(),
    PhysicalComponent(),
    VisionComponent()
  ],
  graphicsComponents: @[
    createWindowingSystemComponent("survival/widgets/"),
    WorldGraphicsComponent(),
    DynamicEntityGraphicsComponent(),
    PlayerControlComponent(),
    initializationGraphicsComponent()
  ]
))

