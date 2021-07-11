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
import game/grids
import graphics/canvas
import argentum/game/physics_component
import argentum/game/machine_component

type
   PrintComponent = ref object of GameComponent
      updateCount: int
      lastPrint: UnitOfTime
      mostRecentEventStr: string

   InitializationComponent = ref object of GameComponent





method initialize(g: InitializationComponent, world: World) =
   discard

method initialize(g: PrintComponent, world: World) =
   echo "Initialized"

method update(g: PrintComponent, world: World) =
   g.updateCount.inc
   let curTime = relTime()
   if curTime - g.lastPrint > seconds(2.0f):
      g.lastPrint = curTime
      let updatesPerSecond = (g.updateCount / 2)
      if updatesPerSecond < 59:
         info &"Updates / second (sub 60) : {updatesPerSecond}"
      else:
         fine &"Updates / second : {updatesPerSecond}"
      g.updateCount = 0

method onEvent(g: PrintComponent, world: World, event: Event) =
   discard


main(GameSetup(
   windowSize: vec2i(1440, 900),
   resizeable: false,
   windowTitle: "Argentum",
   gameComponents: @[
      (GameComponent)(PrintComponent()),
   ],
   graphicsComponents: @[
      createCameraComponent(createPixelCamera(1)),
      createWindowingSystemComponent("ax4/widgets/"),
      PhysicsComponent(),
      MachineComponent()
   ]
))

