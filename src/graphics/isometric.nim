import glm
import graphics/images
import graphics/color
import graphics/canvas
import graphics/texture_block
import graphics/core

type
  IsometricTileRendering* = object
    tileWidth: int
    tileHeight: int
    halfTileWidth: int
    halfTileHeight: int

  IsometricTileQuadBuilder* = object
    itr: IsometricTileRendering
    groundOffset*: int
    position*: Vec3f
    dimensions*: Vec2f
    texture*: ImageLike
    color*: RGBA
    origin*: Vec2f

proc isometricTileRendering*(tileWidth: int) : IsometricTileRendering =
  let tileHeight = tileWidth div 2
  IsometricTileRendering(
    tileWidth: tileWidth,
    tileHeight: tileHeight,
    halfTileWidth: tileWidth div 2,
    halfTileHeight: tileHeight div 2
  )

proc quadBuilder*(itr: IsometricTileRendering): IsometricTileQuadBuilder =
  IsometricTileQuadBuilder(itr: itr, color: White)

func toPixelPos*(r: IsometricTileRendering, v: Vec2i): Vec2f =
  vec2f(v.x.float * r.halfTileWidth.float - v.y.float * r.halfTileWidth.float,
          v.y.float * r.halfTileHeight.float + v.x.float * r.halfTileHeight.float)

func toPixelPos*(r: IsometricTileRendering, v: Vec3i): Vec3f =
  vec3f(v.x.float * r.halfTileWidth.float - v.y.float * r.halfTileWidth.float,
          v.y.float * r.halfTileHeight.float + v.x.float * r.halfTileHeight.float,
          v.z.float)

func toPixelPos*(r: IsometricTileRendering, v: Vec3f): Vec3f =
  vec3f(  v.x * r.halfTileWidth.float  - v.y * r.halfTileWidth.float,
          v.y * r.halfTileHeight.float + v.x * r.halfTileHeight.float,
          v.z.float)


func fromPixelPos*(r: IsometricTileRendering, v: Vec2f): Vec2i =
  let x = ((v.x / r.tileWidth.float) + (v.y / r.tileHeight.float))
  let y = ((v.y / r.tileHeight.float) - (v.x / r.tileWidth.float))
  vec2i(x.floor.int32, y.floor.int32)


proc `isoTilePos=`*(iqb: var IsometricTileQuadBuilder, v: Vec3f) =
  iqb.position = iqb.itr.toPixelPos(v)


proc drawTo*(qb : IsometricTileQuadBuilder, cv : var SimpleCanvas) =
   let tc = cv.texture[qb.texture.asImage]
   var vi = cv.vao.vi
   var ii = cv.vao.ii
   for i in 0 ..< 4:
      let vt = cv.vao[vi+i]
      vt.vertex.x = qb.position.x + (UnitSquareVertices[i].x - qb.origin.x) * qb.dimensions.x
      vt.vertex.y = qb.position.y + (UnitSquareVertices[i].y - qb.origin.y) * qb.dimensions.y - qb.groundOffset.float32
      vt.vertex.z = qb.position.z - qb.position.y * 0.01

      vt.color = qb.color
      vt.texCoords = tc[i]

   cv.vao.addIQuad(ii,vi)



when isMainModule:
  import graphics_testing
  import engines
  import resources

  proc testRender(display: DisplayWorld, canvas: var SimpleCanvas) =
    let itr = isometricTileRendering(144)
    var qb = itr.quadBuilder

    qb.origin = vec2f(0.5f, 0.0f)

    qb.isoTilePos = vec3f(0.0f,0.0f,0.0f)
    qb.texture = imageLike(image("vn/rooms/reference_floor_hi_res.png"))
    qb.color = rgba(1.0,1.0,1.0,1.0)
    qb.dimensions = vec2f(144.0f,144.0f)
    qb.groundOffset = 15
    qb.drawTo(canvas)

    qb.isoTilePos = vec3f(-1.0f,0.0f,0.0f)
    qb.drawTo(canvas)

    qb.isoTilePos = vec3f(0.0f,-1.0f,0.0f)
    qb.drawTo(canvas)

    qb.isoTilePos = vec3f(0.33333f, 0.33333f, 0.0f)
    qb.dimensions = vec2f(48.0f, 48.0f)
    qb.groundOffset = 0
    qb.texture = imageLike(image("vn/machines/test_machine_hi_res.png"))
    qb.drawTo(canvas)

    qb.isoTilePos = vec3f(4.0/9.0, 0.0/9.0, 0.0f)
    qb.dimensions = vec2f(16.0f, 16.0f)
    qb.groundOffset = 0
    qb.texture = imageLike(image("vn/machines/test_machine_16.png"))
    qb.drawTo(canvas)

    qb.isoTilePos = vec3f(3.0/9.0, 0.0/9.0, 0.0f)
    qb.dimensions = vec2f(16.0f, 16.0f)
    qb.groundOffset = 0
    qb.texture = imageLike(image("vn/machines/belt_ne_16.png"))
    qb.drawTo(canvas)

    qb.isoTilePos = vec3f(0.0f, 0.3333f, 0.0f)
    qb.dimensions = vec2f(48.0f, 48.0f)
    qb.texture = imageLike(image("vn/machines/belt_ne.png"))
    qb.drawTo(canvas)

    qb.isoTilePos = vec3f(-0.333333f, 0.3333f, 0.0f)
    qb.drawTo(canvas)



  graphicsTestingMain(testRender, createPixelCamera(5))