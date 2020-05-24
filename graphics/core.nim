import nimgl/opengl
import easygl
import glm
import atomics
import tables
import macros
import color
import sequtils
import stb_image/read as stbi
import sugar
import ../noto

var vaoID : Atomic[int]
var bufferID : Atomic[int]
var shaderID : Atomic[int]
var textureID : Atomic[int]

type 
    VaoID* = int
    VertexBufferID* = int
    ShaderID* = int
    TextureID* = int

    VertexAttributeProfile* = concept v

    TextureInfo* = object
        id* : TextureID
        data* : pointer
        len* : int
        width* : int
        height* : int
        magFilter* : GLenum
        minFilter* : GLenum
        internalFormat* : GLenum
        dataFormat* : GLenum
        revision* : int

    Texture* = concept t
        textureInfo(t) is TextureInfo

    Shader* = ref object
        id : ShaderID
        vertexSource* : string
        fragmentSource* : string
        uniformBools* : Table[string, bool]
        uniformInts* : Table[string, int]
        uniformFloats* : Table[string, float]
        uniformVec2* : Table[string, Vec2f]
        uniformVec3* : Table[string, Vec3f]
        uniformVec4* : Table[string, Vec4f]
        uniformMat4* : Table[string, Mat4x4f]


    GrowableBuffer[T] = object
        data : ptr T
        len : int
        capacity : int

    GLBuffer[T] = object
        id : VertexBufferID
        frontBuffer : GrowableBuffer[T]
        backBuffer : GrowableBuffer[T]

    Vao*[VT : VertexAttributeProfile, IT : uint16 | uint32] = ref object
        id : VaoID
        vertices* : GLBuffer[VT]
        indices* : GLBuffer[IT]
        swapped : bool
        usage* : GLenum

    StaticTexture* = ref object
        texture : TextureInfo

    DynamicTexture* = ref object
        buffer : GLBuffer[color.RGBA]
        swapped : bool
        magFilter : GLenum
        minFilter : GLenum
        revision : int

    VertexBuffer* = object
        id : VertexBufferID
        data* : pointer
        len* : int
        usage : GLenum

    VertexArrayDefinition* = object
        dataType* : GLenum
        stride* : int
        offset* : int
        num* : int
        normalize* : bool

    DrawCommand* = object
        vao* : VaoID
        vertexBuffer* : VertexBuffer
        vertexArrayDefinitions* : seq[VertexArrayDefinition]
        indexBuffer* : VertexBuffer
        indexBufferType* : GLenum
        indexCount* : int
        shader* : Shader
        textures* : seq[TextureInfo]
        
    SimpleVertex* = object
        vertex* : Vec3f
        texCoords* : Vec2f
        color* : RGBA

    MinimalVertex* = object
        vertex* : Vec3f

let UnitSquareVertices* = @[vec3f(0.0f,0.0f,0.0f), vec3f(1.0f,0.0f,0.0f), vec3f(1.0f,1.0f,0.0f), vec3f(0.0f,1.0f,0.0f)]


#=============================================================================================#
#                                   Texture Functions                                         #
#=============================================================================================#

proc textureInfo*(st : StaticTexture) : TextureInfo =
    if st.texture.id == 0:
        st.texture.id = textureID.fetchAdd(1)+1
    result = st.texture
    result.revision = 1

proc textureInfo*(dt : DynamicTexture) : TextureInfo =
    if dt.buffer.id == 0:
        dt.buffer.id = textureID.fetchAdd(1)+1
    result = TextureInfo(
        id : dt.buffer.id,
        data : dt.buffer.frontBuffer.data,
        len : dt.buffer.frontBuffer.len,
        magFilter : dt.magFilter,
        minFilter : dt.minFilter,
        revision : dt.revision
    )

