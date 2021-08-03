import nimgl/[glfw, opengl]
import easygl
import glm
import atomics
import tables
import macros
import color
import ../stb_image/read as stbi
import sugar
import ../noto
import strutils
import ../engines/event_types
import ../worlds
import cameras
import images
import options
import prelude

var vaoID: Atomic[int]
var bufferID: Atomic[int]
var shaderID: Atomic[int]
var textureID*: Atomic[int]

type
  VaoID* = int
  VertexBufferID* = int
  ShaderID* = int
  TextureID* = int

  TextureInfo* = object
    id*: TextureID
    data*: pointer
    len*: int
    width*: int
    height*: int
    magFilter*: GLenum
    minFilter*: GLenum
    internalFormat*: GLenum
    dataFormat*: GLenum
    revision*: int

  Shader* = ref object
    id: ShaderID
    vertexSource*: string
    fragmentSource*: string
    uniformBools*: Table[string, bool]
    uniformInts*: Table[string, int]
    uniformFloats*: Table[string, float]
    uniformVec2*: Table[string, Vec2f]
    uniformVec3*: Table[string, Vec3f]
    uniformVec4*: Table[string, Vec4f]
    uniformMat4*: Table[string, Mat4x4f]


  GrowableBuffer[T] = object
    data: ptr T
    len: int
    capacity: int

  GLBuffer[T] = object
    id: VertexBufferID
    frontBuffer: GrowableBuffer[T]
    backBuffer: GrowableBuffer[T]

  Vao*[VT; IT: uint16 | uint32] = ref object
    id: VaoID
    vertices*: GLBuffer[VT]
    indices*: GLBuffer[IT]
    swapped: bool
    usage*: GLenum
    revision*: int

  Texture* = ref object of RootRef


  StaticTexture* = ref object of Texture
    texture: TextureInfo

  DynamicTexture* = ref object of Texture
    buffer: GLBuffer[color.RGBA]
    swapped: bool
    magFilter: GLenum
    minFilter: GLenum
    revision: int

  # TextureKind* {.pure.} = enum
  #   Static
  #   Dynamic

  # Texture* = object
  #   case kind : TextureKind
  #   of TextureKind.Static: staticTexture : StaticTexture
  #   of TextureKind.Dynamic: dynamicTexture : DynamicTexture

  VertexBuffer* = object
    id: VertexBufferID
    data*: pointer
    len*: int
    usage: GLenum

  VertexArrayDefinition* = object
    dataType*: GLenum
    stride*: int
    offset*: int
    num*: int
    normalize*: bool
    name*: string

  RenderSettings* = object
    depthTestEnabled*: bool
    depthFunc*: GLenum
    alphaTestEnabled*: bool

  DrawCommandKind* {.pure.} = enum
    DrawCommandUpdate
    CameraUpdate
    Finish

  DrawCommand* = object
    camera*: Camera
    case kind*: DrawCommandKind:
      of DrawCommandUpdate:
        vao*: VaoID
        vaoRevision*: int
        vertexBuffer*: VertexBuffer
        vertexArrayDefinitions*: seq[VertexArrayDefinition]
        indexBuffer*: VertexBuffer
        indexBufferType*: GLenum
        indexCount*: int
        shader*: Shader
        textures*: seq[TextureInfo]
        renderSettings*: RenderSettings
        drawOrder*: int
        requiredUpdateFrequency*: Option[UnitOfTime]
      of DrawCommandKind.CameraUpdate:
        discard
      of DrawCommandKind.Finish:
        discard


  SimpleVertex* = object
    vertex*: Vec3f
    texCoords*: Vec2f
    color*: RGBA

  MinimalVertex* = object
    vertex*: Vec3f

  WindowResolutionChanged* = ref object of Event
    windowSize*: Vec2i
    framebufferSize*: Vec2i

  GraphicsContextData* = object
    windowSize*: Vec2i
    framebufferSize*: Vec2i

  GraphicsContextCommandKind* {.pure.} = enum
    CursorCommand

  GraphicsContextCommand* = object
    case kind*: GraphicsContextCommandKind
    of GraphicsContextCommandKind.CursorCommand:
      cursorEnabled*: bool
      cursorIcon*: Option[string]
      standardCursor*: Option[int]

