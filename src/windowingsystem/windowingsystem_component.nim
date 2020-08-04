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
import ax4/game/cards
import game/library

type
   WindowingSystemComponent* = ref object of GraphicsComponent
      vao: VAO[WVertex, uint32]
      texture: TextureBlock
      shader: Shader
      camera: Camera
      initTime: UnitOfTime

proc createWindowingSystemComponent*(): WindowingSystemComponent =
   WindowingSystemComponent(
      initializePriority: 10,
      eventPriority: 100
   )

proc render(g: WindowingSystemComponent, display: DisplayWorld) =
   display[WindowingSystem].render(g.vao, g.texture)

method initialize(g: WindowingSystemComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "WindowingSystemComponent"
   g.initTime = relTime()
   g.vao = newVAO[WVertex, uint32]()
   g.shader = initShader("shaders/windowing")
   g.texture = newTextureBlock(1024, 1, false)
   let windowingSystem = createWindowingSystem(display)
   windowingSystem.rootConfigPath = "ax4/widgets/"
   windowingSystem.pixelScale = 2

   display.attachDataRef(windowingSystem)
   g.camera = createWindowingCamera(1)

   windowingSystem.desktop.background = nineWayImage("ui/woodBorder.png")
   windowingSystem.desktop.background.pixelScale = 1

method onEvent(g: WindowingSystemComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   let gcd = display[GraphicsContextData]
   let ws = display[WindowingSystem]

   ifOfType(UIEvent, event):
      ifOfType(WidgetEvent, event):
         if ws.handleEvent(event, world, display):
            event.consume()
      var shouldConsume = false
      matchType(event):
         extract(MouseMove, position):
            let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
            ws.lastMousePosition = wsPos.xy
            var widget = ws.widgetAtPosition(wsPos.xy)
            shouldConsume = ws.handleEvent(WidgetMouseMove(widget: widget, position: wsPos.xy), world, display)
         extract(MouseDrag, position, button):
            let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
            ws.lastMousePosition = wsPos.xy
            var widget = ws.widgetAtPosition(wsPos.xy)
            shouldConsume = ws.handleEvent(WidgetMouseDrag(widget: widget, position: wsPos.xy, button: button), world, display)
         extract(MousePress, position, button):
            let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
            var widget = ws.widgetAtPosition(wsPos.xy)
            shouldConsume = ws.handleEvent(WidgetMousePress(widget: widget, position: wsPos.xy), world, display)
         extract(MouseRelease, position, button):
            let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
            var widget = ws.widgetAtPosition(wsPos.xy)
            shouldConsume = ws.handleEvent(WidgetMouseRelease(widget: widget, position: wsPos.xy), world, display)
         extract(KeyPress, key):
            if ws.focusedWidget.isSome:
               let widget = ws.focusedWidget.get
               shouldConsume = ws.handleEvent(WidgetKeyPress(widget: widget, key: key), world, display)
         extract(KeyRelease, key):
            if ws.focusedWidget.isSome:
               let widget = ws.focusedWidget.get
               shouldConsume = ws.handleEvent(WidgetKeyRelease(widget: widget, key: key), world, display)
         extract(RuneEnter, rune):
            if ws.focusedWidget.isSome:
               let widget = ws.focusedWidget.get
               shouldConsume = ws.handleEvent(WidgetRuneEnter(widget: widget, rune: rune), world, display)
      if shouldConsume:
         event.consume()



method update(g: WindowingSystemComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   display[WindowingSystem].update(g.texture, world, display)
   g.render(display)

   @[draw(g.vao, g.shader, @[g.texture], g.camera, 100, RenderSettings(depthTestEnabled: false))]
