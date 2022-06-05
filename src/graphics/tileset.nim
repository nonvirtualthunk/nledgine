import engines
import graphics/images
import graphics/texture_block
import options
import tables
import config
import graphics/color
import prelude
import graphics/canvas
import glm
import arxmath


import resources

type
  TilesetTile* = object
    # main tile image
    center*: ImageRef
    equalEdges*: ImageRef
    # Edges to draw when transitioning upward to a "higher" tile, i.e. water to grass
    upEdges*: Option[ImageRef]
    upEdgeVariants*: Table[int, ImageRef]
    upCorners*: Option[ImageRef]
    upCornerVariants*: Table[int, ImageRef]
    upRamp*: Option[ColorRamp]
    # Edges to draw when transitioning to a slightly "lower" tile, i.e. water to dirt
    downEdges*: Option[ImageRef]
    downCorners*: Option[ImageRef]
    # Edges to draw when transition to a much "lower" tile, i.e. grass to water / void
    dropEdges*: Option[ImageRef]
    # Miscellaneous decor images to use
    decor*: seq[ImageRef]

    ramp*: ColorRamp
    # The relative "height" layer in graphical terms of this tile
    # -1 Void, 0 Water, 1 Ground, 2 Vegetation
    layer*: int

  Tileset* = object
    tiles*: seq[ref TilesetTile]

  TilesetRenderer*[V,I] = object
    tileSize: float32
    tileset: Tileset
    canvas: Canvas[V,I]



defineSimpleReadFromConfig(TilesetTile)


proc createTilesetRenderer*[V,I](tileSize: float32, tileset: Tileset, canvas: Canvas[V,I]) : TilesetRenderer[V,I] =
  TilesetRenderer[V,I](
    tileSize: tileSize,
    tileset: tileset,
    canvas: canvas
  )


proc createTileset*(tiles: seq[ref TilesetTile]) : Tileset =
  result = Tileset(tiles: tiles)
  for i in 0 ..< tiles.len:
    if tiles[i] == nil:
      continue
    let tilesetTile = tiles[i]
    if tilesetTile.upEdges.isSome:
      if tilesetTile.upRamp.isSome:
        let fromRamp = tilesetTile.upRamp.get
        let upImg = tilesetTile.upEdges.get.asImage

        for j in 0 ..< tiles.len:
          let otherTilesetTile = tiles[j]
          if otherTilesetTile == nil: continue
          if i != j:
            let variant = tilesetTile.upEdges.get.copy()
            variant.recolor(fromRamp, otherTilesetTile.ramp)
            tilesetTile.upEdgeVariants[j] = imageRef(variant)

            let cornerVariant = tilesetTile.upCorners.get.copy()
            cornerVariant.recolor(fromRamp, otherTilesetTile.ramp)
            tilesetTile.upCornerVariants[j] = imageRef(cornerVariant)
      else:
        for j in 0 ..< tiles.len:
          let otherTilesetTile = tiles[j]
          if otherTilesetTile == nil: continue
          if i != j:
            tilesetTile.upEdgeVariants[j] = imageRef(tilesetTile.upEdges.get)
            tilesetTile.upCornerVariants[j] = imageRef(tilesetTile.upCorners.get)


# const BottomLeftToTopRightDiagonal = [[vec3f(0,0,0), vec3f(1,1,0), vec3f(0,1,0)], [vec3f(0,0,0), vec3f(1,0,0), vec3f(1,1,0)]]
# const BottomRightToTopLeftDiagonal = [[vec3f(1,0,0), vec3f(1,1,0), vec3f(0,1,0)], [vec3f(0,0,0), vec3f(1,0,0), vec3f(0,1,0)]]
# const AllDiagonals = [BottomLeftToTopRightDiagonal, BottomRightToTopLeftDiagonal]

# The usual unitSquare points
const CornerPoints = [vec3f(0,0,0), vec3f(1,0,0), vec3f(1, 1, 0), vec3f(0, 1, 0)]

