import ../main
import ../application
import glm
import ../engines
import ../worlds
import ../prelude
import ../graphics
import tables
import ../noto
import ../resources
import ../graphics/texture_block
import ../graphics/images
import windowingsystem
import windowingsystem/text_widget
import config
import options
import ax4/game/cards
import game/library
import windowingsystem/windowingsystem_component
import windowingsystem/list_widget

type
   PrintComponent = ref object of GameComponent
      updateCount: int
      lastPrint: UnitOfTime

   DrawQuadComponent = ref object of GraphicsComponent
      vao: VAO[WVertex, uint32]
      texture: TextureBlock
      shader: Shader
      needsUpdate: bool
      camera: Camera
      initTime: UnitOfTime
      card: CardArchetype

method initialize(g: PrintComponent, world: World) =
   echo "Initialized"

method update(g: PrintComponent, world: World) =
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

method initialize(g: DrawQuadComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.initTime = relTime()
   let windowingSystem = display[WindowingSystem]
   windowingSystem.rootConfigPath = "ax4/widgets/"
   windowingSystem.pixelScale = 2

   windowingSystem.desktop.background = nineWayImage("ui/woodBorder.png")
   windowingSystem.desktop.background.pixelScale = 1

   let widget = windowingSystem.createWidget("CardWidgets", "CardWidget")
   #  let widget = windowingSystem.createWidget("demo/widgets/main_widgets.sml", "widget")
   #  let child = widget.childByIdentifier("child").get
   #  let rightChild = widget.childByIdentifier("rightChild").get
   #  let textChild = widget.childByIdentifier("textChild").get
   #  let textChild2 = widget.childByIdentifier("textChild2").get

   let world = createWorld()

   g.card = library(CardArchetype)[taxon("CardTypes", "Move")]
   let cardInfo = cardInfoFor(world, SentinelEntity, g.card, 0)

   widget.bindValue("card", cardInfo)

   # widget.onEvent(WidgetMouseMove, mouseMoveEvent):
   #    echo "Mouse move event: ", mouseMoveEvent.originatingWidget.identifier
   widget.onEvent(WidgetMouseEnter, mouseEnter):
      echo "top level mouse enter event: ", mouseEnter.originatingWidget.identifier
   widget.onEvent(ListItemMouseOver, mouseOver):
      echo "Moused over list item: ", mouseOver.index, " from ", mouseOver.originatingWidget.identifier
      let cardInfo = cardInfoFor(world, SentinelEntity, g.card, mouseOver.index)
      widget.bindValue("card", cardInfo)



method onEvent(g: DrawQuadComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   ifOfType(KeyPress, event):
      display[WindowingSystem].desktop.bindValue("text1", $event.key)


method update(g: DrawQuadComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   discard



main(GameSetup(
   windowSize: vec2i(1440, 900),
   resizeable: false,
   windowTitle: "Windowing Test",
   gameComponents: @[(GameComponent)(new PrintComponent)],
   graphicsComponents: @[WindowingSystemComponent(), DrawQuadComponent()]
))

