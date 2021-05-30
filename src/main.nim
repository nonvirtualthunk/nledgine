import nimgl/[glfw, opengl]

import engines
import reflect
import tables
import graphics/core
import graphics/color
import glm
import application
import worlds
import resources
import noto
import os
import bitops
import unicode
import times
import noto
import prelude
import algorithm
import options
import times


var eventChannel: Channel[Event]
eventChannel.open()

var drawCommandChannel: Channel[DrawCommand]
drawCommandChannel.open()


var goChannel: Channel[bool]
goChannel.open()


type FullGameSetup = object
   setup: GameSetup
   reflectInitializers: ReflectInitializers

var engineThread: Thread[FullGameSetup]

var lastMousePosition: Vec2f
var lastMousePressPosition: Vec2f
var lastMousePressTime: float
var lastModifiers: KeyModifiers
var hasFocus: bool
var mouseButtonsDown: Table[MouseButton, bool]
var windowSize = vec2i(800, 600)
var framebufferSize = vec2i(800, 600)

# var activeModifiers = KeyModifiers()

proc runEngine(full: FullGameSetup) {.thread.} =
   for op in full.reflectInitializers:
      op()

   var gameEngine = newGameEngine()
   var liveGameEngine = newLiveGameEngine()

   var graphicsEngine = if full.setup.useLiveWorld or full.setup.liveGameComponents.len > 0:
     newGraphicsEngine(liveGameEngine)
   else:
     newGraphicsEngine(gameEngine)

   graphicsEngine.displayWorld.attachData(GraphicsContextData)

   for gc in full.setup.gameComponents:
      gameEngine.addComponent(gc)
   gameEngine.initialize()
   for gc in full.setup.liveGameComponents:
      liveGameEngine.addComponent(gc)
   liveGameEngine.initialize()
   for gc in full.setup.graphicsComponents:
      graphicsEngine.addComponent(gc)
   graphicsEngine.initialize()


   var lastTime = glfwGetTime()
   var quit = false
   while not quit:
      # let curTime = glfwGetTime()
      # let dt = curTime - lastTime
      # if dt < 0.01666666667:
      #    sleep(((0.01666667 - dt) * 0.75 * 1000).int)
      #    continue
      # lastTime = curTime
      discard goChannel.recv

      while true:
         let evtOpt = eventChannel.tryRecv()
         if evtOpt.dataAvailable:
            let evt = evtOpt.msg
            ifOfType(QuitRequest, evt):
               echo "Quitting"
               quit = true
            ifOfType(WindowResolutionChanged, evt):
               let gctxt = graphicsEngine.displayWorld[GraphicsContextData]
               gctxt.windowSize = evt.windowSize
               gctxt.framebufferSize = evt.framebufferSize
            graphicsEngine.displayWorld.addEvent(evt)
         else:
            break

      gameEngine.update()
      liveGameEngine.update()
      graphicsEngine.update(drawCommandChannel, 1.0f)



proc toKeyModifiers(mods: int32): KeyModifiers =
   let shift = (mods.bitand(GLFWModShift)) != 0
   let alt = (mods.bitand(GLFWModAlt)) != 0
   let ctrl = (mods.bitand(GLFWModControl)) != 0 or (mods.bitand(GLFWModSuper)) != 0
   KeyModifiers(shift: shift, alt: alt, ctrl: ctrl)

proc keyDownProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
   if key == GLFWKey.Q and action == GLFWPress and (mods.bitand(GLFWModControl) != 0 or mods.bitand(GLFWModSuper) != 0):
      eventChannel.send(QuitRequest())
      window.setWindowShouldClose(true)

   lastModifiers = toKeyModifiers(mods)
   if action == GLFWPress:
      if key != -1:
         let isFirstPress = not isKeyDown(key.KeyCode)

         setKeyDown(key.KeyCode, true)
         eventChannel.send(KeyPress(key: key.KeyCode, modifiers: lastModifiers, repeat: not isFirstPress))
      else:
         fine &"-1 key: {scancode}"
   elif action == GLFWRepeat:
      if key != -1:
         setKeyDown(key.KeyCode, true)
         eventChannel.send(KeyPress(key: key.KeyCode, modifiers: lastModifiers, repeat: true))
      else:
         fine &"-1 key: {scancode}"
   elif action == GLFWRelease:
      if key != -1:
         setKeyDown(key.KeyCode, false)
         eventChannel.send(KeyRelease(key: key.KeyCode, modifiers: lastModifiers))
      else:
         fine &"-1 key: {scancode}"