var graphicsContextCommandChannel*: Channel[GraphicsContextCommand]
graphicsContextCommandChannel.open()

defineDisplayReflection(GraphicsContextData)


const UnitSquareVertices*: array[4, Vec3f] = [vec3f(0.0f, 0.0f, 0.0f), vec3f(1.0f, 0.0f, 0.0f), vec3f(1.0f, 1.0f, 0.0f), vec3f(0.0f, 1.0f, 0.0f)]
const CenteredUnitSquareVertices*: array[4, Vec3f] = [vec3f(-0.5f, -0.5f, 0.0f), vec3f(0.5f, -0.5f, 0.0f), vec3f(0.5f, 0.5f, 0.0f), vec3f(-0.5f, 0.5f, 0.0f)]
const UnitSquareVertices2d*: array[4, Vec2f] = [vec2f(0.0f, 0.0f), vec2f(1.0f, 0.0f), vec2f(1.0f, 1.0f), vec2f(0.0f, 1.0f)]
  # var UnitSquareVerticesStore {.threadvar.} : array[4, Vec3f]
  # template UnitSquareVertices* : array[4, Vec3f] =
  #   if UnitSquareVerticesStore.len == 0:
  #     UnitSquareVerticesStore = [vec3f(0.0f,0.0f,0.0f), vec3f(1.0f,0.0f,0.0f), vec3f(1.0f,1.0f,0.0f), vec3f(0.0f,1.0f,0.0f)]
  #   UnitSquareVerticesStore



  #=============================================================================================#
  #                  Texture Functions                     #
  #=============================================================================================#

method textureInfo*(st: Texture): TextureInfo {.base.} =
  echo "textureInfo() must be overridden for child texture types"
  discard

method textureInfo*(st: StaticTexture): TextureInfo =
  if st.texture.id == 0:
    st.texture.id = textureID.fetchAdd(1)+1
  result = st.texture
  result.revision = 1

method textureInfo*(dt: DynamicTexture): TextureInfo =
  if dt.buffer.id == 0:
    dt.buffer.id = textureID.fetchAdd(1)+1
  result = TextureInfo(
    id: dt.buffer.id,
    data: dt.buffer.frontBuffer.data,
    len: dt.buffer.frontBuffer.len,
    magFilter: dt.magFilter,
    minFilter: dt.minFilter,
    revision: dt.revision
  )

proc toTexture*(image: Image; gammaCorrection: bool = false): StaticTexture =
  result = new StaticTexture

  result.texture.data = image.data
  let len = image.dimensions.x * image.dimensions.y * image.channels
  let gammaFormat =
    if gammaCorrection:
      GL_SRGB_ALPHA
    else:
      GL_RGBA

  let (internalFormat, dataFormat) =
    if image.channels == 1:
      (GL_RED, GL_RED)
    elif image.channels == 3:
      (gammaFormat, GL_RGB)
    elif image.channels == 4:
      (gammaFormat, GL_RGBA)
    else:
      (echo "texture unknown, assuming rgb";
          (GL_RGBA, GL_RGBA))


  result.texture.len = len

  result.texture.magFilter = GL_NEAREST
  result.texture.minFilter = GL_NEAREST
  result.texture.internalFormat = internalFormat
  result.texture.dataFormat = dataFormat
  result.texture.width = image.dimensions.x
  result.texture.height = image.dimensions.y


proc loadTexture*(path: string; gammaCorrection: bool = false): StaticTexture =
  result = new StaticTexture

  stbi.setFlipVerticallyOnLoad(true)
  var width, height, channels: int
  result.texture.data = stbi.load(path, width, height, channels, stbi.Default)
  let len = width * height * channels
  let gammaFormat =
    if gammaCorrection:
      GL_SRGB_ALPHA
    else:
      GL_RGBA

  let (internalFormat, dataFormat) =
    if channels == 1:
      (GL_RED, GL_RED)
    elif channels == 3:
      (gammaFormat, GL_RGB)
    elif channels == 4:
      (gammaFormat, GL_RGBA)
    else:
      (echo "texture unknown, assuming rgb";
          (GL_RGBA, GL_RGBA))


  result.texture.len = len

  result.texture.magFilter = GL_NEAREST
  result.texture.minFilter = GL_NEAREST
  result.texture.internalFormat = internalFormat
  result.texture.dataFormat = dataFormat
  result.texture.width = width
  result.texture.height = height

