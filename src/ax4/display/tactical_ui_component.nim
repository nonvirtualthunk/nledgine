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

type
   TacticalUIComponent* = ref object of GraphicsComponent
     canvas : SimpleCanvas
     tentativePath : Watchable[Option[Path]]
     worldWatcher : Watcher[WorldEventClock]

   TacticalUIData* = object
      selectedCharacter : Option[Entity]

defineReflection(TacticalUIData)

method initialize(g : TacticalUIComponent, world : World, curView : WorldView, display : DisplayWorld) =
   g.name = "TacticalUIComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.worldWatcher = watcher(() => curView.currentTime())
   g.eventPriority = 10
   g.canvas.drawOrder = 5
   display.attachData(TacticalUIData())
   

proc render(g : TacticalUIComponent, view : WorldView, display : DisplayWorld) =
   withView(view):
      var qb = QuadBuilder()
      qb.centered()
      let img = image("ax4/images/ui/hex_selection.png")
      qb.texture = img
      qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
      let hexSize = mapGraphicsSettings().hexSize.float
      
      if g.tentativePath.isSome:
         for hex in g.tentativePath.get.hexes:
            qb.position = hex.asCartVec.Vec3f * hexSize
            qb.dimensions = vec2f(hexSize, hexSize)

            qb.drawTo(g.canvas)

      g.canvas.swap()


method onEvent(g : TacticalUIComponent, world : World, curView : WorldView, display : DisplayWorld, event : Event) =
   let tuid = display[TacticalUIData]
   let selc = tuid.selectedCharacter

   withWorld(world):
      matchType(event):
         extract(HexMouseRelease, hex, button, position):
            if tuid.selectedCharacter.isSome:
               let selc = tuid.selectedCharacter.get
               let oldPos = selc[Physical].position
               world.eventStmts(CharacterMoveEvent(fromHex: oldPos, toHex: hex)):
                  selC.modify(Physical.position := hex)
            else:
               for entity in world.entitiesWithData(Physical):
                  if entity[Physical].position == hex:
                     if tuid.selectedCharacter != some(entity):
                        tuid.selectedCharacter = some(entity)
                        display.addEvent(CharacterSelect(character : entity))
         extract(CharacterSelect, character):
            g.tentativePath.set(none(Path))
         extract(HexMouseEnter, hex):
            ifSome(selc):
               let pf = createPathfinder(world)
               g.tentativePath.set(pf.findPath(selc, selc[Physical].position, hex))

method update(g : TacticalUIComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
   if g.worldWatcher.hasChanged or g.tentativePath.hasChanged:
     g.render(world.view, display)
   @[g.canvas.drawCommand(display)]