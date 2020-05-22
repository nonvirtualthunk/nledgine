import nimgl/[glfw, opengl]

import engines
import reflect
import tables

var eventChannel : Channel[Event]
eventChannel.open()



var activeModifiers = KeyModifiers()

proc runEngine() = 
    var eventBuffer = createEventBuffer(1000)

    while true:
        let evtOpt = eventChannel.tryRecv()
        if evtOpt.dataAvailable:
            let evt = evtOpt.msg
            ifOfType(evt, QuitRequest):
                echo "Quitting"
                break
            eventBuffer.addEvent(evt)
        
        
            

var engineThread : Thread[void]
createThread(engineThread, runEngine)

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

    while not w.windowShouldClose:
        glfwPollEvents()
        glClearColor(0.68f, 1f, 0.34f, 1f)
        glClear(GL_COLOR_BUFFER_BIT)
        w.swapBuffers()

    w.destroyWindow()
    glfwTerminate()

main()