const XTK = 0 # aligns with Axis.X.ord
const YTK = 1 # aligns with Axis.Y.ord
const CenterI = 2
const DTK = 3
# [x-adjacent, y-adjacent, center, diagonal] for tks and ts
proc renderTileEdges*[V,I](r: var TilesetRenderer[V,I], qb: var QuadBuilder, tb: var TriBuilder, tks: array[4, int], x: int, y: int, sx: int, sy: int) =
  let halfSize = r.tileSize * 0.5f32
  qb.dimensions = vec2f(halfSize, halfSize)

  # if these are all the same there is nothing to do
  if tks[0] == tks[1] and tks[0] == tks[2] and tks[0] == tks[3]:
    return

  let centerT = r.tileset.tiles[tks[CenterI]]
  let centerTK = tks[CenterI]
  let subTilePos = vec3f(x.float32 * r.tileSize + sx.float32 * halfSize,
                        y.float32 * r.tileSize + sy.float32 * halfSize,
                        centerT.layer.float32 + 0.1f32)
  let diagonalT = r.tileset.tiles[tks[DTK]]
  let xT = r.tileset.tiles[tks[XTK]]
  let yT = r.tileset.tiles[tks[YTK]]
  # Exterior corner case (only deal with exterior corners for up edges at the moment)
  if tks[XTK] == centerTK and tks[YTK] == centerTK and diagonalT.layer > centerT.layer:
    if centerT.upCorners.isSome:
      qb.texture = centerT.upCornerVariants[tks[DTK]].asImage
      qb.position = subTilePos
      qb.textureSubRect = rectf(sx.float32 * 0.5f,sy.float32 * 0.5f, 0.5f, 0.5f)
      qb.drawTo(r.canvas)
  else:
    # Interior corner case (only deal with interior corners for up edges at the moment)
    if tks[XTK] != centerTK and tks[YTK] != centerTK and (xT.layer > centerT.layer and yT.layer > centerT.layer):
      if centerT.upEdges.isSome:
        if tks[XTK] != tks[YTK]:
          let imgDataX = r.canvas.texture.imageData(centerT.upEdgeVariants[tks[XTK]].asImage)
          let tcX = imgDataX.subRect(rectf(0.66666f32 * sx.float32, 0.666666f32 * sy.float32, 0.333333f32, 0.333333f32))
          let imgDataY = r.canvas.texture.imageData(centerT.upEdgeVariants[tks[YTK]].asImage)
          let tcY = imgDataY.subRect(rectf(0.66666f32 * sx.float32, 0.666666f32 * sy.float32, 0.333333f32, 0.333333f32))
          let tcs = [tcX, tcY]

          let rotOffset = (sx - sy).abs
          let tcA = (sy + 1) mod 2
          let tcB = sy
          tb.points = [subTilePos + CornerPoints[0] * halfSize, subTilePos + CornerPoints[1] * halfSize, subTilePos + CornerPoints[2 + rotOffset] * halfSize]
          tb.texCoords = [tcs[tcA][0], tcs[tcA][1], tcs[tcA][2 + rotOffset]]
          tb.drawTo(r.canvas)

          tb.points = [subTilePos + CornerPoints[2] * halfSize, subTilePos + CornerPoints[3] * halfSize, subTilePos + CornerPoints[0 + rotOffset] * halfSize]
          tb.texCoords = [tcs[tcB][2], tcs[tcB][3], tcs[tcB][0 + rotOffset]]
          tb.drawTo(r.canvas)
        else:
          qb.texture = centerT.upEdgeVariants[tks[YTK]].asImage
          qb.position = subTilePos
          qb.textureSubRect = rectf(0.66666f32 * sx.float32, 0.666666f32 * sy.float32, 0.333333f32, 0.333333f32)
          qb.drawTo(r.canvas)
    else:
      let n = vec2i(sx * 2 - 1, sy * 2 - 1)
      if centerT.downEdges.isSome:
        if tks[XTK] != centerTK and tks[YTK] != centerTK and tks[DTK] != centerTK and diagonalT.layer < centerT.layer:
          qb.texture = centerT.downEdges.get.asImage
          qb.position = subTilePos + vec3f(n.x, n.y, 0) * halfSize * 0.5f
          qb.textureSubRect = rectf(sx.float32 * 0.66666f, sy.float32 * 0.66666f, 0.333333f, 0.333333f)
          qb.drawTo(r.canvas)
        if (sx == 0 and yT.layer < centerT.layer) or (sx == 1 and yT.layer < centerT.layer and diagonalT.layer < centerT.layer and xT.layer == centerT.layer):
          qb.texture = centerT.downEdges.get.asImage
          qb.position = subTilePos + vec3f(halfSize * 0.5, halfSize * n.y.float * 0.5, 0.0)
          qb.textureSubRect = rectf(0.3333333f,sy.float * 0.6666f, 0.33333f, 0.333333f)
          qb.drawTo(r.canvas)
        if (sy == 0 and xT.layer < centerT.layer) or (sy == 1 and xT.layer < centerT.layer and diagonalT.layer < centerT.layer and yT.layer == centerT.layer):
          qb.texture = centerT.downEdges.get.asImage
          qb.position = subTilePos + vec3f(halfSize * n.x.float * 0.5, halfSize * 0.5, 0.0)
          qb.textureSubRect = rectf(sx.float * 0.6666f, 0.3333333f, 0.33333f, 0.333333f)
          qb.drawTo(r.canvas)
        if tks[XTK] == tks[YTK] and tks[XTK] == centerTK and centerTK != tks[DTK] and diagonalT.layer < centerT.layer:
          if centerT.downCorners.isSome:
            # TODO, actual corners
            discard
          else:
            # let vtData = r.canvas.texture.imageData(image("survival/graphics/tiles/stone_wall2.png"))
            # let vtc = vtData.subRect(rectf(0.0f,0.0f,1.0f,1.0f))
            let downData = r.canvas.texture.imageData(centerT.downEdges.get.asImage)
            let xTC = downData.subRect(rectf(sx.float32 * 0.666666f, 0.3333333f, 0.333333f, 0.3333333f))
            let yTC = downData.subRect(rectf(0.3333333f, sy.float32 * 0.666666f, 0.333333f, 0.3333333f))
            let tcs = [xTC, yTC]
            let tcA = sy
            let tcB = (sy + 1) mod 2

            let sstp = subTilePos + vec3f(n.x.float * halfSize * 0.5, n.y.float * halfSize * 0.5, 0.0)
            let rotOffset = (sx - sy).abs

            qb.texture = centerT.downEdges.get.asImage
            qb.position = sstp
            qb.textureSubRect = rectf(0.3333333f, sy.float32 * 0.666666f, 0.333333f, 0.3333333f)
            qb.drawTo(r.canvas)

            tb.points = [sstp + CornerPoints[0] * halfSize, sstp + CornerPoints[1] * halfSize, sstp + CornerPoints[2 + rotOffset] * halfSize]
            tb.texCoords = [tcs[tcA][0], tcs[tcA][1], tcs[tcA][2 + rotOffset]]
            tb.drawTo(r.canvas)

            tb.points = [sstp + CornerPoints[2] * halfSize, sstp + CornerPoints[3] * halfSize, sstp + CornerPoints[0 + rotOffset] * halfSize]
            tb.texCoords = [tcs[tcB][2], tcs[tcB][3], tcs[tcB][0 + rotOffset]]
            tb.drawTo(r.canvas)


      for axis in axes2d():
        if tks[axis.ord] != centerTK:
          # Currently up edges take priority
          let (img, offset) = if r.tileset.tiles[tks[axis.ord]].layer > centerT.layer and centerT.upEdges.isSome:
                                (some(centerT.upEdgeVariants[tks[axis.ord]]), 0.0f32)
                              else:
                                (none(ImageRef), 0.0f32)
          if img.isSome:
            qb.texture = img.get.asImage
            qb.position = subTilePos
            qb.position[axis] = qb.position[axis] + n[axis].float32 * halfSize * offset
            if axis == Axis.X:
              qb.textureSubRect = rectf(sx.float * 0.6666f, 0.333333f, 0.33333f, 0.333333f)
            else:
              qb.textureSubRect = rectf(0.3333333f,sy.float * 0.6666f, 0.33333f, 0.333333f)
            qb.drawTo(r.canvas)



