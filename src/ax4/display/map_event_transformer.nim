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

type
   MapEventTransformer* = ref object of GraphicsComponent
     lastMousedHex : AxialVec


method initialize(g : MapEventTransformer, world : World, curView : WorldView, display : DisplayWorld) =
   g.name = "MapEventTransformer"
   g.eventPriority = -100

method onEvent(g : MapEventTransformer, world : World, curView : WorldView, display : DisplayWorld, event : Event) =
   matchType(event):
      extract(MouseRelease, button, position):
         display.addEvent(HexMouseRelease(hex: pixelToHex(display, position), position : position, button : button))
      extract(MousePress, button, position):
         display.addEvent(HexMousePress(hex: pixelToHex(display, position), position : position, button : button))
      extract(MouseMove, position):
         let hex = pixelToHex(display, position)
         if hex != g.lastMousedHex:
            display.addEvent(HexMouseExit(hex: g.lastMousedHex))
            g.lastMousedHex = hex
            display.addEvent(HexMouseEnter(hex: hex))

# method update(g : TacticalUIComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
#    if g.worldWatcher.hasChanged:
#      g.render(world.view, display)
#    @[g.canvas.drawCommand(display)]