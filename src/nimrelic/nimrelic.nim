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
import nimrelic/query_workbook
import nimrelic/async_component
import nimrelic/chart_widget


main(GameSetup(
   windowSize: vec2i(1440, 900),
   resizeable: false,
   windowTitle: "NimRelic",
   gameComponents: @[],
   graphicsComponents: @[
      createCameraComponent(createPixelCamera(1)),
      createWindowingSystemComponent("nimrelic/widgets/", @[(WindowingComponent) ChartDisplayRenderer()]),
      QueryWorkbookComponent(),
      AsyncComponent()
   ]
))