when isMainModule:
  import game/grids
  import resources
  import glm
  import graphics/camera_component
  import graphics/cameras
  import application
  import main
  import noto
  import engines/debug_components
  import arxmath
  import nimgl/[glfw, opengl]
  import perlin
  import core/poisson_disk

  const W = 30
  const H = 30

  type
    TilesetGraphicsComponent* = ref object of GraphicsComponent
      tiles*: Table[string, TilesetTile]
      canvas*: SimpleCanvas
      updated*: bool
      map*: FiniteGrid2D[W,H,string]



  method initialize(g: TilesetGraphicsComponent, world: LiveWorld, displayWorld: DisplayWorld) =
    config("demo/sample_tileset.sml").readInto(g.tiles)
    g.canvas = createSimpleCanvas("shaders/simple")
    g.canvas.renderSettings.depthTestEnabled = true
    g.canvas.renderSettings.depthFunc = GL_LEQUAL



    let noise = newNoise()

    for x in 0 ..< W:
      for y in 0 ..< H:
        let dx = x - W div 2
        let dy = y - H div 2
        let d = (dx*dx + dy*dy).float32 / ((W div 2)*(W div 2)+(H div 2)*(H div 2)).float32


        let h = noise.pureSimplex(x.float32 * 0.05, y.float32 * 0.05) - d * 0.5f
        if h < 0.25f:
          g.map[x,y] = "Water"
        else:
          let n = noise.pureSimplex(x.float32 * 0.035 + 1234.0, y.float32 * 0.035 + 1234.0)
          if n < 0.2f:
            g.map[x,y] = "Stone"
          elif n < 0.3f:
            g.map[x,y] = "Dirt"
          else:
            g.map[x,y] = "Grass"

  method update(g: TilesetGraphicsComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
    if not g.updated:
      let poisson = generatePoissonDiskSample(W, H)

      const TileSize = 32.0f32
      const TileHalfSize = 16.0f32

      proc positionFor(x: int, y: int,z : float32) : Vec3f =
        vec3f(TileSize * (x-W div 2).float32 - TileHalfSize, TileSize * (y-H div 2).float32 - TileHalfSize, z)

      var qb : QuadBuilder
      var tb : TriBuilder = TriBuilder(color: rgba(255,255,255,255))

      # proc imageAndOffset(cT: TilesetTile, aTK: string, aT: TilesetTile) : (Option[ImageRef], float32) =
      #   if aT.layer <= cT.layer and aT.upEdges.isNone:
      #     (cT.downEdges, 0.5f32)
      #   elif aT.layer > cT.layer and cT.upEdges.isSome:
      #     (some(cT.upEdgeVariants[aTK]), 0.0f32)
      #   else:
      #     (none(ImageRef), 0.0f32)

      qb.color = rgba(255,255,255,255)
      qb.origin = vec2f(0.0f,0.0f)

      var tilesetSeq : seq[ref TilesetTile]
      var tilesetKeys: Table[string, int]
      for k,v in g.tiles:
        tilesetKeys[k] = tilesetSeq.len
        tilesetSeq.add(new TilesetTile)
        tilesetSeq[^1][] = v


      let tileset = createTileset(tilesetSeq)

      var tks : array[4, int]

      var tilesetRenderer = TilesetRenderer(tileSize: TileSize, tileset: tileset, canvas: g.canvas)

      for x in 0 ..< W:
        for y in countdown(H-1,0):
          let centerTK = g.map[x,y]
          let centerT = g.tiles[centerTK]

          qb.dimensions = vec2f(TileSize,TileSize)
          qb.position = vec3f(x.float32 * TileSize, y.float32 * TileSize, centerT.layer.float32)
          qb.texture = centerT.center.asImage
          qb.drawTo(g.canvas)

          for sx in 0 .. 1:
            for sy in 0 .. 1:
              let n = vec2i(sx * 2 - 1, sy * 2 - 1)
              if x + n.x < 0 or x + n.x >= W or y + n.y < 0 or y + n.y >= H: continue

              tks[0] = tilesetKeys[g.map[x + n.x, y]]
              tks[1] = tilesetKeys[g.map[x, y + n.y]]
              tks[2] = tilesetKeys[g.map[x, y]]
              tks[3] = tilesetKeys[g.map[x + n.x, y + n.y]]

              renderTileEdges(tilesetRenderer, qb, tb, tks, x, y, sx, sy)

      for i in countup(0, poisson.points.len-1, 3):
        let p = poisson.points[i]
        let ptk = g.map[p.x.int, p.y.int]
        var allSame = true
        for dx in countup(-1,1,2):
          for dy in countup(-1,1,2):
            let ax = (p.x + dx.float32 * 0.6f32)
            let ay = (p.y + dy.float32 * 0.6f32)
            if ax.int >= 0 and ay.int >= 0 and ax.int < W and ay.int < H:
              if g.map[ax.int, ay.int] != ptk:
                allSame = false
                break

        if allSame:
          let pt = g.tiles[ptk]
          let decor = pt.decor[(i div 3) mod pt.decor.len]
          qb.position = vec3f((p.x) * TileSize.float32, (p.y) * TileSize.float32, pt.layer.float32 + 0.2f32)
          qb.texture = decor.asImage
          qb.textureSubRect = rectf(0.0f32,0.0f32,0.0f32,0.0f32)
          qb.color = rgba(255,255,255,255)
          qb.dimensions = vec2f(TileHalfSize, TileHalfSize)
          qb.drawTo(g.canvas)


      # for x in 0 ..< W:
      #   for y in countdown(H-1,0):
      #     for sx in 0 .. 1:
      #       for sy in 0 .. 1:
      #         let dx = sx * 2 - 1
      #         let dy = sy * 2 - 1
      #
      #         if x + dx >= 0 and x + dx < W and y + dy >= 0 and y + dy < H:
      #           let mtile = g.tiles[ g.map[x,y] ]
      #           let ytileKey = g.map[x,y + dy]
      #           let ytile = g.tiles[ ytileKey ]
      #           let xtileKey = g.map[x + dx, y]
      #           let xtile = g.tiles[ xtileKey ]
      #           let dtile = g.tiles[ g.map[x + dx, y + dy] ]
      #
      #           if mtile == ytile and mtile == xtile and mtile == dtile:
      #             discard
      #           else:
      #             if mtile != xtile and mtile != ytile and mtile.layer < xtile.layer and mtile.layer < ytile.layer:
      #               let img = mtile.upEdges
      #               let offset = -1
      #
      #               if img.isSome:
      #                 qb.position = vec3f(32.0f * (x-W div 2).float + sx.float * 32.0f - 8.0f32 + (dx * offset).float32 * 8.0f32 - TileHalfSize,
      #                                     32.0f * (y-H div 2).float + sy.float * 16.0f - TileHalfSize,
      #                                     mtile.layer.float32 + 0.1f32)
      #                 qb.dimensions = vec2f(16.0f, 16.0f)
      #                 qb.textureSubRect = rectf(sx.float32 * 0.666666f,sy.float32 * 0.66666f, 0.33333f, 0.333333f)
      #                 qb.texture = img.get.asImage
      #
      #                 qb.drawTo(g.canvas)
      #             elif mtile == xtile and mtile == ytile and mtile != dtile and mtile.layer < dtile.layer:
      #               let img = mtile.upCorners
      #               let offset = -1
      #
      #               if img.isSome:
      #                 qb.position = vec3f(32.0f * (x-W div 2).float + sx.float * 16.0f - TileHalfSize,
      #                                     32.0f * (y-H div 2).float + sy.float * 16.0f - TileHalfSize,
      #                                     mtile.layer.float32 + 0.1f32)
      #                 qb.dimensions = vec2f(16.0f, 16.0f)
      #                 qb.textureSubRect = rectf(sx.float32 * 0.5f,sy.float32 * 0.5f, 0.5f, 0.5f)
      #                 qb.texture = img.get.asImage
      #
      #                 qb.drawTo(g.canvas)
      #             else:
      #               if mtile != xtile:
      #                 let (img, offset) = if mtile.layer - xtile.layer == 1 and mtile.downEdges.isSome:
      #                   (mtile.downEdges, 0)
      #                   # none(ImageRef)
      #                 elif mtile.layer < xtile.layer and mtile.upEdges.isSome:
      #                   (some(mtile.upEdgeVariants[xtileKey]), -1)
      #                   # (mtile.upEdges, -1)
      #                 else:
      #                   (none(ImageRef), 0)
      #
      #                 if img.isSome:
      #                   qb.position = vec3f(32.0f * (x-W div 2).float + sx.float * 32.0f - 8.0f32 + (dx * offset).float32 * 8.0f32 - TileHalfSize,
      #                                       32.0f * (y-H div 2).float + sy.float * 16.0f - TileHalfSize,
      #                                       mtile.layer.float32 + 0.1f32)
      #                   qb.dimensions = vec2f(16.0f, 16.0f)
      #                   qb.textureSubRect = rectf(sx.float * 0.6666f, 0.333333f, 0.33333f, 0.333333f)
      #                   qb.texture = img.get.asImage
      #
      #                   qb.drawTo(g.canvas)
      #               if mtile != ytile:
      #                 let (img, offset) = if mtile.layer - ytile.layer == 1 and mtile.downEdges.isSome:
      #                   (mtile.downEdges, 0)
      #                   # none(ImageRef)
      #                 elif mtile.layer < ytile.layer and mtile.upEdges.isSome:
      #                   (mtile.upEdges, -1)
      #                 else:
      #                   (none(ImageRef), 0)
      #
      #                 if img.isSome:
      #                   qb.position = vec3f(32.0f * (x-W div 2).float + sx.float * 16.0f - TileHalfSize,
      #                                       32.0f * (y-H div 2).float + sy.float * 32.0f - 8.0f + (dy * offset).float32 * 8.0f32 - TileHalfSize,
      #                                       mtile.layer.float32 + 0.1f32)
      #                   qb.dimensions = vec2f(16.0f, 16.0f)
      #                   qb.textureSubRect = rectf(0.3333333f,sy.float * 0.6666f, 0.33333f, 0.333333f)
      #                   qb.texture = img.get.asImage
      #
      #                   qb.drawTo(g.canvas)

      g.updated = true
      g.canvas.swap()
      @[g.canvas.drawCommand(display)]
    else:
      @[]


  main(GameSetup(
    windowSize: vec2i(1400, 1000),
    resizeable: false,
    windowTitle: "Tileset",
    liveGameComponents: @[
      (LiveGameComponent) BasicLiveWorldDebugComponent()
    ],
    graphicsComponents: @[
      TilesetGraphicsComponent(),
      createCameraComponent(createPixelCamera(3, vec2f(-(W/2) * 32.0f32, -(H/2) * 32.0f32)).withMoveSpeed(300.0f)),
    ],
    clearColor: rgba(0.4f,0.4f,0.4f,1.0f),
  ))

