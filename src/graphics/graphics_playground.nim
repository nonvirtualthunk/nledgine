import nimgl/[glfw, opengl]

import ../engines
import ../reflect
import tables
import color
import core
import glm
import easygl
import os


var eventChannel: Channel[Event]
eventChannel.open()

var drawCommandChannel: Channel[DrawCommand]
drawCommandChannel.open()

var goChannel: Channel[bool]
goChannel.open()

var activeModifiers = KeyModifiers()

proc runEngine() {.gcsafe.} =
   var eventBuffer = createEventBuffer(1000)

   let vao = Vao[SimpleVertex, uint16]()
   for i in 0..<4:
      vao.vertices[i].vertex = UnitSquareVertices[i] * 100f
      vao.vertices[i].color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
      vao.vertices[i].texCoords = UnitSquareVertices[i].xy

   vao.indices[0] = 0
   vao.indices[1] = 1
   vao.indices[2] = 2

   vao.indices[3] = 2
   vao.indices[4] = 3
   vao.indices[5] = 0

   vao.swap()

   let shader = Shader(
       vertexSource: "resources/shaders/simple.vertex",
       fragmentSource: "resources/shaders/simple.fragment"
   )
   var proj = ortho(0.0f, (float)800, 0.0f, (float)600, -100.0f, 100.0f)
   var modelview = mat4f()
   shader.uniformMat4["ModelViewMatrix"] = modelview
   shader.uniformMat4["ProjectionMatrix"] = proj
   # shader.uniformInts["tex0"] = 0

   let texture: Texture = loadTexture("resources/images/book_01b.png")

   var up = true
   var y = 0.0
   var w = 100.0

   # var accum = 0.0
   # var lastTime = glfwGetTime()
   while true:
      discard goChannel.recv

      # let curTime = glfwGetTime()
      # accum += curTime - lastTime
      # lastTime = curTime

      # # if accum > 0.0166666667:
      # #     accum -= 0.01666667
      # if accum > 0.00444444444:
      #     accum -= 0.0044444444
      # else:
      #     sleep(((0.016666667 - accum) * 1000).int)

      let evtOpt = eventChannel.tryRecv()
      if evtOpt.dataAvailable:
         let evt = evtOpt.msg
         ifOfType(QuitRequest, evt):
            echo "Quitting"
            break
         ifOfType(KeyRelease, evt):
            if evt.key == KeyCode.F:
               w *= 2
               for i in 0..<4:
                  vao.vertices[i].vertex = UnitSquareVertices[i] * w
                  vao.vertices[i].color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
                  vao.vertices[i].texCoords = UnitSquareVertices[i].xy

               vao.indices[0] = 0
               vao.indices[1] = 1
               vao.indices[2] = 2

               vao.indices[3] = 2
               vao.indices[4] = 3
               vao.indices[5] = 0
               vao.swap()
         eventBuffer.addEvent(evt)

      if up:
         y += 1
         if y > 500:
            up = false
      else:
         y -= 1
         if y < 0:
            up = true

      let m = mat4f()
      let tm = translate(m, vec3f(0.0f, y.float, 0.0f))
      shader.uniformMat4["ModelViewMatrix"] = tm
      let drawCommand = draw(vao, shader, @[texture])
      drawCommandChannel.send(drawCommand)




var engineThread: Thread[void]
createThread(engineThread, runEngine)

proc keyDownProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
   if key == GLFWKey.ESCAPE and action == GLFWPress:
      eventChannel.send(QuitRequest())
      window.setWindowShouldClose(true)

   if action == GLFWPress:
      let isFirstPress = not isKeyDown(key.KeyCode)
      if isFirstPress:
         setKeyDown(key.KeyCode, true)
         eventChannel.send(KeyPress(key: key.KeyCode, modifiers: activeKeyModifiers()))
   elif action == GLFWRelease:
      setKeyDown(key.KeyCode, false)
      eventChannel.send(KeyRelease(key: key.KeyCode, modifiers: activeKeyModifiers()))



proc main() =
   assert glfwInit()

   glfwWindowHint(GLFWContextVersionMajor, 3)
   glfwWindowHint(GLFWContextVersionMinor, 3)
   glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for Mac
   glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
   glfwWindowHint(GLFWResizable, GLFW_FALSE)

   let w: GLFWWindow = glfwCreateWindow(800, 600, "NimGL")
   if w == nil:
      quit(-1)

   glfwSwapInterval(1)

   discard w.setKeyCallback(keyDownProc)
   w.makeContextCurrent()

   assert glInit()

   let windowWidth: ptr[int32] = create(int32)
   let windowHeight: ptr[int32] = create(int32)
   getWindowSize(w, windowWidth, windowHeight)

   disable(GL_CULL_FACE)

   glViewport(0, 0, windowWidth[], windowHeight[])

   var lastUpdated = glfwGetTime()

   var drawCommands: seq[DrawCommand]


   while not w.windowShouldClose:
      glfwPollEvents()
      glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
      glClear(GL_COLOR_BUFFER_BIT)

      let curTime = glfwGetTime()
      let deltaFrames = (curTime - lastUpdated)/0.0166666666667
      lastUpdated = curTime

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

      for i in 0 ..< drawCommands.len:
         if drawCommands[i].vao != 0:
            drawCommands[i].render()

      goChannel.send(true)
      w.swapBuffers()

   w.destroyWindow()
   glfwTerminate()

main()
