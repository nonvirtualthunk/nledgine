import engines
import ax4/game/components/flag_component
import ax4/game/components/ai_component
import ax4/game/vision
import ax4/game/components/conditions_component
import ax4/game/randomness
import ax4/game/character_types
import ax4/game/ax_events
import graphics/color
import worlds
import ax4/game/turns
import ax4/game/map
import hex
import prelude
import noto
import strutils


type
   WorldInfo* = object
      playerFaction*: Entity
      enemyFaction*: Entity

type
   EventPrintComponent = ref object of GameComponent
      mostRecentEventStr: string


method initialize(g: EventPrintComponent, world: World) =
   g.name = "EventPrintComponent"

method onEvent(g: EventPrintComponent, world: World, event: Event) =
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



proc testEngine*(): (GameEngine, World, WorldInfo) =
   let gameEngine = newGameEngine()
   gameEngine.addComponent(FlagComponent())
   gameEngine.addComponent(AIComponent())
   gameEngine.addComponent(VisionComponent())
   gameEngine.addComponent(ConditionsComponent())
   gameEngine.addComponent(EventPrintComponent())

   withWorld(gameEngine.world):
      let playerFaction = gameEngine.world.createEntity()
      playerFaction.attachData(Faction(color: rgba(0.7f, 0.15f, 0.2f, 1.0f), playerControlled: true))
      playerFaction.attachData(Vision())
      playerFaction.attachData(DebugData(name: "Player Faction"))

      let enemyFaction = gameEngine.world.createEntity()
      enemyFaction.attachData(Faction(color: rgba(0.2f, 0.1f, 0.8f, 1.0f), playerControlled: false))
      enemyFaction.attachData(Vision())
      enemyFaction.attachData(DebugData(name: "Enemy Faction"))

      gameEngine.world.attachData(RandomizationWorldData(style: RandomizationStyle.Median))
      gameEngine.world.attachData(TurnData(turnNumber: 0, activeFaction: enemyFaction))

      gameEngine.world.addFullEvent(WorldInitializedEvent())

      (gameEngine, gameEngine.world, WorldInfo(
         playerFaction: playerFaction,
         enemyFaction: enemyFaction,
      ))

# Creates a map of radius 15 filled with grass tiles
proc createBasicMap*(world: World) =
   withWorld(world):
      let grass = taxon("vegetations", "grass")
      let flatland = taxon("terrains", "flatland")

      var map = createMap(vec2i(50, 50))
      for r in 0 ..< 15:
         for hex in hexRing(axialVec(0, 0), r):
            let tile = world.createEntity()
            let vegetation = @[grass]
            let terrain = flatland

            tile.attachData(Tile(
               position: hex,
               terrain: terrain,
               vegetation: vegetation
            ))
            map.setTileAt(hex, tile)

      world.attachData(map)
