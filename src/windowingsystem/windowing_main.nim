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
import windowingsystem/text_widget
import config
import options

type 
    PrintComponent = ref object of GameComponent
        updateCount : int
        lastPrint : UnitOfTime

    DrawQuadComponent = ref object of GraphicsComponent
        vao : VAO[WVertex, uint32]
        texture : TextureBlock
        shader : Shader
        needsUpdate: bool
        camera : Camera
        initTime : UnitOfTime


        

method initialize(g : PrintComponent, world : World) =
    echo "Initialized"

method update(g : PrintComponent, world : World) =
    g.updateCount.inc
    let curTime = relTime()
    if curTime - g.lastPrint > seconds(2.0f):
        g.lastPrint = curTime
        let updatesPerSecond = (g.updateCount / 2)
        if updatesPerSecond < 59:
            info "Updates / second (sub 60) : ", updatesPerSecond
        else:
            fine "Updates / second : ", updatesPerSecond
        g.updateCount = 0


proc render(g : DrawQuadComponent, display: DisplayWorld) =

    # let swordTexCoords = g.texture[g.swordImg]
    # for i in 0..<4:
    #     g.vao.vertices[vi+i].vertex = UnitSquareVertices[i] * g.size + vec3f(g.size + 10, 0.0f, 0.0f)
    #     g.vao.vertices[vi+i].color = rgba(1.0f,1.0f,1.0f,1.0f)
    #     g.vao.vertices[vi+i].texCoords = swordTexCoords[i]
    # g.vao.addIQuad(ii, vi)

    display[WindowingSystem].render(g.vao, g.texture)

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
    g.initTime = relTime()
    g.vao = newVAO[WVertex, uint32]()
    g.shader = initShader("shaders/windowing")
    g.texture = newTextureBlock(1024, 1, false)
    let windowingSystem = createWindowingSystem(display)
    windowingSystem.pixelScale = 2

    display.attachDataRef(windowingSystem)
    g.camera = createWindowingCamera(2)
    g.needsUpdate = true

    windowingSystem.desktop.background = nineWayImage("ui/woodBorder.png")

    # let widget = windowingSystem.createWidget()
    # widget.background = nineWayImage("ui/minimalistBorder.png")
    # widget.x = fixedPos(50)
    # widget.y = fixedPos(50)
    # widget.width = fixedSize(500)
    # widget.height = fixedSize(500)

    # # let child = windowingSystem.createWidget()
    # # child.background = nineWayImage("ui/buttonBackground.png")
    # # child.parent = widget
    # # child.x = fixedPos(10)
    # # child.y = fixedPos(10)
    # # child.width = proportionalSize(0.5)
    # # child.height = relativeSize(-20)

    # let child = windowingSystem.createWidgetFromConfig("child",parseConfig("""
    #     background.image : "ui/buttonBackground.png"
    #     x : 10
    #     y : 10
    #     width : 0.5
    #     height : -20
    # """), widget)

    let widget = windowingSystem.createWidget("demo/widgets/main_widgets.sml", "widget")
    let child = widget.childByIdentifier("child").get
    let rightChild = widget.childByIdentifier("rightChild").get
    let textChild = widget.childByIdentifier("textChild").get
    let textChild2 = widget.childByIdentifier("textChild2").get

    let quote = richText("There are not many persons who know what wonders are opened to them in the stories and visions of their youth; for when as children we listen and dream, we think but half-formed thoughts, and when as men we try to remember, we are dulled and prosaic with the poison of life.")
    # discard updateBindings(textChild2.data(TextDisplay)[], boundValueResolver({"text2" : bindValue(quote)}.toTable))
    textChild2.bindValue("text2", quote)

    # let textChild2 = windowingSystem.createWidget(widget)
    # textChild2.attachData(TextDisplay(
    #     text : bindable(richText("There are not many persons who know what wonders are opened to them in the stories and visions of their youth; for when as children we listen and dream, we think but half-formed thoughts, and when as men we try to remember, we are dulled and prosaic with the poison of life.")),
    #     fontSize : 16,
    #     color : bindable(rgba(0,0,0,1.0f))
    # ))
    # textChild2.x = relativePos(textChild, 10, WidgetOrientation.TopRight)
    # textChild2.y = fixedPos(10)
    # textChild2.width = expandToParent(10)
    # textChild2.height = intrinsic()
    # textChild2.background = nineWayImage("ui/minimalistBorder.png")
    # textChild2.padding = vec3i(2,2,0)





method update(g : DrawQuadComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
    if g.needsUpdate:
        display[WindowingSystem].update(g.texture)
        g.render(display)
        # echo g.vao.vertices
        info "Seconds till first render: " , (relTime() - g.initTime).as(second)
    
    @[draw(g.vao, g.shader, @[g.texture], g.camera, RenderSettings(depthTestEnabled : false))]



main(GameSetup(
    windowSize : vec2i(1440,900),
    resizeable : false,
    windowTitle : "Windowing Test",
    gameComponents : @[(GameComponent)(new PrintComponent)],
    graphicsComponents : @[createCameraComponent(createPixelCamera(1)), DrawQuadComponent()]
))

