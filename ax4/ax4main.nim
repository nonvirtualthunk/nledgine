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


type 
    PrintComponent = ref object of GameComponent
        updateCount : int
        lastPrint : UnitOfTime

    DrawQuadComponent = ref object of GraphicsComponent
        vao : VAO[SimpleVertex, uint16]
        texture : Texture
        shader : Shader
        y : float
        size : float
        dy : float
        needsUpdate: bool


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
    for i in 0..<4:
        g.vao.vertices[i].vertex = UnitSquareVertices[i] * g.size
        g.vao.vertices[i].color = rgba(1.0f,1.0f,1.0f,1.0f)
        g.vao.vertices[i].texCoords = UnitSquareVertices[i].xy

    g.vao.indices[0] = 0
    g.vao.indices[1] = 1
    g.vao.indices[2] = 2

    g.vao.indices[3] = 2
    g.vao.indices[4] = 3
    g.vao.indices[5] = 0
    g.vao.swap()
    g.needsUpdate = false

method initialize(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld) =
    g.vao = newVAO[SimpleVertex, uint16]()
    g.shader = initShader("shaders/simple")
    g.texture = loadTexture("resources/images/book_01b.png")
    g.y = 0.0f
    g.size = 100.0f
    g.render()

    g.onEvent(KeyRelease, kre):
        if kre.key == KeyCode.F:
            g.size *= 2
            g.needsUpdate = true

method update(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
    if g.needsUpdate:
        g.render()
    @[draw(g.vao, g.shader, @[g.texture], display[CameraData].camera)]

main(GameSetup(
    windowSize : vec2i(1024,768),
    resizeable : false,
    windowTitle : "Ax4",
    gameComponents : @[(GameComponent)(new PrintComponent)],
    graphicsComponents : @[createCameraComponent(createPixelCamera(1)), DrawQuadComponent()]
))

