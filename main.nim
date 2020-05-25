import nimgl/[glfw, opengl]

import engines
import reflect
import tables
import graphics/core
import glm
import application
import worlds

var eventChannel : Channel[Event]
eventChannel.open()

var drawCommandChannel : Channel[DrawCommand]
drawCommandChannel.open()

var goChannel : Channel[bool]
goChannel.open()


type FullGameSetup = object
    setup : GameSetup
    reflectInitializers : ReflectInitializers

# var activeModifiers = KeyModifiers()

proc runEngine(full : FullGameSetup) {.thread.} = 
    for op in full.reflectInitializers:
        op()

    var gameEngine = newGameEngine()
    var graphicsEngine = newGraphicsEngine(gameEngine)
    graphicsEngine.displayWorld.attachData(GraphicsContextData)

    for gc in full.setup.gameComponents:
        gameEngine.addComponent(gc)
    gameEngine.initialize()
    for gc in full.setup.graphicsComponents:
        graphicsEngine.addComponent(gc)
    graphicsEngine.initialize()


    while true:
        discard goChannel.recv
    
        let evtOpt = eventChannel.tryRecv()
        if evtOpt.dataAvailable:
            let evt = evtOpt.msg
            ifOfType(evt, QuitRequest):
                echo "Quitting"
                break
            ifOfType(evt, WindowResolutionChanged):
                let gctxt = graphicsEngine.displayWorld[GraphicsContextData]
                gctxt.windowSize = evt.windowSize
                gctxt.framebufferSize = evt.framebufferSize
            graphicsEngine.displayWorld.addEvent(evt)
        
        gameEngine.update()
        graphicsEngine.update(drawCommandChannel, 1.0f)

        
        
            

var engineThread : Thread[FullGameSetup]

proc keyDownProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
    if key == GLFWKey.ESCAPE and action == GLFWPress:
        eventChannel.send(QuitRequest())
        window.setWindowShouldClose(true)
    
    if action == GLFWPress:
        let isFirstPress = not isKeyDown(key.KeyCode)
        if isFirstPress:
            setKeyDown(key.KeyCode, true)
            eventChannel.send(KeyPress(key : key.KeyCode, modifiers : activeKeyModifiers()))
    elif action == GLFWRelease:
        setKeyDown(key.KeyCode, false)
        eventChannel.send(KeyRelease(key : key.KeyCode, modifiers : activeKeyModifiers()))


var windowSize = vec2i(800,600)
var framebufferSize = vec2i(800,600)
proc windowSizeCallback(window : GLFWWindow, width : int32, height : int32) : void {.cdecl.} =
    windowSize = vec2i(width, height)
    eventChannel.send(WindowResolutionChanged(windowSize : windowSize, framebufferSize: framebufferSize))

proc framebufferSizeCallback(window : GLFWWindow, width : int32, height : int32) : void {.cdecl.} =
    framebufferSize = vec2i(width, height)
    eventChannel.send(WindowResolutionChanged(windowSize : windowSize, framebufferSize: framebufferSize))

proc errorCallback(errorCode : int32, err : cstring) : void {.cdecl.} =
    echo "GLFW ERROR[", errorCode, "]: ", err

proc toGLFWBool(b : bool) : int32 =
    if b:
        GLFW_TRUE
    else:
        GLFW_FALSE

proc main*(setup : GameSetup) =
    assert glfwInit()

    glfwWindowHint(GLFWContextVersionMajor, 3)
    glfwWindowHint(GLFWContextVersionMinor, 3)
    glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for Mac
    glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
    glfwWindowHint(GLFWResizable, toGLFWBool(setup.resizeable))

    let w: GLFWWindow = glfwCreateWindow(setup.windowSize.x, setup.windowSize.y, setup.windowTitle)
    if w == nil:
        quit(-1)

    glfwSwapInterval(1)

    var width: int32 = 0
    var height: int32 = 0
    getWindowSize(w, width.addr, height.addr)
    windowSize = vec2i(width, height)
    getFramebufferSize(w, width.addr, height.addr)
    framebufferSize = vec2i(width, height)

    eventChannel.send(WindowResolutionChanged(windowSize : windowSize, framebufferSize : framebufferSize))
    discard w.setFramebufferSizeCallback(framebufferSizeCallback)
    discard w.setWindowSizeCallback(windowSizeCallback)
    discard glfwSetErrorCallback(errorCallback)

    discard w.setKeyCallback(keyDownProc)
    w.makeContextCurrent()

    assert glInit()

    var drawCommands : seq[DrawCommand]

    createThread(engineThread, runEngine, FullGameSetup(setup : setup, reflectInitializers : reflectInitializers))

    var lastViewport = vec2i(0,0)

    while not w.windowShouldClose:
        if lastViewport != framebufferSize:
            glViewport(0,0,framebufferSize.x, framebufferSize.y)
            lastViewport = framebufferSize

        glfwPollEvents()
        glClearColor(0.0f,0.0f,0.0f,1.0f)
        glClear(GL_COLOR_BUFFER_BIT)

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
                drawCommands[i].render(framebufferSize)

        goChannel.send(true)
        w.swapBuffers()

    w.destroyWindow()
    glfwTerminate()

# const appName {.strdefine.} : string = "None"

# when appName == "Ax4":
#     main(GameSetup(
#         windowSize : vec2i(1024,768),
#         resizeable : false,
#         windowTitle : "Ax4"
#     ))

# when appName == "None":
#     echo "Specify an appName when compiling"