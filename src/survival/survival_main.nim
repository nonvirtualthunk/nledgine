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
import survival/game/survival_core
import survival/game/logic
import worlds/taxonomy

type
  InitializationComponent = ref object of LiveGameComponent





method initialize(g: InitializationComponent, world: LiveWorld) =
  world.eventStmts(WorldInitializedEvent()):
    let regionEnt = world.createEntity()
    let region = regionEnt.attachData(Region)
    generateRegion(world, regionEnt)


    let water = taxon("TileKinds", "Seawater")

    var pos = vec3i(0,0,MainLayer)
    for y in countdown(RegionHalfSize-1,0):
      let tile = region.tile(0,y,MainLayer)
      if tile.floorLayers.nonEmpty and tile.floorLayers[^1].tileKind != water:
        pos = vec3i(0.int32,y.int32,MainLayer.int32)
        break

    let axe = createItem(world, regionEnt, † Items.Axe)

    let player = world.createEntity()
    player.attachData(Player(
      quickSlots: [player, axe, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity]
    ))
    player.attachData(Creature(
      stamina: vital(14),
      hydration: vital(22).withLossTime(Ticks(400)),
      hunger: vital(19).withLossTime(Ticks(600)),
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
    player[Inventory].items.incl(axe)

    regionEnt[Region].entities.incl(player)
    regionEnt[Region].dynamicEntities.incl(player)



main(GameSetup(
  windowSize: vec2i(1800, 1200),
  resizeable: false,
  windowTitle: "Survival",
  liveGameComponents: @[
    BasicLiveWorldDebugComponent().ignoringEventType(WorldAdvancedEvent),
    InitializationComponent(),
    CreatureComponent(),
    PhysicalComponent(),
  ],
  graphicsComponents: @[
    createCameraComponent(createPixelCamera(3).withMoveSpeed(0.0f).withEye(vec3f(0.0f,10000.0f,0.0f))),
    createWindowingSystemComponent("survival/widgets/"),
    WorldGraphicsComponent(),
    DynamicEntityGraphicsComponent(),
    PlayerControlComponent(),
  ]
))