#=============================================================================================#
#                  VAO Functions                      #
#=============================================================================================#

proc newVao*[VT, IT](): Vao[VT, IT] =
  new VAO[VT, IT]

proc `[]`*[T](buffer: var GrowableBuffer[T]; index: int): ptr T =
  if index >= buffer.capacity:
    var newCapacity = buffer.capacity
    if newCapacity == 0:
      newCapacity += 100
    while newCapacity <= index:
      newCapacity *= 2
    let newData = cast[ptr T](allocShared0(newCapacity * sizeof(T)))
    if buffer.data != nil:
      copyMem(newData, buffer.data, buffer.len * sizeof(T))
      freeShared(buffer.data)
    buffer.data = newData
    buffer.capacity = newCapacity

  if index >= buffer.len:
    buffer.len = index+1
  cast[ptr T](cast[uint](buffer.data) + (index * sizeof(T)).uint)

proc clear*[T](buffer: var GrowableBuffer[T]) =
  buffer.len = 0

proc `[]`*[T](buffer: var GLBuffer[T]; index: int): ptr T =
  buffer.backBuffer[index]

proc `[]=`*[T](buffer: var GLBuffer[T]; index: int; v: T) =
  buffer.backBuffer[index][] = v

proc `[]`*[VT, IT](vao: Vao[VT, IT]; index: int): ptr VT =
  vao.vertices[index]

proc addIQuad*[VT, IT, OT](vao: Vao[VT, IT]; ii: var int; vi: var OT) =
  vao.indices[ii+0] = (vi+0).IT
  vao.indices[ii+1] = (vi+1).IT
  vao.indices[ii+2] = (vi+2).IT

  vao.indices[ii+3] = (vi+2).IT
  vao.indices[ii+4] = (vi+3).IT
  vao.indices[ii+5] = (vi+0).IT

  ii += 6
  vi += 4

proc addITri*[VT, IT, OT](vao: Vao[VT, IT]; ii: var int; vi: var OT) =
  vao.indices[ii+0] = (vi+0).IT
  vao.indices[ii+1] = (vi+1).IT
  vao.indices[ii+2] = (vi+2).IT

  ii += 3
  vi += 3

proc swap*[T](buffer: var GLBuffer[T]) =
  var tmp = buffer.frontBuffer
  buffer.frontBuffer = buffer.backBuffer
  buffer.backBuffer = tmp
  buffer.backBuffer.clear()
  # swap(buffer.frontBuffer, buffer.backBuffer)

proc swap*[VT, IT](vao: VAO[VT, IT]) =
  vao.vertices.swap()
  vao.indices.swap()
  vao.swapped = true
  vao.revision.inc

proc `$`*[T](buffer: var GrowableBuffer[T]): string =
  result = "["
  for i in 0 ..< buffer.len:
    result &= $(buffer[i][])
    result &= ",\n"
  result &= "]"

proc `$`*[T](buffer: var GLBuffer[T]): string =
  result = "Buffer {\n" &
    "\tfrontBuffer: " & $buffer.frontBuffer & "\n" &
    "\tbackBuffer: " & $buffer.backBuffer & "\n" &
    "}"

proc vi*[VT, IT](vao: Vao[VT, IT]): int =
  vao.vertices.backBuffer.len

proc ii*[VT, IT](vao: Vao[VT, IT]): int =
  vao.indices.backBuffer.len

#=============================================================================================#
#                  Shader Functions                     #
#=============================================================================================#