proc loadTexture*(path : string, gammaCorrection : bool = false) : StaticTexture =
    stbi.setFlipVerticallyOnLoad(true)               
    var width,height,channels:int        
    var data = stbi.load(path,width,height,channels,stbi.Default)        
    let gammaFormat = 
        if gammaCorrection: 
            GL_SRGB 
        else: 
            GL_RGB
            
    let (internalFormat,dataFormat) = 
        if channels == 1:                    
            (GL_RED,GL_RED)
        elif channels == 3:                    
            (gammaFormat,GL_RGB)
        elif channels == 4:
            (gammaFormat,GL_RGBA)
        else:            
            ( echo "texture unknown, assuming rgb";        
                   (GL_RGBA,GL_RGBA) )

    result = new StaticTexture
    result.texture.data = allocShared0(data.len)
    result.texture.len = data.len
    copyMem(data[0].addr, result.texture.data, data.len)
    result.texture.magFilter = GL_NEAREST
    result.texture.minFilter = GL_NEAREST
    result.texture.internalFormat = internalFormat
    result.texture.dataFormat = dataFormat
    result.texture.width = width
    result.texture.height = height

#=============================================================================================#
#                                    VAO Functions                                            #
#=============================================================================================#

proc `[]`* [T](buffer : var GrowableBuffer[T], index: int) : ptr T =
    if index >= buffer.capacity:
        var newCapacity = buffer.capacity
        if newCapacity == 0:
            newCapacity += 1
        while newCapacity <= index:
            newCapacity *= 2
        buffer.data = resizeShared(buffer.data, newCapacity)
    if index >= buffer.len:
        buffer.len = index+1
    cast[ptr T](cast[uint](buffer) + (index * sizeof(T)).uint)

proc `[]`* [T](buffer : var GLBuffer[T], index: int) : ptr T =
    buffer.backBuffer[index]

proc `[]=`* [T](buffer : var GLBuffer[T], index: int, v : T) =
    buffer.backBuffer[index][] = v

proc `[]`* [VT,IT](vao : Vao[VT,IT], index: int) : ptr VT =
    vao.vertices[index]

proc swap*[T](buffer : var GLBuffer[T]) =
    var tmp = buffer.frontBuffer
    buffer.frontBuffer = buffer.backBuffer
    buffer.backBuffer = tmp
    # swap(buffer.frontBuffer, buffer.backBuffer)

proc swap*[VT,IT](vao : VAO[VT,IT]) =
    vao.vertices.swap()
    vao.indices.swap()
    vao.swapped = true


#=============================================================================================#
#                                    Draw Command Functions                                   #
#=============================================================================================#


macro vertexArrayDefinitions(t : typed) : seq[VertexArrayDefinition] =
    var definitions = newStmtList()

    let tDesc = getType(getType(t)[1])
    
    let strideSym = genSym(nskLet, "stride")
    let seqSym = genSym(nskVar, "s")
    let offsetSym = genSym(nskVar, "offset")

    for field in tDesc[2].children:
        let fieldName = newIdentNode($field)

        definitions.add(
            quote do:
                when `t`.`fieldName` is Vec4u8:
                    `seqSym`.add(VertexArrayDefinition(dataType: GL_UNSIGNED_BYTE ,num : 4, offset : `offsetSym`, stride : `strideSym`, normalize : true))
                    `offsetSym` += 4
                when `t`.`fieldName` is RGBA:
                    `seqSym`.add(VertexArrayDefinition(dataType: GL_UNSIGNED_BYTE ,num : 4, offset : `offsetSym`, stride : `strideSym`, normalize : true))
                    `offsetSym` += 4
                when `t`.`fieldName` is float:
                    `seqSym`.add(VertexArrayDefinition(dataType: EGL_FLOAT ,num : 1, offset : `offsetSym`, stride : `strideSym`))
                    `offsetSym` += 4*1
                when `t`.`fieldName` is Vec2f:
                    `seqSym`.add(VertexArrayDefinition(dataType: EGL_FLOAT ,num : 2, offset : `offsetSym`, stride : `strideSym`))
                    `offsetSym` += 4*2
                when `t`.`fieldName` is Vec3f:
                    `seqSym`.add(VertexArrayDefinition(dataType: EGL_FLOAT ,num : 3, offset : `offsetSym`, stride : `strideSym`))
                    `offsetSym` += 4*3
                when `t`.`fieldName` is Vec4f:
                    `seqSym`.add(VertexArrayDefinition(dataType: EGL_FLOAT ,num : 4, offset : `offsetSym`, stride : `strideSym`))
                    `offsetSym` += 4*4
        )
    

    result = quote do:
        block:
            var `seqSym` : seq[VertexArrayDefinition] = @[]
            var `offsetSym` : int
            let `strideSym` = sizeof(`t`)
            `definitions`
            `seqSym`

