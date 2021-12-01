import glm
import graphics/images
import graphics/color
import graphics/canvas
import graphics/texture_block
import graphics/core
import options
import prelude

type
  IsometricTileRendering* = object
    tileWidth: int
    tileHeight: int
    tileHeightf: float32
    halfTileWidth: int
    halfTileWidthf: float32
    halfTileHeight: int
    halfTileHeightf: float32

  IsometricTileQuadBuilder* = object
    itr: IsometricTileRendering
    groundOffset*: int
    position*: Vec3f
    dimensions*: Vec2f
    texture*: ImageLike
    color*: RGBA
    origin*: Vec2f
    texCoords*: Option[ref array[4,Vec2f]]

proc isometricTileRendering*(tileWidth: int) : IsometricTileRendering =
  let tileHeight = tileWidth div 2
  IsometricTileRendering(
    tileWidth: tileWidth,
    tileHeight: tileHeight,
    tileHeightf: tileHeight.float32,
    halfTileWidth: tileWidth div 2,
    halfTileWidthf: (tileWidth div 2).float32,
    halfTileHeight: tileHeight div 2,
    halfTileHeightf: (tileHeight div 2).float32,
  )

proc quadBuilder*(itr: IsometricTileRendering): IsometricTileQuadBuilder =
  IsometricTileQuadBuilder(itr: itr, color: White)

func toPixelPos*(r: IsometricTileRendering, v: Vec2i): Vec2f =
  vec2f(v.x.float32 * r.halfTileWidthf - v.y.float32 * r.halfTileWidthf,
          v.y.float32 * r.halfTileHeightf + v.x.float32 * r.halfTileHeightf)

func toPixelPos*(r: IsometricTileRendering, v: Vec3i): Vec3f =
  vec3f(v.x.float32 * r.halfTileWidthf - v.y.float32 * r.halfTileWidthf,
          v.y.float32 * r.halfTileHeightf + v.x.float32 * r.halfTileHeightf + v.z.float32 * r.tileHeightf,
          0.0f32)

func toPixelPos*(r: IsometricTileRendering, v: Vec3f): Vec3f =
  vec3f(  v.x * r.halfTileWidthf  - v.y * r.halfTileWidthf,
          v.y * r.halfTileHeightf + v.x * r.halfTileHeightf + v.z * r.tileHeightf,
          0.0f32)

func toPixelPos*(r: IsometricTileRendering, x,y,z: float32): Vec3f =
  vec3f(  x * r.halfTileWidthf  - y * r.halfTileWidthf,
          y * r.halfTileHeightf + x * r.halfTileHeightf + z * r.tileHeightf,
          0.0f32)

func toPixelPos*(r: IsometricTileRendering, x,y,z: int): Vec3f =
  vec3f(  x.float32 * r.halfTileWidthf  - y.float32 * r.halfTileWidthf,
          y.float32 * r.halfTileHeightf + x.float32 * r.halfTileHeightf + z.float32 * r.tileHeightf,
          0.0f32)

func fromPixelPos*(r: IsometricTileRendering, v: Vec2f): Vec2i =
  let x = ((v.x / r.tileWidth.float) + (v.y / r.tileHeight.float))
  let y = ((v.y / r.tileHeight.float) - (v.x / r.tileWidth.float))
  vec2i(x.floor.int32, y.floor.int32)


proc `isoTilePos=`*(iqb: var IsometricTileQuadBuilder, v: Vec3f) =
  iqb.position = iqb.itr.toPixelPos(v)


proc drawTo*(qb : IsometricTileQuadBuilder, cv : var SimpleCanvas) =
  let tc = if qb.texCoords.isSome:
    qb.texCoords.get
  else:
    cv.texture[qb.texture.asImage]

  var vi = cv.vao.vi
  var ii = cv.vao.ii

  let ox = qb.position.x - qb.origin.x * qb.dimensions.x
  let oy = qb.position.y - qb.origin.y * qb.dimensions.y - qb.groundOffset.float32
  let oz = qb.position.z - qb.position.y * 0.01


  let vt0 = cv.vao.reserve(vi, 4)
  vt0.vertex.x = ox
  vt0.vertex.y = oy
  vt0.vertex.z = oz
  vt0.color = qb.color
  vt0.texCoords = tc[0]

  let vt1 = vt0 + 1
  vt1.vertex.x = ox + qb.dimensions.x
  vt1.vertex.y = oy
  vt1.vertex.z = oz
  vt1.color = qb.color
  vt1.texCoords = tc[1]

  let vt2 = vt0 + 2
  vt2.vertex.x = ox + qb.dimensions.x
  vt2.vertex.y = oy + qb.dimensions.y
  vt2.vertex.z = oz
  vt2.color = qb.color
  vt2.texCoords = tc[2]

  let vt3 = vt0 + 3
  vt3.vertex.x = ox
  vt3.vertex.y = oy + qb.dimensions.y
  vt3.vertex.z = oz
  vt3.color = qb.color
  vt3.texCoords = tc[3]

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