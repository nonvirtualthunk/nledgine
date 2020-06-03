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
import ax4/game/map
import hex
import ax4/graphics/map_graphics_component


type 
    PrintComponent = ref object of GameComponent
        updateCount : int
        lastPrint : UnitOfTime

    DrawQuadComponent = ref object of GraphicsComponent
        vao : VAO[SimpleVertex, uint16]
        texture : TextureBlock
        shader : Shader
        y : float
        size : float
        dy : float
        needsUpdate: bool
        bookImg : Image
        swordImg : Image

    MapInitializationComponent = ref object of GameComponent


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
    var vi = 0
    var ii = 0

    let bookTexCoords = g.texture[g.bookImg]
    for i in 0..<4:
        g.vao.vertices[i].vertex = UnitSquareVertices[i] * g.size
        g.vao.vertices[i].color = rgba(1.0f,1.0f,1.0f,1.0f)
        g.vao.vertices[i].texCoords = bookTexCoords[i]
    g.vao.addIQuad(ii, vi)

    let swordTexCoords = g.texture[g.swordImg]
    for i in 0..<4:
        g.vao.vertices[vi+i].vertex = UnitSquareVertices[i] * g.size + vec3f(g.size + 10, 0.0f, 0.0f)
        g.vao.vertices[vi+i].color = rgba(1.0f,1.0f,1.0f,1.0f)
        g.vao.vertices[vi+i].texCoords = swordTexCoords[i]
    g.vao.addIQuad(ii, vi)

    g.vao.swap()
    g.needsUpdate = false

method initialize(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld) =
    g.vao = newVAO[SimpleVertex, uint16]()
    g.bookImg = image("images/book_01b.png")
    g.swordImg = image("images/sword_02b.png")
    g.shader = initShader("shaders/simple")
    g.texture = newTextureBlock(1024, 1, false)
    g.texture.addImage(g.bookImg)
    g.texture.addImage(g.swordImg)
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





method initialize(g : MapInitializationComponent, world : World) = 
    let grass = taxon("vegetations", "Grass")
    withWorld(world):
        var map = createMap(vec2i(50,50))
        for r in 0 ..< 10:
            for hex in hexRing(axialVec(0,0), r):
                let tile = world.createEntity()
                tile.attachData(Tile(
                    position : hex,
                    terrainKind : grass
                ))
                map.setTileAt(hex, tile)
        world.attachData(map)

method update(g : MapInitializationComponent, world : World) = discard

main(GameSetup(
    windowSize : vec2i(1440,900),
    resizeable : false,
    windowTitle : "Ax4",
    gameComponents : @[(GameComponent)(new PrintComponent), new MapInitializationComponent],
    graphicsComponents : @[createCameraComponent(createPixelCamera(1)), DrawQuadComponent(), MapGraphicsComponent()]
))

