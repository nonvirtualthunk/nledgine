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
import argentum/game/physics_component
import argentum/game/machine_component

type
   InitializationComponent = ref object of GameComponent





method initialize(g: InitializationComponent, world: World) =
   discard

main(GameSetup(
   windowSize: vec2i(1440, 900),
   resizeable: false,
   windowTitle: "Survival",
   gameComponents: @[
      BasicDebugComponent(),
      InitializationComponent()
   ],
   graphicsComponents: @[
      createCameraComponent(createPixelCamera(1)),
      createWindowingSystemComponent("survival/widgets/"),
   ]
))

