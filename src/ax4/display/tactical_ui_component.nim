import engines
import graphics
import prelude
import tables
import ax4/game/map
import hex
import graphics/cameras
import graphics/camera_component
import ax4/game/characters
import ax4/display/data/mapGraphicsData
import graphics/canvas
import strformat
import ax4/display/ax_display_events
import util
import options
import ax4/game/ax_events
import ax4/game/pathfinder
import windowingsystem/windowingsystem

type
   TacticalUIComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas
      tentativePath: Watchable[Option[Path]]
      worldWatcher: Watcher[WorldEventClock]

   TacticalUIData* = object
      selectedCharacter*: Option[Entity]

defineReflection(TacticalUIData)

template withSelectedCharacter*(display: DisplayWorld, stmts: untyped) =
   let tuid = display[TacticalUIData]
   if tuid.selectedCharacter.isSome:
      let selC {.inject.} = tuid.selectedCharacter.get
      stmts

method initialize(g: TacticalUIComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "TacticalUIComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.worldWatcher = watcher(() => curView.currentTime())
   g.eventPriority = 10
   g.canvas.drawOrder = 5
   display.attachData(TacticalUIData())

   let ws = display[WindowingSystem]
   ws.desktop.background.drawCenter = false


proc render(g: TacticalUIComponent, view: WorldView, display: DisplayWorld) =
   discard


method onEvent(g: TacticalUIComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   let tuid = display[TacticalUIData]
   let selc = tuid.selectedCharacter

   withWorld(world):
      matchType(event):
         extract(HexMouseRelease, hex, button, position):
            if tuid.selectedCharacter.isSome:
               discard
            else:
               for entity in world.entitiesWithData(Physical):
                  if entity[Physical].position == hex:
                     if tuid.selectedCharacter != some(entity):
                        tuid.selectedCharacter = some(entity)
                        display.addEvent(CharacterSelect(character: entity))
         extract(CharacterSelect, character):
            g.tentativePath.setTo(none(Path))

method update(g: TacticalUIComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   if g.worldWatcher.hasChanged:
      g.render(world.view, display)
   # @[g.canvas.drawCommand(display)]
   @[]
