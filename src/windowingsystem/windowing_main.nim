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
import windowingsystem
import windowingsystem/text_widget
import config
import options

type 
   PrintComponent = ref object of GameComponent
      updateCount : int
      lastPrint : UnitOfTime

   DrawQuadComponent = ref object of GraphicsComponent
      vao : VAO[WVertex, uint32]
      texture : TextureBlock
      shader : Shader
      needsUpdate: bool
      camera : Camera
      initTime : UnitOfTime


      

method initialize(g : PrintComponent, world : World) =
   echo "Initialized"

method update(g : PrintComponent, world : World) =
   g.updateCount.inc
   let curTime = relTime()
   if curTime - g.lastPrint > seconds(2.0f):
      g.lastPrint = curTime
      let updatesPerSecond = (g.updateCount / 2)
      if updatesPerSecond < 59:
         info "Updates / second (sub 60) : ", updatesPerSecond
      else:
         fine "Updates / second : ", updatesPerSecond
      g.updateCount = 0


proc render(g : DrawQuadComponent, display: DisplayWorld) =

   # let swordTexCoords = g.texture[g.swordImg]
   # for i in 0..<4:
   #    g.vao.vertices[vi+i].vertex = UnitSquareVertices[i] * g.size + vec3f(g.size + 10, 0.0f, 0.0f)
   #    g.vao.vertices[vi+i].color = rgba(1.0f,1.0f,1.0f,1.0f)
   #    g.vao.vertices[vi+i].texCoords = swordTexCoords[i]
   # g.vao.addIQuad(ii, vi)

   display[WindowingSystem].render(g.vao, g.texture)

   # var vi = g.vao.vi
   # var ii = g.vao.ii

   # let img = image("images/book_01b.png")
   # let bookTexCoords = g.texture[img]
   # for i in 0..<4:
   #    g.vao.vertices[i].vertex = UnitSquareVertices[i] * 100.0f
   #    g.vao.vertices[i].color = rgba(1.0f,1.0f,1.0f,1.0f)
   #    g.vao.vertices[i].texCoords = bookTexCoords[i]
   # g.vao.addIQuad(ii, vi)


   # echo $g.vao.vertices
   # echo $g.vao.indices

   # g.vao.swap()
   g.needsUpdate = false

method initialize(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld) =
   g.initTime = relTime()
   g.vao = newVAO[WVertex, uint32]()
   g.shader = initShader("shaders/windowing")
   g.texture = newTextureBlock(1024, 1, false)
   let windowingSystem = createWindowingSystem(display)
   windowingSystem.pixelScale = 2

   display.attachDataRef(windowingSystem)
   g.camera = createWindowingCamera(2)
   g.needsUpdate = true

   windowingSystem.desktop.background = nineWayImage("ui/woodBorder.png")
   windowingSystem.desktop.background.pixelScale = 1

   let widget = windowingSystem.createWidget("ax4/widgets/card_widgets.sml", "CardWidget")
   #  let widget = windowingSystem.createWidget("demo/widgets/main_widgets.sml", "widget")
   #  let child = widget.childByIdentifier("child").get
   #  let rightChild = widget.childByIdentifier("rightChild").get
   #  let textChild = widget.childByIdentifier("textChild").get
   #  let textChild2 = widget.childByIdentifier("textChild2").get

   #  widget.bindValue("text1", "")

   #  let quote = richText("There are not many persons who know what wonders are opened to them in the stories and visions of their youth; for when as children we listen and dream, we think but half-formed thoughts, and when as men we try to remember, we are dulled and prosaic with the poison of life.")
   #  textChild2.bindValue("text2", quote)

   widget.bindValue("card.name", richText("Test Card"))
   widget.bindValue("card.mainCost", richText("1 AP"))
   widget.bindValue("card.secondaryCost", richText("2 SP"))
   widget.bindValue("card.image", imageLike("ax4/images/card_images/slime.png"))

method onEvent(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld, event : Event) =
   ifOfType(event, KeyPress):
      display[WindowingSystem].desktop.bindValue("text1", $event.key)


method update(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
   # if g.needsUpdate:
   display[WindowingSystem].update(g.texture)
   g.render(display)
   # echo g.vao.vertices

   # info "Seconds till first render: " , (relTime() - g.initTime).as(second)
   
   @[draw(g.vao, g.shader, @[g.texture], g.camera, 0, RenderSettings(depthTestEnabled : false))]



main(GameSetup(
   windowSize : vec2i(1440,900),
   resizeable : false,
   windowTitle : "Windowing Test",
   gameComponents : @[(GameComponent)(new PrintComponent)],
   graphicsComponents : @[createCameraComponent(createPixelCamera(1)), DrawQuadComponent()]
))

