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
   CardDisplayComponent* = ref object of GraphicsComponent

method initialize(g : CardDisplayComponent, world : World, curView : WorldView, display : DisplayWorld) =
   g.name = "CardDisplayComponent"

method onEvent(g : CardDisplayComponent, world : World, curView : WorldView, display : DisplayWorld, event : Event) =
   discard

method update(g : CardDisplayComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
   discard