import engines
import graphics/images
import graphics/texture_block
import options
import tables
import config
import graphics/color
import prelude

type
  TilesetTile* = object
    # main tile image
    center*: ImageRef
    equalEdges*: ImageRef
    # Edges to draw when transitioning upward to a "higher" tile, i.e. water to grass
    upEdges*: Option[ImageRef]
    upEdgeVariants*: Table[string, ImageRef]
    upCorners*: Option[ImageRef]
    upCornerVariants*: Table[string, ImageRef]
    upRamp*: Option[ColorRamp]
    # Edges to draw when transitioning to a slightly "lower" tile, i.e. water to dirt
    downEdges*: Option[ImageRef]
    # Edges to draw when transition to a much "lower" tile, i.e. grass to water / void
    dropEdges*: Option[ImageRef]
    # Miscellaneous decor images to use
    decor*: seq[ImageRef]

    ramp*: ColorRamp
    # The relative "height" layer in graphical terms of this tile
    # -1 Void, 0 Water, 1 Ground, 2 Vegetation
    layer*: int



defineSimpleReadFromConfig(TilesetTile)


when isMainModule:
  import game/grids
  import graphics/canvas
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

    for k,tilesetTile in g.tiles.mpairs:
      if tilesetTile.upEdges.isSome:
        if tilesetTile.upRamp.isSome:
          let fromRamp = tilesetTile.upRamp.get
          let upImg = tilesetTile.upEdges.get.asImage

          for otherK, otherTilesetTile in g.tiles.pairs:
            if otherK != k:
              let variant = tilesetTile.upEdges.get.copy()
              variant.recolor(fromRamp, otherTilesetTile.ramp)
              tilesetTile.upEdgeVariants[otherK] = imageRef(variant)

              let cornerVariant = tilesetTile.upCorners.get.copy()
              cornerVariant.recolor(fromRamp, otherTilesetTile.ramp)
              tilesetTile.upCornerVariants[otherK] = imageRef(cornerVariant)
        else:
          for otherK, otherTilesetTile in g.tiles.pairs:
            if otherK != k:
              tilesetTile.upEdgeVariants[otherK] = imageRef(tilesetTile.upEdges.get)
              tilesetTile.upCornerVariants[otherK] = imageRef(tilesetTile.upCorners.get)



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

      proc imageAndOffset(cT: TilesetTile, aTK: string, aT: TilesetTile) : (Option[ImageRef], float32) =
        if aT.layer <= cT.layer and aT.upEdges.isNone:
          (cT.downEdges, 0.5f32)
        elif aT.layer > cT.layer and cT.upEdges.isSome:
          (some(cT.upEdgeVariants[aTK]), 0.0f32)
        else:
          (none(ImageRef), 0.0f32)

      qb.color = rgba(255,255,255,255)
      qb.origin = vec2f(0.0f,0.0f)

      let axes = [Axis.X, Axis.Y]
      for x in 0 ..< W:
        for y in countdown(H-1,0):
          let centerTK = g.map[x,y]
          let centerT = g.tiles[centerTK]
          let originPoint = positionFor(x,y,centerT.layer.float32 + 0.1f32)

          qb.dimensions = vec2f(TileSize,TileSize)
          qb.position = positionFor(x,y, centerT.layer.float32)
          qb.texture = centerT.center.asImage
          qb.drawTo(g.canvas)

          qb.dimensions = vec2f(TileHalfSize,TileHalfSize)
          for sx in 0 .. 1:
            for sy in 0 .. 1:
              let n = vec2i(sx * 2 - 1, sy * 2 - 1)
              let subTilePos = vec3f(originPoint.x + sx.float32 * TileHalfSize, originPoint.y + sy.float32 * TileHalfSize, originPoint.z)
              if x + n.x < 0 or x + n.x >= W or y + n.y < 0 or y + n.y >= H: continue

              let aTK = [ g.map[x + n.x ,y], g.map[x, y + n.y] ]
              let aT = [ g.tiles[aTK[Axis.X]], g.tiles[aTK[Axis.Y]] ]

              let adTK = g.map[x + n.x, y + n.y]
              let adT = g.tiles[adTK]

              # Exterior corner case (only deal with exterior corners for up edges at the moment)
              if aTK[Axis.X] == centerTK and aTK[Axis.Y] == centerTK and adT.layer > centerT.layer:
                if centerT.upCorners.isSome:
                  qb.texture = centerT.upCornerVariants[adTK].asImage
                  qb.position = subTilePos
                  qb.textureSubRect = rectf(sx.float32 * 0.5f,sy.float32 * 0.5f, 0.5f, 0.5f)
                  qb.drawTo(g.canvas)
              else:
                # Interior corner case (only deal with interior corners for up edges at the moment)
                if aTK[Axis.X] != centerTK and aTK[Axis.Y] != centerTK and (aT[Axis.X].layer > centerT.layer and aT[Axis.Y].layer > centerT.layer):
                  if centerT.upEdges.isSome:
                    if aTK[Axis.X] != aTK[Axis.Y]:
                      let imgDataX = g.canvas.texture.imageData(centerT.upEdgeVariants[aTK[Axis.X]].asImage)
                      let tcX = imgDataX.subRect(rectf(0.66666f32 * sx.float32, 0.666666f32 * sy.float32, 0.333333f32, 0.333333f32))
                      let imgDataY = g.canvas.texture.imageData(centerT.upEdgeVariants[aTK[Axis.Y]].asImage)
                      let tcY = imgDataY.subRect(rectf(0.66666f32 * sx.float32, 0.666666f32 * sy.float32, 0.333333f32, 0.333333f32))

                      var tb: TriBuilder = TriBuilder(color: rgba(255,255,255,255))
                      if sy == 1:
                        if sx == 1:
                          tb.points = [subTilePos, subTilePos + vec3f(TileHalfSize, 0.0f32, 0.0f32), subTilePos + vec3f(TileHalfSize, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcX[0], tcX[1], tcX[2]]
                          tb.drawTo(g.canvas)

                          tb.points = [subTilePos, subTilePos + vec3f(TileHalfSize, TileHalfSize, 0.0f32), subTilePos + vec3f(0.0f32, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcY[0], tcY[2], tcY[3]]
                          tb.drawTo(g.canvas)
                        else:
                          tb.points = [subTilePos, subTilePos + vec3f(TileHalfSize, 0.0f32, 0.0f32), subTilePos + vec3f(0.0f32, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcX[0], tcX[1], tcX[3]]
                          tb.drawTo(g.canvas)

                          tb.points = [subTilePos + vec3f(TileHalfSize, 0.0f32, 0.0f32), subTilePos + vec3f(TileHalfSize, TileHalfSize, 0.0f32), subTilePos + vec3f(0.0f32, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcY[1], tcY[2], tcY[3]]
                          tb.drawTo(g.canvas)
                      else:
                        if sx == 0:
                          tb.points = [subTilePos, subTilePos + vec3f(TileHalfSize, 0.0f32, 0.0f32), subTilePos + vec3f(TileHalfSize, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcY[0], tcY[1], tcY[2]]
                          tb.drawTo(g.canvas)

                          tb.points = [subTilePos, subTilePos + vec3f(TileHalfSize, TileHalfSize, 0.0f32), subTilePos + vec3f(0.0f32, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcX[0], tcX[2], tcX[3]]
                          tb.drawTo(g.canvas)
                        else:
                          tb.points = [subTilePos, subTilePos + vec3f(TileHalfSize, 0.0f32, 0.0f32), subTilePos + vec3f(0.0f32, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcY[0], tcY[1], tcY[3]]
                          tb.drawTo(g.canvas)

                          tb.points = [subTilePos + vec3f(TileHalfSize, 0.0f32, 0.0f32), subTilePos + vec3f(TileHalfSize, TileHalfSize, 0.0f32), subTilePos + vec3f(0.0f32, TileHalfSize, 0.0f32)]
                          tb.texCoords = [tcX[1], tcX[2], tcX[3]]
                          tb.drawTo(g.canvas)
                    else:
                      qb.texture = centerT.upEdgeVariants[aTK[Axis.Y]].asImage
                      qb.position = subTilePos
                      qb.textureSubRect = rectf(0.66666f32 * sx.float32, 0.666666f32 * sy.float32, 0.333333f32, 0.333333f32)
                      qb.drawTo(g.canvas)
                else:
                  for axis in axes:
                    if aTK[axis] != centerTK:
                      # Currently up edges take priority
                      let (img, offset) = imageAndOffset(centerT, aTK[axis], aT[axis])

                      if img.isSome:
                        qb.texture = img.get.asImage
                        qb.position = subTilePos
                        qb.position[axis] = qb.position[axis] + n[axis].float32 * TileHalfSize * offset
                        if axis == Axis.X:
                          qb.textureSubRect = rectf(sx.float * 0.6666f, 0.333333f, 0.33333f, 0.333333f)
                        else:
                          qb.textureSubRect = rectf(0.3333333f,sy.float * 0.6666f, 0.33333f, 0.333333f)
                        qb.drawTo(g.canvas)

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
          qb.position = vec3f((p.x - (W div 2).float32) * TileSize.float32 - TileHalfSize, (p.y - (H div 2).float32) * TileSize.float32 - TileHalfSize, pt.layer.float32 + 0.2f32)
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
      createCameraComponent(createPixelCamera(3, vec2f(0.0f, 0.0f)).withMoveSpeed(300.0f)),
    ],
    clearColor: rgba(0.4f,0.4f,0.4f,1.0f),
  ))

