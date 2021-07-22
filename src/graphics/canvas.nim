import graphics
import worlds
import graphics/camera_component
import arxmath


type
  Canvas*[T,I] = object
    name*: string
    vao* : Vao[T, I]
    texture* : TextureBlock
    shader* : Shader
    drawOrder* : int
    renderSettings* : RenderSettings
    # If set, the camera in use to draw this will be updated even if no new draw command is issued. If false, the only
    # time the effective camera will change is when `draw()` is called. Defaults to true
    syncCamera*: bool


  SimpleCanvas* = Canvas[SimpleVertex, uint16]

  QuadBuilder* = object
    position* : Vec3f
    dimensions* : Vec2f
    texture* : Image
    color* : RGBA
    origin* : Vec2f
    textureSubRect*: Rectf

proc createCanvas*[T,I](shaderName : string, textureDimensions : int = 1024, name: string = "unnamed canvas") : Canvas[T, I] =
  Canvas[T, I](
    name: name,
    vao : newVao[T,I](),
    texture : newTextureBlock(textureDimensions),
    shader : initShader(shaderName),
    syncCamera: true
  )

proc createSimpleCanvas*(shaderName : string, textureDimensions : int = 1024, name: string = "unnamed canvas") : SimpleCanvas =
  createCanvas[SimpleVertex,uint16](shaderName,textureDimensions, name)

proc drawTo*[I](qb : QuadBuilder, cv : var Canvas[SimpleVertex,I]) =
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
    
  if qb.textureSubRect.width > 0.0f:
    let imgData = cv.texture.imageData(qb.texture)
    for q in 0 ..< 4:
      cv.vao[vi+q].texCoords = imgData.texPosition + (qb.textureSubRect.position + qb.textureSubRect.dimensions * UnitSquareVertices2d[q]) * imgData.texDimensions

  cv.vao.addIQuad(ii,vi)

proc drawCommand*(canvas : Canvas, display : DisplayWorld) : DrawCommand =
  let cam = if not canvas.syncCamera:
    var copy = display[CameraData].camera
    copy.id = 0
    copy
  else:
    display[CameraData].camera
  draw(canvas.vao, canvas.shader, @[canvas.texture], cam, canvas.drawOrder, canvas.renderSettings)

proc centered*(qb : var QuadBuilder) : var QuadBuilder {.discardable.} =
  qb.origin = vec2f(0.5,0.5)
  qb

proc swap*(canvas : var Canvas) =
  canvas.vao.swap()