proc initShader*(basePath: string): Shader =
  result = Shader(
    fragmentSource: "resources/" & basePath & ".fragment",
    vertexSource: "resources/" & basePath & ".vertex",
    uniformBools: initTable[string, bool](),
    uniformInts: initTable[string, int](),
    uniformFloats: initTable[string, float](),
    uniformVec2: initTable[string, Vec2f](),
    uniformVec3: initTable[string, Vec3f](),
    uniformVec4: initTable[string, Vec4f](),
    uniformMat4: initTable[string, Mat4f]()
  )


#=============================================================================================#
#                  Draw Command Functions                  #
#=============================================================================================#


macro vertexArrayDefinitions(t: typed): seq[VertexArrayDefinition] =
  var definitions = newStmtList()

  let tDesc = getType(getType(t)[1])

  let strideSym = genSym(nskLet, "stride")
  let seqSym = genSym(nskVar, "s")
  let offsetSym = genSym(nskVar, "offset")

  for field in tDesc[2].children:
    let fieldName = newIdentNode($field)
    let fieldNameLit = newLit($field)

    definitions.add(
      quote do:
      when `t`.`fieldName` is Vec4u8:
        `seqSym`.add(VertexArrayDefinition(name: `fieldNameLit`, dataType: GL_UNSIGNED_BYTE, num: 4, offset: `offsetSym`, stride: `strideSym`, normalize: true))
        `offsetSym` += 4
      when `t`.`fieldName` is RGBA:
        `seqSym`.add(VertexArrayDefinition(name: `fieldNameLit`, dataType: GL_UNSIGNED_BYTE, num: 4, offset: `offsetSym`, stride: `strideSym`, normalize: true))
        `offsetSym` += 4
      when `t`.`fieldName` is float:
        `seqSym`.add(VertexArrayDefinition(name: `fieldNameLit`, dataType: EGL_FLOAT, num: 1, offset: `offsetSym`, stride: `strideSym`))
        `offsetSym` += 4*1
      when `t`.`fieldName` is Vec2f:
        `seqSym`.add(VertexArrayDefinition(name: `fieldNameLit`, dataType: EGL_FLOAT, num: 2, offset: `offsetSym`, stride: `strideSym`))
        `offsetSym` += 4*2
      when `t`.`fieldName` is Vec3f:
        `seqSym`.add(VertexArrayDefinition(name: `fieldNameLit`, dataType: EGL_FLOAT, num: 3, offset: `offsetSym`, stride: `strideSym`))
        `offsetSym` += 4*3
      when `t`.`fieldName` is Vec4f:
        `seqSym`.add(VertexArrayDefinition(name: `fieldNameLit`, dataType: EGL_FLOAT, num: 4, offset: `offsetSym`, stride: `strideSym`))
        `offsetSym` += 4*4
    )


  result = quote do:
    block:
      var `seqSym`: seq[VertexArrayDefinition] = @[]
      var `offsetSym`: int
      let `strideSym` = sizeof(`t`)
      `definitions`
      `seqSym`

proc defaultRenderSettings*(): RenderSettings =
  RenderSettings(
    depthTestEnabled: false,
    depthFunc: GL_LEQUAL
  )