proc draw* [VT : VertexAttributeProfile, IT : uint16 | uint32, TT : Texture](vao : Vao[VT, IT], shader : Shader, textures : seq[TT]) : DrawCommand =
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
        VertexBuffer(data : vao.vertices.frontBuffer.data, len : vao.vertices.frontBuffer.len * sizeof(VT), id : vao.vertices.id, usage : usage)
    else :
        VertexBuffer(id : vao.vertices.id, usage : usage)
    
    let indexBuffer = if vao.swapped:
        VertexBuffer(data : vao.indices.frontBuffer.data, len : vao.indices.frontBuffer.len * sizeof(IT), id : vao.indices.id, usage : usage)
    else:
        VertexBuffer(id : vao.indices.id, usage : usage)

    when IT is uint32:
        let indexType = GL_UNSIGNED_INT
    when IT is uint16:
        let indexType = GL_UNSIGNED_SHORT
    else:
        raiseAssert("invalid index type " & $IT)

    vao.swapped = false
    # var effTextures = newSeq[TextureInfo]()
    # for tex in textures:
    #     effTextures.add(textureInfo(tex))
    return DrawCommand(
        vao : vao.id,
        vertexBuffer: vertexBuffer,
        vertexArrayDefinitions: vertexArrayDefinitions(VT),
        indexBuffer : indexBuffer,
        indexBufferType : indexType,
        indexCount : vao.indices.frontBuffer.len,
        textures : textures.mapIt(textureInfo(it)),
        shader : shader
    )

proc merge*(command : var DrawCommand, next : DrawCommand) =
    if command.vao != next.vao or
        command.vertexBuffer.id != next.vertexBuffer.id or
        command.indexBuffer.id != next.indexBuffer.id:
            echo "Merge called with mismatched vao/vbo/iio"

    if next.vertexBuffer.data != nil:
        command.vertexBuffer = next.vertexBuffer
    if next.indexBuffer.data != nil:
        command.indexBuffer = next.indexBuffer
    command.textures = next.textures
    command.shader = next.shader


var glVaoIDs = @[0.VertexArrayID]
var glVertexPointersInitialized = @[true]
var glVboIDs = @[0.BufferID]
var glTextureIDs = @[0.TextureIDType]
var glTextureRevisions = @[0]
var glShaderIDs = @[0.ShaderProgramID]
var glShaderUniformLocations = @[newTable[string, UniformLocation]()]

proc setAt[T](s : var seq[T], i : int, v : T) =
    while s.len < i:
        s.add(default(T))
        
    if s.len == i:
        s.add(v)
    else:
        s[i] = v

proc addIfNeeded[T](s : var seq[T], i : int, v : () -> T): bool =
    if s.len <= i or s[i].int == 0:
        setAt(s, i, v())
        return true
    else:
        return false

proc lookupUniformLocation(shaderID : ShaderID, program : ShaderProgramID, name : string) : UniformLocation =
    if not glShaderUniformLocations[shaderID].hasKey(name):
        glShaderUniformLocations[shaderID][name] = getUniformLocation(program,name)
    result = glShaderUniformLocations[shaderID][name]

