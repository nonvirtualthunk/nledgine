import windowing_system_core
import worlds
import graphics
import prelude
import text_widget
import image_widget
import list_widget
import bar_widget
import divider_widget
import nimclipboard/libclipboard

export windowing_system_core

proc createWindowingSystem*(display: DisplayWorld, rootConfigPath: string): WindowingSystemRef =
   result = new WindowingSystem
   result.desktop = new Widget
   result.desktop.showing = bindable(true)
   result.desktop.windowingSystem = result
   result.desktop.identifier = "Desktop"
   result.display = display
   result.dimensions = display[GraphicsContextData].framebufferSize
   result.pixelScale = 1
   result.lastWidgetUnderMouse = result.desktop
   result.rootConfigPath = rootConfigPath
   result.clipboard = clipboard_new(nil)
   ifPresent(configOpt(rootConfigPath & "Stylesheet.sml")):
     result.stylesheet = it
   for e in RecalculationFlag:
      result.desktop.markForUpdate(e)
   result.components.add(TextDisplayRenderer())
   result.components.add(ImageDisplayComponent())
   result.components.add(ListWidgetComponent())
   result.components.add(BarWidgetComponent())
   result.components.add(DividerComponent())








when isMainModule:
   import noto

   let display = createDisplayWorld()
   display.attachData(GraphicsContextData)
   display[GraphicsContextData].framebufferSize = vec2i(800, 600)
   let ws = createWindowingSystem(display, "ax4/widgets/")

   ws.update()

   let widget = ws.createWidget()

   ws.update()

   echoAssert widget.resolvedPosition.x == 0
   echoAssert widget.resolvedPosition.y == 0
   echoAssert widget.resolvedDimensions.x == 10
   echoAssert widget.resolvedDimensions.y == 10

   widget.x = fixedPos(12)
   widget.y = proportionalPos(0.1)
   widget.width = fixedSize(20)
   widget.height = proportionalSize(0.5)

   ws.update()

   echoAssert widget.resolvedPosition.x == 12
   echoAssert widget.resolvedPosition.y == 60
   echoAssert widget.resolvedDimensions.x == 20
   echoAssert widget.resolvedDimensions.y == 300

   let childWidget = ws.createWidget()
   childWidget.parent = widget

   childWidget.width = relativeSize(-5)
   childWidget.height = wrapContent()


   let subChildWidget = ws.createWidget()
   subChildWidget.parent = childWidget
   subChildWidget.x = fixedPos(5)
   subChildWidget.y = fixedPos(7)
   subChildWidget.width = fixedSize(20)
   subChildWidget.height = fixedSize(30)

   ws.update()

   echoAssert childWidget.resolvedPosition.x == 12
   echoAssert subChildWidget.resolvedPosition.x == 17
   echoAssert childWidget.resolvedDimensions.x == 15
   echoAssert childWidget.resolvedDimensions.y == 37

   info "====================="
   subChildWidget.x = fixedPos(6)

   ws.update()
