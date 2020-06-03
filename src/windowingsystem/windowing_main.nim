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


type 
    PrintComponent = ref object of GameComponent
        updateCount : int
        lastPrint : UnitOfTime

    DrawQuadComponent = ref object of GraphicsComponent
        vao : VAO[WVertex, uint32]
        texture : TextureBlock
        shader : Shader
        needsUpdate: bool
        windowingSystem : WindowingSystem
        camera : Camera


        

method initialize(g : PrintComponent, world : World) =
    echo "Initialized"

method update(g : PrintComponent, world : World) =
    g.updateCount.inc
    let curTime = relTime()
    if curTime - g.lastPrint > seconds(2.0f):
        g.lastPrint = curTime
        info "Updates / second : ", (g.updateCount / 2)
        g.updateCount = 0


proc render(g : DrawQuadComponent) =

    # let swordTexCoords = g.texture[g.swordImg]
    # for i in 0..<4:
    #     g.vao.vertices[vi+i].vertex = UnitSquareVertices[i] * g.size + vec3f(g.size + 10, 0.0f, 0.0f)
    #     g.vao.vertices[vi+i].color = rgba(1.0f,1.0f,1.0f,1.0f)
    #     g.vao.vertices[vi+i].texCoords = swordTexCoords[i]
    # g.vao.addIQuad(ii, vi)

    g.windowingSystem.render(g.vao, g.texture)

    # var vi = g.vao.vi
    # var ii = g.vao.ii

    # let img = image("images/book_01b.png")
    # let bookTexCoords = g.texture[img]
    # for i in 0..<4:
    #     g.vao.vertices[i].vertex = UnitSquareVertices[i] * 100.0f
    #     g.vao.vertices[i].color = rgba(1.0f,1.0f,1.0f,1.0f)
    #     g.vao.vertices[i].texCoords = bookTexCoords[i]
    # g.vao.addIQuad(ii, vi)


    # echo $g.vao.vertices
    # echo $g.vao.indices

    # g.vao.swap()
    g.needsUpdate = false

method initialize(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld) =
    g.vao = newVAO[WVertex, uint32]()
    g.shader = initShader("shaders/windowing")
    g.texture = newTextureBlock(1024, 1, false)
    g.windowingSystem = createWindowingSystem(display)
    g.windowingSystem.pixelScale = 2
    g.camera = createWindowingCamera(2)
    g.needsUpdate = true

    g.windowingSystem.desktop.background = nineWayImage("ui/woodBorderTransparent.png")

    let widget = g.windowingSystem.createWidget()
    widget.background = nineWayImage("ui/minimalistBorder.png")
    widget.x = fixedPos(50)
    widget.y = fixedPos(50)
    widget.width = fixedSize(400)
    widget.height = fixedSize(400)

    let child = g.windowingSystem.createWidget()
    child.background = nineWayImage("ui/buttonBackground.png")
    child.parent = widget
    child.x = fixedPos(10)
    child.y = fixedPos(10)
    child.width = proportionalSize(0.5)
    child.height = relativeSize(-20)

method update(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
    if g.needsUpdate:
        g.windowingSystem.update()
        g.render()
    @[draw(g.vao, g.shader, @[g.texture], g.camera, RenderSettings(depthTestEnabled : false))]



main(GameSetup(
    windowSize : vec2i(1440,900),
    resizeable : false,
    windowTitle : "Windowing Test",
    gameComponents : @[(GameComponent)(new PrintComponent)],
    graphicsComponents : @[createCameraComponent(createPixelCamera(1)), DrawQuadComponent()]
))

