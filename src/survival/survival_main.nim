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

type
  InitializationComponent = ref object of LiveGameComponent





method initialize(g: InitializationComponent, world: LiveWorld) =
  world.eventStmts(WorldInitializedEvent()):
    let regionEnt = world.createEntity()
    let player = world.createEntity()
    player.attachData(Player())
    player.attachData(Creature())
    player.attachData(Physical(
      position : vec3i(0,0,MainLayer),
      images: @[imageLike("survival/graphics/creatures/player.png")],
      dynamic: true
    ))

    let region = regionEnt.attachData(Region)
    generateRegion(world, regionEnt)

    regionEnt[Region].entities.incl(player)
    regionEnt[Region].dynamicEntities.incl(player)



main(GameSetup(
  windowSize: vec2i(1440, 900),
  resizeable: false,
  windowTitle: "Survival",
  liveGameComponents: @[
    BasicLiveWorldDebugComponent(),
    InitializationComponent()
  ],
  graphicsComponents: @[
    createCameraComponent(createPixelCamera(2).withMoveSpeed(0.0f)),
    createWindowingSystemComponent("survival/widgets/"),
    WorldGraphicsComponent(),
    DynamicEntityGraphicsComponent(),
    PlayerControlComponent(),
  ]
))

