import engines
import graphics
import prelude
import tables
import ax4/game/map
import hex
import graphics/cameras
import graphics/camera_component

type
    MapGraphicsComponent* = ref object of GraphicsComponent
        vao : Vao[SimpleVertex, uint16]
        texture : TextureBlock
        shader : Shader
        imagesByKind : Table[Taxon, Image]
        needsUpdate : bool


method initialize(g : MapGraphicsComponent, world : World, curView : WorldView, display : DisplayWorld) =
    g.vao = newVAO[SimpleVertex, uint16]()
    g.shader = initShader("shaders/simple")
    g.texture = newTextureBlock(1024, 1, false)
    g.imagesByKind[taxon("vegetations", "grass")] = image("images/zeshioModified/01 Grass/01 Solid Tiles/PixelHex_zeshio_tile-001.png")
    g.needsUpdate = true


proc render(g : MapGraphicsComponent, view : WorldView, display : DisplayWorld) =
    withView(view):
        var vi = 0
        var ii = 0

        let size = 128.0f

        let map = view.data(Map)
        for tileEnt in map.tiles:
            let tile = tileEnt[Tile]
            let img = g.imagesByKind[tile.terrainKind]
            let tc = g.texture[img]
            
            let cart = tile.position.asCartVec * size

            for q in 0 ..< 4:
                let vt = g.vao[vi+q]
                vt.vertex = cart.Vec3f + UnitSquareVertices[q] * size
                vt.color = rgba(1.0f,1.0f,1.0f,1.0f)
                vt.texCoords = tc[q]
            g.vao.addIQuad(ii,vi)
        g.vao.swap()
        g.needsUpdate = false


method update(g : MapGraphicsComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
    if g.needsUpdate:
        g.render(world.view, display)
    @[draw(g.vao, g.shader, @[g.texture], display[CameraData].camera)]