proc mouseButtonProc(window: GLFWWindow, buttonRaw: int32, action: int32, mods: int32): void {.cdecl.} =
   let button = mouseButtonFromGlfw(buttonRaw)
   lastModifiers = toKeyModifiers(mods)
   if action == GLFWPress:
      mouseButtonsDown[button] = true
      setMouseButtonDown(button, true)
      lastMousePressPosition = lastMousePosition
      let t = inMilliseconds(now() - programStartTime).float / 1000.0
      let doublePress = (t - lastMousePressTime) < 0.25
      lastMousePressTime = t
      eventChannel.send(MousePress(position: lastMousePosition, modifiers: lastModifiers, button: button, doublePress: doublePress))
   elif action == GLFWRelease:
      mouseButtonsDown[button] = false
      setMouseButtonDown(button, false)
      eventChannel.send(MouseRelease(position: lastMousePosition, modifiers: lastModifiers, button: button))

proc mouseMoveProc(window: GLFWWindow, x: float, y: float): void {.cdecl.} =
   if x >= 0 and y >= 0 and x < windowSize.x.float and y < windowSize.y.float:
      let delta = vec2f(x, y) - lastMousePosition
      lastMousePosition = vec2f(x, y)

      for button in MouseButton:
         if mouseButtonsDown.getOrDefault(button, false):
            eventChannel.send(MouseDrag(position: lastMousePosition, modifiers: lastModifiers, delta: delta, origin: lastMousePressPosition, button: button))
            return

      eventChannel.send(MouseMove(position: lastMousePosition, modifiers: lastModifiers, delta: delta))

proc charEnterProc(window: GLFWWindow, codePoint: uint32): void {.cdecl.} =
   let rune = codePoint.Rune
   eventChannel.send(RuneEnter(rune: rune, modifiers: lastModifiers))

proc focusProc(window: GLFWWindow, focus: bool): void {.cdecl.} =
   if focus != hasFocus:
      hasFocus = focus
      if focus:
         eventChannel.send(WindowFocusGained())
      else:
         eventChannel.send(WindowFocusLost())

proc windowSizeCallback(window: GLFWWindow, width: int32, height: int32): void {.cdecl.} =
   windowSize = vec2i(width, height)
   eventChannel.send(WindowResolutionChanged(windowSize: windowSize, framebufferSize: framebufferSize))

proc framebufferSizeCallback(window: GLFWWindow, width: int32, height: int32): void {.cdecl.} =
   framebufferSize = vec2i(width, height)
   eventChannel.send(WindowResolutionChanged(windowSize: windowSize, framebufferSize: framebufferSize))

proc errorCallback(errorCode: int32, err: cstring): void {.cdecl.} =
   echo "GLFW ERROR[", errorCode, "]: ", err

proc toGLFWBool(b: bool): int32 =
   if b:
      GLFW_TRUE
   else:
      GLFW_FALSE

