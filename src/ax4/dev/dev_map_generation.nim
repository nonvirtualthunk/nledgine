import main
import application
import ax4/display/map_graphics_component
import graphics/camera_component
import ax4/display/map_culling_component
import prelude
import graphics/cameras
import ax4/display/data/mapGraphicsData
import ax4/game/randomness
import ax4/game/map_generation
import ax4/game/map
import ax4/game/ax_events
import engines
import ax4/dev/up_to_date_animation_component

type MapInitializationComponent = ref object of GameComponent

method initialize(g: MapInitializationComponent, world: World) =
   world.attachData(RandomizationWorldData())
   withWorld(world):
      let mapEnt = createForestRoom(world)
      world.attachData(Maps(
         activeMap: mapEnt
      ))

      world.addFullEvent(WorldInitializedEvent())



main(GameSetup(
   windowSize: vec2i(1440, 1024),
   resizeable: false,
   windowTitle: "Map Generation Test",
   gameComponents: @[
      (GameComponent)MapInitializationComponent()
   ],
   graphicsComponents: @[
      createCameraComponent(createPixelCamera(mapGraphicsSettings().baseScale)),
      MapGraphicsComponent(ignoreVision: true),
      MapCullingComponent(),
      UpToDateAnimationComponent(),
   ]
   ))

