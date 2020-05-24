import nimgl/[glfw, opengl]

import ../engines
import ../reflect
import tables
import color
import core
import glm
import easygl

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

    let windowWidth : ptr[int32] = create(int32)
    let windowHeight : ptr[int32] = create(int32)
    getWindowSize(w, windowWidth, windowHeight)

    let vao = Vao[SimpleVertex, uint16]()
    for i in 0..<4:
        vao.vertices[i].vertex = UnitSquareVertices[i] * 100f
        vao.vertices[i].color = rgba(1.0f,1.0f,1.0f,1.0f)
        vao.vertices[i].texCoords = UnitSquareVertices[i].xy

    vao.indices[0] = 0
    vao.indices[1] = 1
    vao.indices[2] = 2

    vao.indices[3] = 2
    vao.indices[4] = 3
    vao.indices[5] = 0

    vao.swap()

    let shader = Shader(
        vertexSource : "resources/shaders/simple.vertex",
        fragmentSource : "resources/shaders/simple.fragment"
    )
    var proj = ortho(0.0f,(float) windowWidth[],0.0f,(float) windowHeight[],-100.0f,100.0f)
    var modelview = mat4f()
    shader.uniformMat4["ModelViewMatrix"] = modelview
    shader.uniformMat4["ProjectionMatrix"] = proj
    shader.uniformInts["tex0"] = 0

    let texture = loadTexture("resources/images/book_01b.png")

    var drawCommand = draw(vao, shader, @[texture])

    # let textureI = genTexture()
    # bindTexture(GL_TEXTURE_0, textureI)

    # for tex in drawCommand.textures:
    #     glTexImage2D(GL_TEXTURE_2D, 0.GLint, tex.internalFormat.GLint, tex.width.GLint, tex.height.GLint, 0.GLint, tex.dataFormat, GL_UNSIGNED_BYTE, tex.data)

    # let shaderI = createAndLinkProgram(drawCommand.shader.vertexSource, drawCommand.shader.fragmentSource)
    # let vaoI = genVertexArray()
    # let vboI = genBuffer()
    # let vioI = genBuffer()

    # bindVertexArray(vaoI)

    # bindBuffer(GL_ARRAY_BUFFER, vboI)
    # bufferData(GL_ARRAY_BUFFER, drawCommand.vertexBuffer.len, drawCommand.vertexBuffer.data, GL_STATIC_DRAW)

    # bindBuffer(GL_ELEMENT_ARRAY_BUFFER, vioI)
    # bufferData(GL_ELEMENT_ARRAY_BUFFER, drawCommand.indexBuffer.len, drawCommand.indexBuffer.data, GL_STATIC_DRAW)

    # for index, varr in drawCommand.vertexArrayDefinitions:
    #     vertexAttribPointer(index.uint32, varr.num, varr.dataType, varr.normalize, varr.stride, varr.offset)
    #     enableVertexAttribArray(index.uint32)

    disable(GL_CULL_FACE)
    
    glViewport(0,0,windowWidth[],windowHeight[])

    while not w.windowShouldClose:
        glfwPollEvents()
        glClearColor(0.0f,0.0f,0.0f,1.0f)
        glClear(GL_COLOR_BUFFER_BIT)

        # var proj = ortho(0.0f,(float) windowWidth[],0.0f,(float) windowHeight[],-100.0f,100.0f)
        # var modelview = mat4f()

        # shaderI.use()
        # shaderI.setMat4("ModelViewMatrix", modelview)
        # shaderI.setMat4("ProjectionMatrix", proj)
        # shaderI.setInt("tex0", 0)

        # bindVertexArray(vaoI)

        # bindTexture(GL_TEXTURE_0, textureI)

        # drawElements(GL_TRIANGLES, 6, drawCommand.indexBufferType, 0)

        drawCommand.render()

        w.swapBuffers()

    w.destroyWindow()
    glfwTerminate()

main()