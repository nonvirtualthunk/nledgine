import ../main
import ../application
import glm
import ../engines
import ../worlds
import ../prelude
import ../graphics
import tables
import ../noto
import ../graphics/camera_component
import ../resources
import ../graphics/texture_block
import ../graphics/images
import ax4/game/map
import ax4/display/data/mapGraphicsData
import hex
import ax4/display/map_graphics_component
import perlin
import ax4/display/map_culling_component
import ax4/display/physical_entity_graphics_component
import ax4/game/characters
import ax4/display/tactical_ui_component
import ax4/display/map_event_transformer

type 
   PrintComponent = ref object of GameComponent
      updateCount : int
      lastPrint : UnitOfTime

   MapInitializationComponent = ref object of GameComponent


method initialize(g : PrintComponent, world : World) =
   echo "Initialized"

method update(g : PrintComponent, world : World) =
   g.updateCount.inc
   let curTime = relTime()
   if curTime - g.lastPrint > seconds(2.0f):
      g.lastPrint = curTime
      let updatesPerSecond = (g.updateCount / 2)
      if updatesPerSecond < 59:
         info "Updates / second (sub 60) : ", updatesPerSecond
      else:
         fine "Updates / second : ", updatesPerSecond
      g.updateCount = 0

method initialize(g : MapInitializationComponent, world : World) = 
   let grass = taxon("vegetations", "grass")
   let forest = taxon("vegetations", "forest")
   
   let hills = taxon("terrains", "hills")
   let mountains = taxon("terrains", "mountains")
   let flatland = taxon("terrains", "flatland")

   let noise = newNoise()

   withWorld(world):
      var map = createMap(vec2i(50,50))
      for r in 0 ..< 15:
         for hex in hexRing(axialVec(0,0), r):
            let tile = world.createEntity()

            let terrainKind = 
               if r <= 1: mountains
               elif r <= 4: hills
               else: flatland

            var vegetation : seq[Taxon]

            let n = noise.pureSimplex(hex.asCartesian.x.float * 0.3, hex.asCartesian.y.float * 0.3)
            var terrainForestThreshold = 
               if terrainKind == mountains: 0.7f
               elif terrainKind == hills: 0.6f
               else: 0.5f

            let grassy = hex.q > hex.r and r > 1
            if grassy:
               vegetation.add(grass)
            else:
               terrainForestThreshold += 0.175
            
            if n > terrainForestThreshold:
               vegetation.add(forest)

            tile.attachData(Tile(
               position : hex,
               terrain : terrainKind,
               vegetation : vegetation
            ))
            map.setTileAt(hex, tile)
      world.attachData(map)

      let tobold = world.createEntity()
      tobold.attachData(Physical())
      

method update(g : MapInitializationComponent, world : World) = discard

main(GameSetup(
   windowSize : vec2i(1440,900),
   resizeable : false,
   windowTitle : "Ax4",
   gameComponents : @[(GameComponent)(new PrintComponent), new MapInitializationComponent],
   graphicsComponents : @[
      createCameraComponent(createPixelCamera(mapGraphicsSettings().baseScale)),
      MapGraphicsComponent(),
      MapCullingComponent(),
      PhysicalEntityGraphicsComponent(),
      TacticalUIComponent(),
      MapEventTransformer()
   ]
))

