import ../main
import ../application
import glm
import ../engines
import ../worlds
import ../prelude
import ../graphics
import tables


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
        echo "Updates / second : ", (g.updateCount / 2)
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

method initialize(g : DrawQuadComponent, world : World, curView : WorldView, displayWorld : DisplayWorld) =
    g.vao = newVAO[SimpleVertex, uint16]()
    g.shader = initShader("shaders/simple")
    g.texture = loadTexture("resources/images/book_01b.png")
    g.y = 0.0f
    g.size = 100.0f
    g.render()

method update(g : DrawQuadComponent, world : World, curView : WorldView, displayWorld : DisplayWorld, df : float) : seq[DrawCommand] =
    if g.needsUpdate:
        g.render()

    var proj = ortho(0.0f,(float) 800,0.0f,(float) 600,-100.0f,100.0f)
    var modelview = mat4f()

    g.shader.uniformMat4["ModelViewMatrix"] = modelview
    g.shader.uniformMat4["ProjectionMatrix"] = proj

    @[draw(g.vao, g.shader, @[g.texture])]

main(GameSetup(
    windowSize : vec2i(1024,768),
    resizeable : false,
    windowTitle : "Ax4",
    gameComponents : @[(GameComponent)(new PrintComponent)],
    graphicsComponents : @[(GraphicsComponent)(new DrawQuadComponent)]
))