proc draw*[VT; IT: uint16 | uint32; TT: Texture](vao: Vao[VT, IT]; shader: Shader; textures: seq[TT]; camera: Camera; drawOrder: int = 0; renderSettings: RenderSettings = defaultRenderSettings()): DrawCommand =
  if vao.id == 0:
    vao.id = vaoID.fetchAdd(1)+1
    vao.vertices.id = bufferID.fetchAdd(1)+1
    vao.indices.id = bufferID.fetchAdd(1)+1
  if shader.id == 0:
    shader.id = shaderID.fetchAdd(1)+1

  var usage = GL_STATIC_DRAW
  if vao.usage.int != 0:
    usage = vao.usage
  let vertexBuffer = if vao.swapped:
    VertexBuffer(data: vao.vertices.frontBuffer.data, len: vao.vertices.frontBuffer.len * sizeof(VT), id: vao.vertices.id, usage: usage)
  else:
    VertexBuffer(id: vao.vertices.id, usage: usage)

  let indexBuffer = if vao.swapped:
    VertexBuffer(data: vao.indices.frontBuffer.data, len: vao.indices.frontBuffer.len * sizeof(IT), id: vao.indices.id, usage: usage)
  else:
    VertexBuffer(id: vao.indices.id, usage: usage)

  when IT is uint32:
    let indexType = GL_UNSIGNED_INT
  elif IT is uint16:
    let indexType = GL_UNSIGNED_SHORT
  else:
    raiseAssert("invalid index type " & $IT)

  vao.swapped = false
  var effTextures = newSeq[TextureInfo]()
  for tex in textures:
    effTextures.add(textureInfo(tex))
  return DrawCommand(
    kind: DrawCommandKind.DrawCommandUpdate,
    vao: vao.id,
    vaoRevision: vao.revision,
    vertexBuffer: vertexBuffer,
    vertexArrayDefinitions: vertexArrayDefinitions(VT),
    indexBuffer: indexBuffer,
    indexBufferType: indexType,
    indexCount: vao.indices.frontBuffer.len,
    textures: effTextures,
    shader: shader,
    camera: camera,
    renderSettings: renderSettings,
    drawOrder: drawOrder,
  )


# proc `==`*(a,b: Shader) : bool =
#   if a.id != b.id:
#     echo "id difference"
#     return false
#   if a.uniformBools != b.uniformBools:
#     echo "uniform difference: " & $a.uniformBools & " != " & $b.uniformBools
#     return false
#   if a.uniformInts != b.uniformInts:
#     echo "uniform difference: " & $a.uniformInts & " != " & $b.uniformInts
#     return false
#   if a.uniformFloats != b.uniformFloats:
#     echo "uniform difference: " & $a.uniformFloats & " != " & $b.uniformFloats
#     return false
#   if a.uniformVec2 != b.uniformVec2:
#     echo "uniform difference: " & $a.uniformVec2 & " != " & $b.uniformVec2
#     return false
#   if a.uniformVec3 != b.uniformVec3:
#     echo "uniform difference: " & $a.uniformVec3 & " != " & $b.uniformVec3
#     return false
#   if a.uniformVec4 != b.uniformVec4:
#     echo "uniform difference: " & $a.uniformVec4 & " != " & $b.uniformVec4
#     return false
#   if a.uniformMat4 != b.uniformMat4:
#     echo "uniform difference: " & $a.uniformMat4 & " != " & $b.uniformMat4
#     return false
#   if a.fragmentSource != b.fragmentSource or a.vertexSource != b.vertexSource:
#     echo "source difference"
#     return false
#   true

proc `$`*(shader: Shader) : string =
  result = "Shader(" & $shader.id.int & "):\n"
  for k,v in shader.uniformBools:
    result.add("\t" & $k & " : " & $v)
  for k,v in shader.uniformInts:
    result.add("\t" & $k & " : " & $v)
  for k,v in shader.uniformFloats:
    result.add("\t" & $k & " : " & $v)
  for k,v in shader.uniformVec2:
    result.add("\t" & $k & " : " & $v)
  for k,v in shader.uniformVec3:
    result.add("\t" & $k & " : " & $v)
  for k,v in shader.uniformVec4:
    result.add("\t" & $k & " : " & $v)
  for k,v in shader.uniformMat4:
    result.add("\t" & $k & " : " & $v)
  result.add("src\n" & shader.fragmentSource & "\n" & shader.vertexSource)

