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
import ax4/game/map
import hex
import perlin
import windowingsystem/windowingsystem_component
import game/library
import core
import game/library
import worlds/gamedebug
import strutils
import graphics/cameras

type
   PrintComponent = ref object of GameComponent
      updateCount: int
      lastPrint: UnitOfTime
      mostRecentEventStr: string

   MapInitializationComponent = ref object of GameComponent


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
   windowTitle: "Ax4",
   gameComponents: @[
      (GameComponent)(PrintComponent()),
   ],
   graphicsComponents: @[
      createCameraComponent(createPixelCamera(1)),
      createWindowingSystemComponent()
   ]
))

