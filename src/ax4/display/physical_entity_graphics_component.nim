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
import core
import ax4/game/resource_pools

type
   PhysicalEntityGraphicsComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas
      worldWatcher: Watcher[WorldEventClock]


method initialize(g: PhysicalEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "PhysicalEntityGraphicsComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.canvas.drawOrder = 10
   g.worldWatcher = watcher(() => curView.currentTime())


proc render(g: PhysicalEntityGraphicsComponent, view: WorldView, display: DisplayWorld) =
   let vertFrame = image("ax4/images/ui/vertical_bar_frame.png")
   let vertContent = image("ax4/images/ui/vertical_bar_content.png")
   let stamFrame = image("ax4/images/ui/stamina_frame.png")
   let stamContent = image("ax4/images/ui/stamina_content.png")

   let stamina = taxon("resource pools", "stamina points")

   withView(view):
      let hexSize = mapGraphicsSettings().hexSize.float
      let hexHeight = hexSize.hexHeight

      var qb = QuadBuilder()
      qb.origin = vec2f(0.5f, 0.0f)

      var uiqb = QuadBuilder()

      for physEnt in view.entitiesWithData(Physical):
         let physical = physEnt[Physical]
         let img = image("ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_38.png")
         let scale = ((hexSize * 0.65).int div img.dimensions.x).float
         let cart = physical.position.asCartVec * hexSize

         let entBasePos = cart.Vec3f - vec3f(0.0f, hexHeight * 0.4f, 0.0f)

         qb.texture = img
         qb.position = entBasePos
         qb.dimensions = img.dimensions.Vec2f * scale
         qb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
         qb.drawTo(g.canvas)

         if physEnt.hasData(Character):
            let barScale = ((hexHeight * 0.7).int div vertFrame.dimensions.y)
            let barHeight = vertFrame.dimensions.y * barScale

            let cd = physEnt.data(Character)
            let maxHP = cd.health.maxValue
            let curHP = cd.health.currentValue
            let pcntHP = curHP.float / maxHP.max(1).float

            let healthBarPos = entBasePos + vec3f(((img.dimensions.x div 2).float * scale + 0.0f), 0.0f, 0.0f)
            let healthBarDim = vertFrame.dimensions.Vec2f * barScale.float
            uiqb.texture = vertFrame
            uiqb.position = healthBarPos
            uiqb.dimensions = healthBarDim
            uiqb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
            uiqb.drawTo(g.canvas)

            let maxContentHeight = barHeight - barScale * 2
            uiqb.position += vec3f(barScale.float, barScale.float, 0.0f)
            uiqb.texture = vertContent
            uiqb.color = rgba(0.8f, 0.1f, 0.1f, 1.0f)
            uiqb.dimensions = vec2f(vertContent.dimensions.x.float * barScale.float, maxContentHeight.float * pcntHP)
            uiqb.drawTo(g.canvas)

            if physEnt.hasData(ResourcePools):
               let rsrc = physEnt[ResourcePools]
               let currentStamina = rsrc.currentResourceValue(stamina)
               let maxStamina = rsrc.maximumResourceValue(stamina)

               let staminaBarPos = healthBarPos + vec3f(healthBarDim.x - barScale.float, 0.0f, 0.0f)
               uiqb.position = staminaBarPos
               uiqb.dimensions = stamFrame.dimensions.Vec2f * barScale.float
               for i in 0 ..< maxStamina:
                  uiqb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
                  uiqb.texture = stamFrame
                  uiqb.drawTo(g.canvas)
                  if i < currentStamina:
                     uiqb.color = rgba(0.1f, 0.7f, 0.2f, 1.0f)
                     uiqb.texture = stamContent
                     uiqb.drawTo(g.canvas)
                  uiqb.position.y += uiqb.dimensions.y - barScale.float

      g.canvas.swap()


method update(g: PhysicalEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   if g.worldWatcher.hasChanged:
      g.render(world.view, display)
   @[g.canvas.drawCommand(display)]