# Returns true if there was any practical change to the draw command that would require a redraw
proc merge*(command: var DrawCommand; next: DrawCommand) : bool =
  var redrawNeeded = false
  template compareAndSet(a,b: typed) =
    if a != b:
      a = b
      redrawNeeded = true
      # info "Redraw needed due to inequality " & $a & " != " & $b

  if command.vao != next.vao or
    command.vertexBuffer.id != next.vertexBuffer.id or
    command.indexBuffer.id != next.indexBuffer.id:
    redrawNeeded = true

  if next.vertexBuffer.data != nil:
    command.vertexBuffer = next.vertexBuffer
  if next.indexBuffer.data != nil:
    command.indexBuffer = next.indexBuffer

  if command.textures.len != next.textures.len:
    redrawNeeded = true
  else:
    for i in 0 ..< command.textures.len:
      if command.textures[i].id != next.textures[i].id or command.textures[i].revision != next.textures[i].revision:
        redrawNeeded = true
        break
  command.textures = next.textures

  compareAndSet(command.requiredUpdateFrequency, next.requiredUpdateFrequency)

  compareAndSet(command.shader[], next.shader[])
  if not effectivelyEquivalent(command.camera, next.camera):
    command.camera = next.camera
    redrawNeeded = true
    # info "Redraw needed due to camera"
  compareAndSet(command.indexCount, next.indexCount)
  compareAndSet(command.renderSettings, next.renderSettings)
  compareAndSet(command.drawOrder, next.drawOrder)

  if command.vaoRevision != next.vaoRevision:
    command.vaoRevision = next.vaoRevision
    redrawNeeded = true
    # info "Redraw needed due to vao"
  redrawNeeded


var glVaoIDs = @[0.VertexArrayID]
var glVaoRevisions = @[0]
var glVertexPointersInitialized = @[true]
var glVboIDs = @[0.BufferID]
var glTextureIDs = @[0.TextureIDType]
var glTextureRevisions = @[0]
var glShaderIDs = @[0.ShaderProgramID]
var glShaderUniformLocations = @[newTable[string, UniformLocation]()]
var shadersBySource = newTable[(string, string), ShaderProgramID]()

proc setAt[T](s: var seq[T]; i: int; v: T) =
  while s.len < i:
    s.add(default(T))

  if s.len == i:
    s.add(v)
  else:
    s[i] = v

proc addIfNeeded[T](s: var seq[T]; i: int; v: () -> T): bool =
  if s.len <= i or s[i].int == 0:
    setAt(s, i, v())
    return true
  else:
    return false

proc lookupUniformLocation(shaderID: ShaderID; program: ShaderProgramID; name: string): UniformLocation =
  if not glShaderUniformLocations[shaderID].hasKey(name):
    glShaderUniformLocations[shaderID][name] = getUniformLocation(program, name)
  result = glShaderUniformLocations[shaderID][name]

proc cachedCreateAndLinkProgram(vertexSource: string; fragmentSource: string): ShaderProgramID =
  if not shadersBySource.hasKey((vertexSource, fragmentSource)):
    let id = createAndLinkProgram(vertexSource, fragmentSource)
    shadersBySource[(vertexSource, fragmentSource)] = id
  shadersBySource[(vertexSource, fragmentSource)]

