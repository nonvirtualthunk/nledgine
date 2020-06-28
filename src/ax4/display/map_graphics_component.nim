import engines
import graphics
import prelude
import tables
import ax4/game/map
import hex
import graphics/cameras
import graphics/camera_component
import tables
import resources
import graphics/image_extras
import data/mapGraphicsData
import data/cullingData
import game/library
import options
import noto
import events

type
    MapGraphicsComponent* = ref object of GraphicsComponent
        vao : Vao[SimpleVertex, uint16]
        texture : TextureBlock
        shader : Shader
        imagesByKind : Table[Taxon, Image]
        cullWatcher : Watcher[int]
        hexSize : float

        overlayVao : VAO[SimpleVertex, uint16]




method initialize(g : MapGraphicsComponent, world : World, curView : WorldView, display : DisplayWorld) =
    g.name = "MapGraphicsComponent"
    g.vao = newVAO[SimpleVertex, uint16]()
    g.shader = initShader("shaders/simple")
    g.texture = newTextureBlock(1024, 1, false)
    g.imagesByKind[taxon("vegetations", "grass")] = image("ax4/images/zeshioModified/01 Grass/01 Solid Tiles/PixelHex_zeshio_tile-001.png")
    g.cullWatcher = watcher(() => display[CullingData].revision)
    g.hexSize = mapGraphicsSettings().hexSize.float

    g.overlayVao = newVAO[SimpleVertex, uint16]()


proc render(g : MapGraphicsComponent, view : WorldView, display : DisplayWorld) =
    withView(view):
        var vi = 0
        var ii = 0

        let vegLib = library(VegetationGraphics)
        let terLib = library(TerrainGraphics)

        let cullingData = display[CullingData]

        var vegInfoByComp = newTable[(Taxon, Taxon), TilesetGraphicsInfo]()

        let map = view.data(Map)
        for hex in cullingData.hexesByCartesianCoord:
            let tileEntOpt = map.tileAt(hex)
            if tileEntOpt.isSome:
                let tileEnt = tileEntOpt.get

                let tile = tileEnt[Tile]

                var drawTerrain = true
                var imagesToDraw : seq[ImageLike]
                for vegKind in tile.vegetation:
                    if not vegInfoByComp.hasKey((vegKind, tile.terrain)):
                        vegInfoByComp[(vegKind, tile.terrain)] = vegLib[vegKind].effectiveGraphicsInfo(tile.terrain)
                    let effInfo = vegInfoByComp[(vegKind, tile.terrain)]
                    if effInfo.replaces:
                        drawTerrain = false

                if drawTerrain:
                    let terImg = terLib[tile.terrain].default.textures.pickBasedOn(tile.position.r * 147 + tile.position.q)
                    imagesToDraw.add(terImg)

                for vegKind in tile.vegetation:
                    let vegInfo = vegInfoByComp[(vegKind, tile.terrain)]
                    let img = vegInfo.textures.pickBasedOn(tile.position.q * 133 + tile.position.r)
                    imagesToDraw.add(img)

                for img in imagesToDraw:
                    let tc = g.texture[img]
                    
                    let cart = tile.position.asCartVec * g.hexSize

                    for q in 0 ..< 4:
                        let vt = g.vao[vi+q]
                        vt.vertex = cart.Vec3f + CenteredUnitSquareVertices[q] * g.hexSize
                        vt.color = rgba(1.0f,1.0f,1.0f,1.0f)
                        vt.texCoords = tc[q]
                    g.vao.addIQuad(ii,vi)
        g.vao.swap()

proc needsUpdate(g : MapGraphicsComponent) : bool =
    g.cullWatcher.hasChanged

# method onEvent(g : MapGraphicsComponent, world : World, curView : WorldView, display : DisplayWorld, event : Event) =
#     ifOfType(event, MouseMove):
#         let GCD = display[GraphicsContextData]
#         let worldPos = display[CameraData].camera.pixelToWorld(GCD.framebufferSize, GCD.windowSize, event.position)
#         echo "mouse pos: ", event.position
#         echo "\tworld pos: ", worldPos

#         let tc = g.texture[image("ax4/images/ui/hex_selection.png")]
#         for q in 0 ..< 4:
#             let vt = g.overlayVao[q]
#             vt.vertex = worldPos.Vec3f + CenteredUnitSquareVertices[q] * g.hexSize
#             vt.color = rgba(1.0f,1.0f,1.0f,1.0f)
#             vt.texCoords = tc[q]
#         var vi,ii = 0
#         g.overlayVao.addIQuad(ii,vi)
#         g.overlayVao.swap()

method update(g : MapGraphicsComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
    if g.needsUpdate:
        g.render(world.view, display)

    
    @[
        draw(g.vao, g.shader, @[g.texture], display[CameraData].camera),
        # draw(g.overlayVao, g.shader, @[g.texture], display[CameraData].camera)
    ]