proc main*(setup: GameSetup) =
   assert glfwInit()

   glfwWindowHint(GLFWContextVersionMajor, 3)
   glfwWindowHint(GLFWContextVersionMinor, 3)
   glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for Mac
   glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
   glfwWindowHint(GLFWResizable, toGLFWBool(setup.resizeable))
   glfwWindowHint(GLFW_SRGB_CAPABLE, GLFW_FALSE)

   let w: GLFWWindow = if not setup.fullscreen:
      glfwCreateWindow(setup.windowSize.x, setup.windowSize.y, setup.windowTitle)
   else:
      let vidMode = getVideoMode(glfwGetPrimaryMonitor())
      glfwCreateWindow(vidMode.width, vidMode.height, setup.windowTitle, glfwGetPrimaryMonitor())

   if w == nil:
      quit(-1)

   glfwSwapInterval(1)

   var width: int32 = 0
   var height: int32 = 0
   getWindowSize(w, width.addr, height.addr)
   windowSize = vec2i(width, height)
   getFramebufferSize(w, width.addr, height.addr)
   framebufferSize = vec2i(width, height)

   eventChannel.send(WindowResolutionChanged(windowSize: windowSize, framebufferSize: framebufferSize))
   discard w.setFramebufferSizeCallback(framebufferSizeCallback)
   discard w.setWindowSizeCallback(windowSizeCallback)
   discard glfwSetErrorCallback(errorCallback)

   discard w.setKeyCallback(keyDownProc)
   discard w.setMouseButtonCallback(mouseButtonProc)
   discard w.setCursorPosCallback(mouseMoveProc)
   discard w.setCharCallback(charEnterProc)
   discard w.setWindowFocusCallback(focusProc)
   w.makeContextCurrent()

   assert glInit()

   var drawCommands: seq[DrawCommand]

   createThread(engineThread, runEngine, FullGameSetup(setup: setup, reflectInitializers: reflectInitializers))

   var lastViewport = vec2i(0, 0)

   glEnable(GL_BLEND)
   glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

   glDisable(GL_FRAMEBUFFER_SRGB)

   let windowInitTime = relTime()
   var first = true

   var cursorShowing = true
   var cursorsByImage : Table[string, GLFWCursor]
   var standardCursors : Table[int, GLFWCursor]
   var activeStandardCursor = 0

   while not w.windowShouldClose:
      if lastViewport != framebufferSize:
         glViewport(0, 0, framebufferSize.x, framebufferSize.y)
         lastViewport = framebufferSize

      glfwPollEvents()
      glClearColor(setup.clearColor.r, setup.clearColor.g, setup.clearColor.b, setup.clearColor.a)
      glClear(GL_COLOR_BUFFER_BIT)

      if hasFocus:
         while true:
            let ctxtCommandOpt = graphicsContextCommandChannel.tryRecv()
            if ctxtCommandOpt.dataAvailable:
               let ctxCommand = ctxtCommandOpt.msg
               case ctxCommand.kind:
               of GraphicsContextCommandKind.CursorCommand:
                  if ctxCommand.cursorEnabled:
                     if not cursorShowing:
                        cursorShowing = true
                        setInputMode(w, GLFWCursorSpecial, GLFWCursorNormal)
                  else:
                     if cursorShowing:
                        cursorShowing = false
                        setInputMode(w, GLFWCursorSpecial, GLFWCursorHidden)

                  if ctxCommand.cursorIcon.isSome:
                     warn &"todo: support custom cursor icons"
                  elif ctxCommand.standardCursor.isSome:
                     let cursorType = ctxCommand.standardCursor.get
                     if cursorType != activeStandardCursor:
                        activeStandardCursor = cursorType
                        if cursorType == 0:
                           setCursor(w, nil)
                        else:
                           let cursor = standardCursors.getOrCreate(cursorType):
                              glfwCreateStandardCursor(cursorType.int32)
                           setCursor(w, cursor)

            else:
               break

         while true:
            let drawCommandOpt = drawCommandChannel.tryRecv()
            if drawCommandOpt.dataAvailable:
               let newComm = drawCommandOpt.msg
               while drawCommands.len <= newComm.vao:
                  drawCommands.add(default(DrawCommand))
               if drawCommands[newComm.vao].vao == 0:
                  drawCommands[newComm.vao] = newComm
               else:
                  drawCommands[newComm.vao].merge(newComm)
            else:
               break

         var drawCommandIndices = newSeq[int](drawCommands.len)
         for i in 0 ..< drawCommands.len:
            drawCommandIndices[i] = i
         let sortedDrawCommandIndices = drawCommandIndices.sortedByIt(drawCommands[it].drawOrder)

         for i in 0 ..< sortedDrawCommandIndices.len:
            if drawCommands[sortedDrawCommandIndices[i]].vao != 0:
               drawCommands[sortedDrawCommandIndices[i]].render(framebufferSize)

         discard goChannel.trySend(true)
         w.swapBuffers()
      else:
         sleep(100)

      if first:
         info &"Time to first frame drawn: {(relTime() - windowInitTime).inSeconds}"
         first = false

   w.destroyWindow()
   glfwTerminate()

# const appName {.strdefine.} : string = "None"

# when appName == "Ax4":
#    main(GameSetup(
#       windowSize : vec2i(1024,768),
#       resizeable : false,
#       windowTitle : "Ax4"
#    ))

# when appName == "None":
#    echo "Specify an appName when compiling"
