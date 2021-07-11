import prelude
import glm
import graphics/canvas
import graphics/images
import graphics/color
import graphics
import nimgl/opengl

export glm

const TileScale* = 1.5f

const TileWidth* = 32.0f * TileScale
const TileHeight* = 16.0f * TileScale

const HTW* = TileWidth / 2.0f - 2.0f * TileScale
const HTH* = TileHeight / 2.0f - 1.0f * TileScale


proc toPixelPos*(v : Vec2i) : Vec2f =
  vec2f(v.x.float * HTW - v.y.float * HTW, v.y.float * HTH + v.x.float * HTH)

proc fromPixelPos*(v: Vec2f) : Vec2i =
  let x = (v.x / HTW + v.y / HTH) / 2.0f
  let y = (v.y / HTH - (v.x / HTW)) / 2.0f
  vec2i(x.int, y.int)


proc createITBCanvas*(shaderName: string) : SimpleCanvas =
  result = createSimpleCanvas(shaderName)
  # result.renderSettings.depthTestEnabled = true
  # result.renderSettings.depthFunc = GL_LEQUAL

type ITBQuad* = object
  position* : Vec2f
  layer*: int
  dimensions* : Vec2f
  texture* : ImageRef
  color* : RGBA
  origin* : Vec2f



proc drawTo*(qb : ITBQuad, cv : var SimpleCanvas) =
   let tc = cv.texture[qb.texture]
   var vi = cv.vao.vi
   var ii = cv.vao.ii
   for i in 0 ..< 4:
      let vt = cv.vao[vi+i]
      vt.vertex.x = qb.position.x + (UnitSquareVertices[i].x - qb.origin.x) * qb.dimensions.x
      vt.vertex.y = qb.position.y + (UnitSquareVertices[i].y - qb.origin.y) * qb.dimensions.y
      # vt.vertex.z = qb.layer.float -qb.position.y * 0.01

      vt.color = qb.color
      vt.texCoords = tc[i]

   cv.vao.addIQuad(ii,vi)

proc centered*(qb : var ITBQuad) : var ITBQuad {.discardable.} =
  qb.origin = vec2f(0.5,0.5)
  qb