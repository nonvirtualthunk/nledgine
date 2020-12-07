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
import game/library
import ax4/game/enemies
import ax4/game/items
import ax4/game/randomness
import ax4/game/flags
import ax4/game/turns
import ax4/game/components/flag_component
import ax4/game/components/ai_component
import ax4/display/animation_component
import ax4/game/components/conditions_component
import ax4/game/vision
import worlds/gamedebug
import ax4/game/ax_events
import strutils
import ax4/game/game_logic
import ax4/display/reward_ui_component

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
   ifOfType(AxEvent, event):
      let eventStr = toString(event, world)
      if event.state == GameEventState.PreEvent:
         info("> " & eventStr)
         indentLogs()
      else:
         unindentLogs()

         let adjustedPrev = g.mostRecentEventStr.replace("PreEvent", "")
         let adjustedNew = eventStr.replace("PostEvent", "")

         if adjustedPrev != adjustedNew:
            info("< " & eventStr)

      g.mostRecentEventStr = eventStr

method initialize(g: MapInitializationComponent, world: World) =
   let grass = taxon("vegetations", "grass")
   let forest = taxon("vegetations", "forest")

   let hills = taxon("terrains", "hills")
   let mountains = taxon("terrains", "mountains")
   let flatland = taxon("terrains", "flatland")

   let noise = newNoise()

   world.attachData(RandomizationWorldData())
   withWorld(world):
      var map = createMap(vec2i(50, 50))
      for r in 0 ..< 15:
         for hex in hexRing(axialVec(0, 0), r):
            let tile = world.createEntity()

            let terrainKind =
               if r <= 7: flatland
               elif r <= 10: hills
               else: mountains

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


      let playerFaction = world.createEntity()
      playerFaction.attachData(Faction(color: rgba(0.7f, 0.15f, 0.2f, 1.0f), playerControlled: true))
      playerFaction.attachData(Vision())
      playerFaction.attachData(DebugData(name: "Player Faction"))

      let enemyFaction = world.createEntity()
      enemyFaction.attachData(Faction(color: rgba(0.2f, 0.1f, 0.8f, 1.0f), playerControlled: false))
      enemyFaction.attachData(Vision())
      enemyFaction.attachData(DebugData(name: "Enemy Faction"))

      let tobold = world.createEntity()
      tobold.attachData(Physical())
      tobold.attachData(Allegiance(faction: playerFaction))

      let arch = library(CardArchetype)[taxon("card types", "move")]
      let card1 = arch.createCard(world)
      let card2 = arch.createCard(world)
      let piercingStab = library(CardArchetype)[taxon("card types", "piercing stab")].createCard(world)
      let fightAnotherDay = library(CardArchetype)[taxon("card types", "fight another day")].createCard(world)
      let vengeance = library(CardArchetype)[taxon("card types", "vengeance")].createCard(world)
      let deck = DeckOwner(
         combatDeck: Deck(cards: {CardLocation.Hand: @[card1, card2, piercingStab, fightAnotherDay, vengeance]}.toTable)
      )

      tobold.attachData(deck)
      tobold.attachData(ResourcePools(resources: {taxon("resource pools", "action points"): reduceable(3), taxon("resource pools", "stamina points"): reduceable(7)}.toTable))
      tobold.attachData(Character(
         health: reduceable(24),
         # pendingRewards: @[CharacterRewardChoice(options: @[
         #    CardReward(taxon("card types", "piercing stab")),
         #    CardReward(taxon("card types", "vengeance")),
         #    CardReward(taxon("card types", "fight another day")),
         #    CardReward(taxon("card types", "double strike"))
         # ])],
      ))
      tobold.attachData(Inventory())
      tobold.attachData(Flags(flags: {taxon("flags", "Weak"): 1}.toTable))
      tobold.attachData(Vision())
      tobold.attachData(DebugData(name: "Tobold"))

      let spear = createItem(world, taxon("items", "longspear"))
      equipItem(world, tobold, spear)
      world.addFullEvent(EntityEnteredWorldEvent(entity: tobold))



      let slime = createMonster(world, enemyFaction, taxon("monster classes", "green slime"))
      slime.modify(Monster.xp += 40)
      placeCharacterInWorld(world, slime, axialVec(1, 2, 0))

      let purpleSlime = createMonster(world, enemyFaction, taxon("monster classes", "purple slime"))
      placeCharacterInWorld(world, purpleSlime, axialVec(2, 1, 0))

      world.attachData(TurnData(activeFaction: playerFaction, turnNumber: 1))

      world.addFullEvent(WorldInitializedEvent())



main(GameSetup(
   windowSize: vec2i(1440, 1024),
   resizeable: false,
   windowTitle: "Ax4",
   gameComponents: @[
      (GameComponent)(PrintComponent()),
      MapInitializationComponent(),
      FlagComponent(),
      AIComponent(),
      VisionComponent(),
      ConditionsComponent(),
   ],
   graphicsComponents: @[
      createCameraComponent(createPixelCamera(mapGraphicsSettings().baseScale)),
      MapGraphicsComponent(),
      MapCullingComponent(),
      PhysicalEntityGraphicsComponent(),
      TacticalUIComponent(),
      CardUIComponent(),
      MapEventTransformer(),
      EffectSelectionComponent(),
      AnimationComponent(),
      RewardUIComponent(),
      createWindowingSystemComponent(),
   ]
))

