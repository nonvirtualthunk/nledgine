import options

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
import ax4/game/rooms

type
   PrintComponent = ref object of GameComponent
      updateCount: int
      lastPrint: UnitOfTime
      mostRecentEventStr: string

   MapInitializationComponent = ref object of GameComponent

   RoomTransitionGraphicsComponent = ref object of GraphicsComponent



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
   world.attachData(RandomizationWorldData())
   withWorld(world):

      world.attachData(Maps())

      let playerFaction = world.createEntity()
      playerFaction.attachData(Faction(color: rgba(0.7f, 0.15f, 0.2f, 1.0f), playerControlled: true))
      playerFaction.attachData(Vision())
      playerFaction.attachData(DebugData(name: "Player Faction"))

      let enemyFaction = world.createEntity()
      enemyFaction.attachData(Faction(color: rgba(0.2f, 0.1f, 0.8f, 1.0f), playerControlled: false))
      enemyFaction.attachData(Vision())
      enemyFaction.attachData(DebugData(name: "Enemy Faction"))

      let tobold = createCharacter(world, taxon("character classes", "fighter"), playerFaction)
      tobold.attachData(DebugData(name: "tobold"))
      let beorn = createCharacter(world, taxon("character classes", "fighter"), playerFaction)
      beorn.attachData(DebugData(name: "beorn"))

      enterNextRoom(world)

      world.attachData(TurnData(activeFaction: playerFaction, turnNumber: 1))

      world.addFullEvent(WorldInitializedEvent())




method initialize(g: RoomTransitionGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "RoomTransitionGraphicsComponent"

method onEvent*(g: RoomTransitionGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   withWorld(world):
      matcher(event):
         extract(RoomEnteredEvent):
            for faction in playerFactions(world):
               for entity in entitiesInFaction(world, faction):
                  if entity.hasData(Physical):
                     display[CameraData].camera.moveTo((entity[Physical].position.asCartVec * mapGraphicsSettings().hexSize.float).Vec3f)




main(GameSetup(
   windowSize: vec2i(1680, 1200),
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
      createCameraComponent(createPixelCamera(mapGraphicsSettings().baseScale).withMoveSpeed(300.0f)),
      MapGraphicsComponent(),
      MapCullingComponent(),
      PhysicalEntityGraphicsComponent(),
      TacticalUIComponent(),
      CardUIComponent(),
      MapEventTransformer(),
      EffectSelectionComponent(),
      AnimationComponent(),
      RewardUIComponent(),
      createWindowingSystemComponent("ax4/widgets/"),
      RoomTransitionGraphicsComponent(),
   ]
))

