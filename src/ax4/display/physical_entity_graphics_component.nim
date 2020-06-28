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

type
   PhysicalEntityGraphicsComponent* = ref object of GraphicsComponent
      canvas : SimpleCanvas
      worldWatcher : Watcher[WorldEventClock]


method initialize(g : PhysicalEntityGraphicsComponent, world : World, curView : WorldView, display : DisplayWorld) =
   g.name = "PhysicalEntityGraphicsComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.canvas.drawOrder = 10
   g.worldWatcher = watcher(() => curView.currentTime())
   

proc render(g : PhysicalEntityGraphicsComponent, view : WorldView, display : DisplayWorld) =
   withView(view):
      let hexSize = mapGraphicsSettings().hexSize.float

      var qb = QuadBuilder()
      qb.centered()

      for physEnt in view.entitiesWithData(Physical):
         let physical = physEnt[Physical]
         let img = image("ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_38.png")         
         let scale = ((hexSize * 0.65).int div img.dimensions.x).float
         let cart = physical.position.asCartVec * hexSize

         qb.texture = img
         qb.position = cart.Vec3f
         qb.dimensions = img.dimensions.Vec2f * scale
         qb.color = rgba(1.0f,1.0f,1.0f,1.0f)

         qb.drawTo(g.canvas)
      g.canvas.swap()


method update(g : PhysicalEntityGraphicsComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
   if g.worldWatcher.hasChanged:
      g.render(world.view, display)
   @[g.canvas.drawCommand(display)]