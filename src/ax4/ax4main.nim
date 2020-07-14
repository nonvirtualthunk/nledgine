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
import windowingsystem/windowingsystem_component
import ax4/game/cards
import game/library
import ax4/display/card_ui_component
import ax4/game/ax_events
import ax4/display/effect_selection_component
import ax4/game/resource_pools
import core

type
   PrintComponent = ref object of GameComponent
      updateCount: int
      lastPrint: UnitOfTime

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

method initialize(g: MapInitializationComponent, world: World) =
   let grass = taxon("vegetations", "grass")
   let forest = taxon("vegetations", "forest")

   let hills = taxon("terrains", "hills")
   let mountains = taxon("terrains", "mountains")
   let flatland = taxon("terrains", "flatland")

   let noise = newNoise()

   withWorld(world):
      var map = createMap(vec2i(50, 50))
      for r in 0 ..< 15:
         for hex in hexRing(axialVec(0, 0), r):
            let tile = world.createEntity()

            let terrainKind =
               if r <= 1: mountains
               elif r <= 4: hills
               else: flatland

            var vegetation: seq[Taxon]

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
               position: hex,
               terrain: terrainKind,
               vegetation: vegetation
            ))
            map.setTileAt(hex, tile)
      world.attachData(map)

      let tobold = world.createEntity()
      tobold.attachData(Physical())

      let arch = library(CardArchetype)[taxon("card types", "move")]
      let card1 = arch.createCard(world)
      let card2 = arch.createCard(world)
      let deck = DeckOwner(
         combatDeck: Deck(cards: {CardLocation.Hand: @[card1, card2]}.toTable)
      )

      tobold.attachData(deck)

      tobold.attachData(ResourcePools(resources: {taxon("resource pools", "action points"): reduceable(3), taxon("resource pools", "stamina points"): reduceable(8)}.toTable))

      world.addEvent(WorldInitializedEvent())

      echo "Tobold: ", tobold


method update(g: MapInitializationComponent, world: World) = discard

main(GameSetup(
   windowSize: vec2i(1440, 900),
   resizeable: false,
   windowTitle: "Ax4",
   gameComponents: @[(GameComponent)(PrintComponent()), MapInitializationComponent()],
   graphicsComponents: @[
      createCameraComponent(createPixelCamera(mapGraphicsSettings().baseScale)),
      MapGraphicsComponent(),
      MapCullingComponent(),
      PhysicalEntityGraphicsComponent(),
      TacticalUIComponent(),
      CardUIComponent(),
      MapEventTransformer(),
      EffectSelectionComponent(),
      createWindowingSystemComponent()
   ]
))