proc render*(command: var DrawCommand; cameras: seq[Camera], framebufferSize: Vec2i) =
  if command.vertexBuffer.len == 0 or command.indexBuffer.len == 0:
    return
  discard addIfNeeded(glVaoIDs, command.vao, () => genVertexArray())

  let vertexSource = command.shader.vertexSource
  let fragmentSource = command.shader.fragmentSource
  if addIfNeeded(glShaderIDs, command.shader.id, () => cachedCreateAndLinkProgram(vertexSource, fragmentSource)):
    setAt(glShaderUniformLocations, command.shader.id, newTable[string, UniformLocation]())
  let shader = glShaderIDs[command.shader.id]
  shader.use()
  checkGLError()

  let time = glfwGetTime()
  if command.camera.id != 0 and command.camera.id < cameras.len:
    command.camera = cameras[command.camera.id]
  let deltaTime = time - command.camera.lastUpdated
  command.camera.lastUpdated = time
  command.camera.update(deltaTime / 0.01666666666667)

  bindVertexArray(glVaoIDs[command.vao])
  checkGLError()

  if addIfNeeded(glVboIDs, command.vertexBuffer.id, () => genBuffer()):
    setAt(glVertexPointersInitialized, command.vertexBuffer.id, false)
  discard addIfNeeded(glVboIDs, command.indexBuffer.id, () => genBuffer())
  discard addIfNeeded(glVaoRevisions, command.vao.int, () => -1)

  if command.vertexBuffer.data != nil and command.vaoRevision > glVaoRevisions[command.vao.int]:
    bindBuffer(GL_ARRAY_BUFFER, glVboIDs[command.vertexBuffer.id])
    bufferData(GL_ARRAY_BUFFER, command.vertexBuffer.len, command.vertexBuffer.data, command.vertexBuffer.usage)
    checkGLError()

    if not glVertexPointersInitialized[command.vertexBuffer.id]:
      var index = command.vertexArrayDefinitions.len - 1
      # for index, varr in command.vertexArrayDefinitions:
      while index >= 0:
        let varr = command.vertexArrayDefinitions[index]
        enableVertexAttribArray(index.uint32)
        vertexAttribPointer(index.uint32, varr.num, varr.dataType, varr.normalize, varr.stride, varr.offset)
        # checkGLError()

        # echo "Binding shader ", $shader.int, " index ", $index, " to ", varr.name.capitalizeAscii
        # glBindAttribLocation(shader.GLuint, index.GLuint, varr.name.capitalizeAscii)
        index.dec
      glVertexPointersInitialized[command.vertexBuffer.id] = true

    command.vertexBuffer.data = nil

  if command.indexBuffer.data != nil and command.vaoRevision > glVaoRevisions[command.vao.int]:
    fine "Buffering element data"
    bindBuffer(GL_ELEMENT_ARRAY_BUFFER, glVboIDs[command.indexBuffer.id])
    bufferData(GL_ELEMENT_ARRAY_BUFFER, command.indexBuffer.len, command.indexBuffer.data, command.indexBuffer.usage)
    command.indexBuffer.data = nil
    # checkGLError()

  glVaoRevisions[command.vao.int] = command.vaoRevision

  for index, tex in command.textures:
    if addIfNeeded(glTextureIDs, tex.id, () => genTexture()):
      setAt(glTextureRevisions, tex.id, -1)

    activeTexture((GL_TEXTURE0.int + index).GLenum)
    bindTexture(GL_TEXTURE_2D, glTextureIDs[tex.id])
    if glTextureRevisions[tex.id] < tex.revision:
      checkGLError()
      fine &"Buffering texture data, data format: {tex.dataFormat} internalFormat: {tex.internalFormat} magfilter: {tex.magFilter} minfilter: {tex.minFilter}"
      fine &"\twidth: {tex.width} height: {tex.height} len: {tex.len}"
      let minFilter = if tex.minFilter.int != 0: tex.minFilter
              else: GL_NEAREST
      let magFilter = if tex.minFilter.int != 0: tex.magFilter
              else: GL_NEAREST
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter.GLint)
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter.GLint)
      glTexImage2D(GL_TEXTURE_2D, 0.GLint, tex.internalFormat.GLint, tex.width.GLint, tex.height.GLint, 0.GLint, tex.dataFormat, GL_UNSIGNED_BYTE, tex.data)
      glTextureRevisions[tex.id] = tex.revision
      checkGLError()


  let modelviewMatrixLoc = lookupUniformLocation(command.shader.id, shader, "ModelViewMatrix").GLint
  let projectionMatrixLoc = lookupUniformLocation(command.shader.id, shader, "ProjectionMatrix").GLint
  let currentTimeLoc = lookupUniformLocation(command.shader.id, shader, "CurrentTime").GLint
  if modelviewMatrixLoc != -1:
    var tmp = command.camera.modelviewMatrix()
    glUniformMatrix4fv(modelviewMatrixLoc, 1, false, tmp.caddr)
  if projectionMatrixLoc != -1:
    var tmp = command.camera.projectionMatrix(framebufferSize)
    glUniformMatrix4fv(projectionMatrixLoc, 1, false, tmp.caddr)
  if currentTimeLoc != -1:
    if command.requiredUpdateFrequency.isNone:
      warn &"Shader with CurrentTime uniform variable does not define a requiredUpdateFrequency: {command.shader.vertexSource}"
    glUniform1f(currentTimeLoc, time)

  # TODO: cache and do not set these if they remain constant
  for k, v in command.shader.uniformMat4:
    var tmp = v
    let loc = lookupUniformLocation(command.shader.id, shader, k).GLint
    if loc != -1:
      glUniformMatrix4fv(loc, 1, false, tmp.caddr)
    checkGLError()
  for k, v in command.shader.uniformVec4:
    var tmp = v
    let loc = lookupUniformLocation(command.shader.id, shader, k).GLint
    if loc != -1:
      glUniform4fv(loc, 1, tmp.caddr)
    checkGLError()
  for k, v in command.shader.uniformVec3:
    var tmp = v
    let loc = lookupUniformLocation(command.shader.id, shader, k).GLint
    if loc != -1:
      glUniform3fv(loc, 1, tmp.caddr)
    checkGLError()
  for k, v in command.shader.uniformVec2:
    var tmp = v
    let loc = lookupUniformLocation(command.shader.id, shader, k).GLint
    if loc != -1:
      glUniform2fv(loc, 1, tmp.caddr)
    checkGLError()
  for k, v in command.shader.uniformFloats:
    let loc = lookupUniformLocation(command.shader.id, shader, k).GLint
    if loc != -1:
      glUniform1f(loc, v)
    checkGLError()
  for k, v in command.shader.uniformBools:
    let loc = lookupUniformLocation(command.shader.id, shader, k).GLint
    if loc != -1:
      glUniform1i(loc, v.GLint)
    checkGLError()
  for k, v in command.shader.uniformInts:
    let loc = lookupUniformLocation(command.shader.id, shader, k).GLint
    if loc != -1:
      glUniform1i(loc, v.GLint)
    checkGLError()

  if command.renderSettings.depthTestEnabled:
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(command.renderSettings.depthFunc)
  else:
    glDisable(GL_DEPTH_TEST)

  drawElements(GL_TRIANGLES, command.indexCount, command.indexBufferType, 0)
  checkGLError()




