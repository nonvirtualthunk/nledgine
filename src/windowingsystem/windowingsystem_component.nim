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
import game/library

type
  WindowingSystemComponent* = ref object of GraphicsComponent
    vao: VAO[WVertex, uint32]
    texture: TextureBlock
    shader: Shader
    camera: Camera
    initTime: UnitOfTime
    rootConfigPath: string
    extraComponents: seq[WindowingComponent]

proc createWindowingSystemComponent*(rootConfigPath: string, extraComponents: seq[WindowingComponent] = @[]): WindowingSystemComponent =
  WindowingSystemComponent(
    initializePriority: 10,
    eventPriority: 100,
    updatePriority: -100,
    rootConfigPath: rootConfigPath,
    extraComponents: extraComponents
  )

proc render(g: WindowingSystemComponent, display: DisplayWorld) =
  display[WindowingSystem].render(g.vao, g.texture)

method initialize(g: WindowingSystemComponent, display: DisplayWorld) =
  g.name = "WindowingSystemComponent"
  g.initTime = relTime()
  g.vao = newVAO[WVertex, uint32]()
  g.shader = initShader("shaders/windowing")
  g.texture = newTextureBlock(4096, 1, false)
  let windowingSystem = createWindowingSystem(display, g.rootConfigPath)
  windowingSystem.pixelScale = 2
  windowingSystem.components.add(g.extraComponents)

  display.attachDataRef(windowingSystem)
  g.camera = createWindowingCamera(1)

  windowingSystem.desktop.background = nineWayImage("ui/woodBorder.png")
  windowingSystem.desktop.background.pixelScale = 1

proc handleEventWrapper(ws: WindowingSystemRef, event: WidgetEvent, world: LiveWorld, display: DisplayWorld) : bool =
  result = handleEvent(ws, event, world, display)
  if not result:
    display.addEvent(event)

proc handleEventWrapper(ws: WindowingSystemRef, event: WidgetEvent, world: WorldView, display: DisplayWorld) : bool =
  result = handleEvent(ws, event, world, display)
  if not result:
    display.addEvent(event)

method onEvent(g: WindowingSystemComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  let gcd = display[GraphicsContextData]
  let ws = display[WindowingSystem]

  ifOfType(UIEvent, event):
    ifOfType(WidgetEvent, event):
      if handleEvent(ws, event, world, display):
        event.consume()
    var shouldConsume = false
    matchType(event):
      extract(MouseMove, position, modifiers):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        ws.lastMousePosition = wsPos.xy
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseMove(widget: widget, position: wsPos.xy, modifiers: modifiers), world, display)
      extract(MouseDrag, position, button, modifiers, origin):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        let wsOrigin = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, origin)
        ws.lastMousePosition = wsPos.xy
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseDrag(widget: widget, position: wsPos.xy, origin: wsOrigin.xy, button: button, modifiers: modifiers), world, display)
      extract(MousePress, position, button, modifiers, doublePress):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMousePress(widget: widget, position: wsPos.xy, modifiers: modifiers, doublePress: doublePress), world, display)
      extract(MouseRelease, position, button, modifiers):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseRelease(widget: widget, position: wsPos.xy, modifiers: modifiers), world, display)
      extract(KeyPress, key, repeat, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetKeyPress(widget: widget, key: key, repeat: repeat, modifiers: modifiers), world, display)
      extract(KeyRelease, key, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetKeyRelease(widget: widget, key: key, modifiers: modifiers), world, display)
      extract(RuneEnter, rune, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetRuneEnter(widget: widget, rune: rune, modifiers: modifiers), world, display)
    if shouldConsume:
      event.consume()

# Duplicated to get around weird "Error: cannot use symbol of kind 'proc' as 'let' when using a generic function
# Should try re-combining when https://github.com/nim-lang/Nim/issues/11182 is fixed
method onEvent(g: WindowingSystemComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  let gcd = display[GraphicsContextData]
  let ws = display[WindowingSystem]

  ifOfType(UIEvent, event):
    ifOfType(WidgetEvent, event):
      if handleEvent(ws, event, world, display):
        event.consume()
    var shouldConsume = false
    matchType(event):
      extract(MouseMove, position, modifiers):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        ws.lastMousePosition = wsPos.xy
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseMove(widget: widget, position: wsPos.xy, modifiers: modifiers), world, display)
      extract(MouseDrag, position, button, modifiers, origin):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        let wsOrigin = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, origin)
        ws.lastMousePosition = wsPos.xy
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseDrag(widget: widget, position: wsPos.xy, origin: wsOrigin.xy, button: button, modifiers: modifiers), world, display)
      extract(MousePress, position, button, modifiers, doublePress):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMousePress(widget: widget, position: wsPos.xy, modifiers: modifiers, doublePress: doublePress), world, display)
      extract(MouseRelease, position, button, modifiers):
        let wsPos = g.camera.pixelToWorld(gcd.framebufferSize, gcd.windowSize, position)
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseRelease(widget: widget, position: wsPos.xy, modifiers: modifiers), world, display)
      extract(KeyPress, key, repeat, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetKeyPress(widget: widget, key: key, repeat: repeat, modifiers: modifiers), world, display)
      extract(KeyRelease, key, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetKeyRelease(widget: widget, key: key, modifiers: modifiers), world, display)
      extract(RuneEnter, rune, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetRuneEnter(widget: widget, rune: rune, modifiers: modifiers), world, display)
    if shouldConsume:
      event.consume()

proc updateBase[WorldType](g: WindowingSystemComponent, world: WorldType, display: DisplayWorld, df: float): seq[DrawCommand] =
  if display[WindowingSystem].update(g.texture, world, display):
    g.render(display)

    @[draw(g.vao, g.shader, @[g.texture], g.camera, 100, RenderSettings(depthTestEnabled: false))]
  else:
    @[]

method update(g: WindowingSystemComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  updateBase(g, world, display, df)

method update(g: WindowingSystemComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  updateBase(g, world, display, df)
