import graphics
import worlds
import graphics/camera_component


type
   Canvas*[T,I] = object
      vao* : Vao[T, I]
      texture* : TextureBlock
      shader* : Shader
      drawOrder* : int
      renderSettings* : RenderSettings


   SimpleCanvas* = Canvas[SimpleVertex, uint16]

   QuadBuilder* = object
      position* : Vec3f
      dimensions* : Vec2f
      texture* : ImageLike
      color* : RGBA
      origin* : Vec2f

proc createCanvas*[T,I](shaderName : string, textureDimensions : int = 1024) : Canvas[T, I] =
   Canvas[T, I](
      vao : newVao[T,I](),
      texture : newTextureBlock(textureDimensions),
      shader : initShader(shaderName),
   )

proc createSimpleCanvas*(shaderName : string, textureDimensions : int = 1024) : SimpleCanvas = createCanvas[SimpleVertex,uint16](shaderName,textureDimensions)

proc drawTo*(qb : QuadBuilder, cv : var SimpleCanvas) =
   let tc = cv.texture[qb.texture]
   var vi = cv.vao.vi
   var ii = cv.vao.ii
   for i in 0 ..< 4:
      let vt = cv.vao[vi+i]
      vt.vertex.x = qb.position.x + (UnitSquareVertices[i].x - qb.origin.x) * qb.dimensions.x
      vt.vertex.y = qb.position.y + (UnitSquareVertices[i].y - qb.origin.y) * qb.dimensions.y
      vt.vertex.z = qb.position.z

      vt.color = qb.color
      vt.texCoords = tc[i]

   cv.vao.addIQuad(ii,vi)

proc drawCommand*(canvas : Canvas, display : DisplayWorld) : DrawCommand =
   draw(canvas.vao, canvas.shader, @[canvas.texture], display[CameraData].camera, canvas.drawOrder, canvas.renderSettings)

proc centered*(qb : var QuadBuilder) : var QuadBuilder {.discardable.} =
   qb.origin = vec2f(0.5,0.5)
   qb

proc swap*(canvas : var Canvas) =
   canvas.vao.swap()