proc enableCursor*() =
  discard graphicsContextCommandChannel.trySend(GraphicsContextCommand(kind: GraphicsContextCommandKind.CursorCommand, cursorEnabled: true))

proc disableCursor*() =
  discard graphicsContextCommandChannel.trySend(GraphicsContextCommand(kind: GraphicsContextCommandKind.CursorCommand, cursorEnabled: false))

proc setCursorShape*(iconName: string) =
  discard graphicsContextCommandChannel.trySend(GraphicsContextCommand(kind: GraphicsContextCommandKind.CursorCommand, cursorEnabled: true, cursorIcon : some(iconName)))

proc setCursorShape*(standardCursor: int) =
  discard graphicsContextCommandChannel.trySend(GraphicsContextCommand(kind: GraphicsContextCommandKind.CursorCommand, cursorEnabled: true, standardCursor : some(standardCursor)))

proc resetCursorShape*() =
  discard graphicsContextCommandChannel.trySend(GraphicsContextCommand(kind: GraphicsContextCommandKind.CursorCommand, cursorEnabled: true, standardCursor : some(0)))

when isMainModule:
  import glm

  type
    TestVertex = object
      vertex: Vec3f
      color: Vec4u8

  let vao = VAO[TestVertex, uint16]()

  vao[0].vertex = vec3f(1, 2, 3)
  vao[1].vertex = vec3f(2, 3, 4)

  assert vao[1].vertex.z == 4

  let shader = Shader()

  let staticTexture: Texture = StaticTexture(texture: default(TextureInfo))

  let camera: Camera = createPixelCamera(1)

  let drawCommand = draw(vao, shader, @[staticTexture], camera)
  assert drawCommand.vertexArrayDefinitions == @[
    VertexArrayDefinition(dataType: EGL_FLOAT, offset: 0, stride: sizeof(TestVertex), num: 3, name: "vertex"),
    VertexArrayDefinition(dataType: GL_UNSIGNED_BYTE, offset: 12, stride: sizeof(TestVertex), num: 4, normalize: true, name: "color")
  ]
  assert drawCommand.textures == @[staticTexture.textureInfo()]
  assert drawCommand.shader == shader