proc render*(command : var DrawCommand) =
    discard addIfNeeded(glVaoIDs,command.vao,() => genVertexArray())
        
    bindVertexArray(glVaoIDs[command.vao])
    
    if addIfNeeded(glVboIDs, command.vertexBuffer.id, () => genBuffer()):
        setAt(glVertexPointersInitialized, command.vertexBuffer.id, false)
    discard addIfNeeded(glVboIDs, command.indexBuffer.id, () => genBuffer())

    if command.vertexBuffer.data != nil:
        info "Buffering vertex data"
        bindBuffer(GL_ARRAY_BUFFER, glVboIDs[command.vertexBuffer.id])
        bufferData(GL_ARRAY_BUFFER, command.vertexBuffer.len, command.vertexBuffer.data, command.vertexBuffer.usage)
        command.vertexBuffer.data = nil

        if not glVertexPointersInitialized[command.vertexBuffer.id]:
            for index, varr in command.vertexArrayDefinitions:
                vertexAttribPointer(index.uint32, varr.num, varr.dataType, varr.normalize, varr.stride, varr.offset)
                enableVertexAttribArray(index.uint32)
            glVertexPointersInitialized[command.vertexBuffer.id] = true

    if command.indexBuffer.data != nil:
        info "Buffering element data"
        bindBuffer(GL_ELEMENT_ARRAY_BUFFER, glVboIDs[command.indexBuffer.id])
        bufferData(GL_ELEMENT_ARRAY_BUFFER, command.indexBuffer.len, command.indexBuffer.data, command.indexBuffer.usage)
        command.indexBuffer.data = nil
    
    for index, tex in command.textures:
        if addIfNeeded(glTextureIDs, tex.id, () => genTexture()):
            setAt(glTextureRevisions, tex.id, -1)
        
        bindTexture((GL_TEXTURE_0.int + index).GLEnum, glTextureIDs[tex.id])
        if glTextureRevisions[tex.id] < tex.revision:
            info "Buffering texture data"
            glTexImage2D(GL_TEXTURE_2D, 0.GLint, tex.internalFormat.GLint, tex.width.GLint, tex.height.GLint, 0.GLint, tex.dataFormat, GL_UNSIGNED_BYTE, tex.data)
            glTextureRevisions[tex.id] = tex.revision


    let vertexSource = command.shader.vertexSource
    let fragmentSource = command.shader.fragmentSource
    if addIfNeeded(glShaderIDs, command.shader.id, () => createAndLinkProgram(vertexSource, fragmentSource)):
        setAt(glShaderUniformLocations, command.shader.id, newTable[string,UniformLocation]())
    let shader = glShaderIDs[command.shader.id]
    shader.use()

    for k,v in command.shader.uniformMat4:
        var tmp = v
        glUniformMatrix4fv(lookupUniformLocation(command.shader.id, shader, k).GLint, 1, false, tmp.caddr)
    for k,v in command.shader.uniformVec4:
        var tmp = v
        glUniform4fv(lookupUniformLocation(command.shader.id, shader, k).GLint, 1, tmp.caddr)
    for k,v in command.shader.uniformVec3:
        var tmp = v
        glUniform3fv(lookupUniformLocation(command.shader.id, shader, k).GLint, 1, tmp.caddr)
    for k,v in command.shader.uniformVec2:
        var tmp = v
        glUniform2fv(lookupUniformLocation(command.shader.id, shader, k).GLint, 1, tmp.caddr)
    for k,v in command.shader.uniformFloats:
        glUniform1f(lookupUniformLocation(command.shader.id, shader, k).GLint, v)
    for k,v in command.shader.uniformBools:
        glUniform1i(lookupUniformLocation(command.shader.id, shader, k).GLint, v.GLint)
    for k,v in command.shader.uniformInts:
        glUniform1i(lookupUniformLocation(command.shader.id, shader, k).GLint, v.GLint)
    
    drawElements(GL_TRIANGLES, command.indexCount, command.indexBufferType, 0)

when isMainModule:
    import glm

    type
        TestVertex = object
            vertex : Vec3f
            color : Vec4u8

    let vao = VAO[TestVertex, uint16]()

    vao[0].vertex = vec3f(1,2,3)
    vao[1].vertex = vec3f(2,3,4)

    assert vao[1].vertex.z == 4

    let shader = Shader()

    let staticTexture = StaticTexture(texture : default(TextureInfo))

    let drawCommand = draw(vao, shader, @[staticTexture])
    assert drawCommand.vertexArrayDefinitions == @[
        VertexArrayDefinition(dataType : EGL_FLOAT, offset : 0, stride : sizeof(TestVertex), num : 3),
        VertexArrayDefinition(dataType : GL_UNSIGNED_BYTE, offset : 12, stride : sizeof(TestVertex), num : 4, normalize : true)
    ]
    assert drawCommand.textures == @[staticTexture.textureInfo()]
    assert drawCommand.shader == shader