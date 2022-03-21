import fonts
import prelude
import glm
import game/grids
import engines
import graphics/cameras
import std/unicode
import graphics/core
import graphics/texture_block
import graphics/color
import noto
import sequtils
import algorithm
import tables
import windowingsystem/windowing_system_core
import windowingsystem/windowingsystem
import windowingsystem/text_widget
import hashes
import ../core as main_core
import config/config_binding
import resources
import windowingsystem/list_widget
import windowingsystem/image_widget
import graphics/image_extras
import strutils
import bitops
import arxmath


type
  Char* = object
    rune*: Rune
    foreground*: uint8
    background*: uint8
    z*: int8

  AsciiBuffer* = object
    dimensions*: Vec2i
    buffer: seq[Char]

  AsciiColorTable* = ref object
    colors: seq[RGBA]
    r_colors: Table[RGBA, uint8]

  AsciiCanvas* = ref object
    buffer*: ref AsciiBuffer
    resized*: bool
    revision*: int
    renderedRevision: int
    drawPriority*: int
    runeInfo: seq[RuneInfo]
    colorTable*: AsciiColorTable
    boundsStack*: seq[Recti]

  AsciiGraphics* = object
    baseCharDimensions*: Vec2i
    charDimensions*: Vec2i
    buffer*: ref AsciiBuffer
    colorTable*: AsciiColorTable
    typeface*: ArxTypeface
    font*: ArxFont
    canvases*: seq[AsciiCanvas]

  AsciiCanvasComponent* = ref object of GraphicsComponent
    vao: Vao[SimpleVertex, uint32]
    texture: TextureBlock
    shader: Shader
    camera: Camera

  BoxPieces* {.pure.} = enum
    None
    TopLeft
    TopRight
    BottomLeft
    BottomRight
    Horizontal
    Vertical
    Cross
    RightJoin
    LeftJoin
    TopJoin
    BottomJoin


  RuneInfo* = object
    boxPiece*: BoxPieces
    doubleVertical*: bool
    doubleHorizontal*: bool

  AsciiWindowingSystemComponent* = ref object of GraphicsComponent

  AsciiWindowing* = object
    canvas*: AsciiCanvas

  AsciiWidgetPlugin* = ref object of WindowingComponent

  AsciiWidgetBorder* = object
    width*: Bindable[int]
    color*: Option[Bindable[RGBA]]
    join*: bool
    fill*: bool

  AsciiDrawCommandKind* {.pure.} = enum
    Chars
    Box
    Buffer

  AsciiDrawCommand* = object
    zTest*: bool
    position*: Vec3i
    dimensions*: Vec2i
    beforeChildren*: bool

    case kind: AsciiDrawCommandKind
    of AsciiDrawCommandKind.Chars:
      chars*: seq[Char]
    of AsciiDrawCommandKind.Buffer:
      buffer*: ref AsciiBuffer
    of AsciiDrawCommandKind.Box:
      foreground*: RGBA
      background*: RGBA
      style*: BoxStyle
      fill*: bool
      join*: bool

  AsciiWidget* = object
    border*: AsciiWidgetBorder
    drawCommands*: seq[AsciiDrawCommand]

  AsciiImageWidget* = object
    samples*: Option[Bindable[int]]
    buffer* {.noAutoLoad.}: ref AsciiBuffer

  AsciiTextWidgetPlugin* = ref object of TextDisplayRenderer
    charsCache: Table[Widget, seq[Char]]

  AsciiImageWidgetPlugin* = ref object of WindowingComponent

  CharLine* = object
    offset*: int
    charRange*: ClosedIntRange

  CharLayout* = object
    lines*: seq[CharLine]

  BoxStyle* {.pure.} = enum
    Single
    Double
    Solid

defineDisplayReflection(AsciiGraphics)
defineDisplayReflection(AsciiWindowing)

defineDisplayReflection(AsciiWidget)
defineDisplayReflection(AsciiImageWidget)


const newlineRune = Rune 0x0000A
const spaceRune = Rune 0x00020
const zeroRune = Rune 0x00000


const allRuneInts : array[225, int] = [948,945,9524,171,9632,49,9563,9554,178,99,125,931,167,52,246,68,9561,966,51,9532,61,116,9835,176,9787,232,9644,108,98,182,181,50,101,9484,35,251,9574,118,238,255,105,64,120,9580,198,224,34,44,97,220,964,106,9492,122,191,241,9568,242,65,9578,163,8735,39,250,9516,103,8993,8734,9572,8976,46,233,9616,162,96,8252,63,243,92,9619,119,223,9660,112,8729,9786,249,60,69,235,236,9488,920,37,33,9569,234,186,9573,915,8616,9559,66,8962,121,209,9560,40,42,9579,9824,94,9600,9834,87,231,45,9571,228,9556,934,8319,54,963,9474,172,123,9794,9612,47,56,9557,9555,8801,247,110,91,9689,161,9553,183,239,237,55,9788,107,36,244,9567,9650,9575,9792,949,402,8593,9658,8597,104,189,9566,93,197,90,9496,57,165,53,960,8226,230,9608,100,9675,187,8594,102,9564,8595,111,8776,38,114,9617,117,115,32,9552,9472,9570,937,8730,201,214,9558,8359,8992,48,8592,9688,83,41,9604,9500,113,8745,170,9827,199,9830,9508,188,9668,229,62,252,8596,9829,196,9577,9576,226,9565,9562,9618,109]

const SBoxPieces : array[12, Rune] = [toRunes(" ")[0],
                                      toRunes("┌")[0], toRunes("┐")[0], toRunes("└")[0], toRunes("┘")[0],
                                      toRunes("─")[0], toRunes("│")[0], toRunes("┼")[0],
                                      toRunes("├")[0], toRunes("┤")[0], toRunes("┴")[0], toRunes("┬")[0]]

const ShadingRunes: array[4, Rune] = [toRunes("░")[0], toRunes("▒")[0],toRunes("▓")[0],toRunes("█")[0]]


# defineSimpleReadFromConfig(AsciiWidgetBorder)
proc readFromConfig*(cv: ConfigValue, b: var AsciiWidgetBorder) =
  cv["width"].readInto(b.width)
  cv["color"].readInto(b.color)
  cv["join"].readInto(b.join)
  cv["fill"].readIntoOrElse(b.fill, true)


defineSimpleReadFromConfig(AsciiImageWidget)
# defineSimpleReadFromConfig(AsciiWidget)
proc readFromConfig*(cv: ConfigValue, b: var AsciiWidget) =
  cv["border"].readInto(b.border)


proc lookupColor*(c: AsciiColorTable, color: RGBA): uint8 =
  let colorLen = c.r_colors.len.uint8
  result = c.r_colors.mgetOrPut(color, colorLen)
  if result == colorLen:
    c.colors.add(color)

proc lookupColor*(c: AsciiCanvas, color: RGBA): uint8 =
  lookupColor(c.colorTable, color)

proc `[]`*(buff: ref AsciiBuffer, x: int, y: int): Char =
  if x < 0 or y < 0 or x >= buff.dimensions.x or y >= buff.dimensions.y:
    warn &"Out of bounds read from ascii buffer: {x}, {y}"
    Char(rune: spaceRune)
  else:
    buff.buffer[x * buff.dimensions.y + y]

proc `[]=`*(buff: ref AsciiBuffer, x: int, y: int, v: Char) =
  if x < 0 or y < 0 or x >= buff.dimensions.x or y >= buff.dimensions.y:
    warn &"Out of bounds: {x}, {y}"
    writeStackTrace()
  else:
    buff.buffer[x * buff.dimensions.y + y] = v

proc swapIfZTested(v: var Char, newChar: Char) =
  if newChar.z >= v.z:
    v = newChar

proc writeZTested*(buff: ref AsciiBuffer, x: int, y: int, v: Char) =
  if x < 0 or y < 0 or x >= buff.dimensions.x or y >= buff.dimensions.y:
    warn &"Out of bounds ztested: {x}, {y}"
    writeStackTrace()
  else:
    let index = x * buff.dimensions.y + y
    swapIfZTested(buff.buffer[index], v)

proc writeColZTested*(buff: ref AsciiBuffer, x,y: int, height: int, v: Char) =
  if x < 0 or y < 0 or x >= buff.dimensions.x or y + height >= buff.dimensions.y:
    warn &"Out of bounds col ztested: {x}, {y}"
    writeStackTrace()
  else:
    let index = x * buff.dimensions.y + y
    for i in 0 ..< height:
      swapIfZTested(buff.buffer[index + i], v)

proc effectiveBounds(c: AsciiCanvas): Recti =
  if c.boundsStack.isEmpty:
    recti(0,0,c.buffer.dimensions.x, c.buffer.dimensions.y)
  else:
    c.boundsStack.last


proc writeColZTested*(c: AsciiCanvas, x,y: int, height: int, v: Char) =
  let bounds = effectiveBounds(c)
  if x >= bounds.x and x < bounds.x + bounds.width:
    var ex = x
    var ey = y
    var eh = height
    if bounds.y > ey:
      eh -= bounds.y - ey
      ey = bounds.y
    if ey + eh > bounds.y + bounds.height:
      eh -= (ey + eh) - (bounds.y + bounds.height)

    c.buffer.writeColZTested(ex,ey,eh,v)


proc blit*(writeTo: ref AsciiBuffer,readFrom : ref AsciiBuffer) =
  if writeTo.dimensions != readFrom.dimensions:
    warn &"Cannot blit buffers of different sizes without offset: {writeTo.dimensions}, {readFrom.dimensions}"
    return

  for i in 0 ..< writeTo.dimensions.x * writeTo.dimensions.y:
    let c = readFrom.buffer[i]
    if c.rune != 0.Rune:
      writeTo.buffer[i] = c

proc blit*(writeTo: ref AsciiBuffer,readFrom : ref AsciiBuffer, readRect: Recti, writeOffset: Vec2i) =
  for x in readRect.position.x ..< readRect.position.x + readRect.dimensions.x:
    for y in readRect.position.y ..< readRect.position.y + readRect.dimensions.y:
      let c = readFrom[x,y]
      if c.rune != 0.Rune:
        writeTo[x + writeOffset.x, y + writeOffset.y] = c

proc blit*(writeTo: ref AsciiBuffer,readFrom : ref AsciiBuffer, writeOffset: Vec2i) =
  blit(writeTo, readFrom, rect(vec2i(0,0), readFrom.dimensions), writeOffset)

proc blit*(writeTo: AsciiCanvas, readFrom: ref AsciiBuffer, writeOffset: Vec2i) =
  let writeRect = intersect(rect(writeOffset, readFrom.dimensions), effectiveBounds(writeTo))
  blit(writeTo.buffer, readFrom, rect(writeRect.position - writeOffset, writeRect.dimensions), writeRect.position)


proc write*(c: AsciiCanvas, x: int, y: int, v: Char) =
  let bounds = effectiveBounds(c)
  if bounds.x <= x and bounds.y <= y and bounds.x + bounds.width > x and bounds.y + bounds.height > y:
    writeZTested(c.buffer, x, y, v)

proc write*(c: AsciiCanvas, x: int, y: int, z: int8, s: string, colorIndex: uint8 = 0) =
  let runes = toRunes(s)
  for i in 0 ..< runes.len:
    write(c, x + i, y, Char(rune: toRunes(s)[i], foreground: colorIndex, z: z))

proc write*(c: AsciiCanvas, x: int, y: int, z: int8, s: string, color: RGBA) =
  let colorIndex = lookupColor(c, color)
  write(c, x, y, z, s, colorIndex)

proc pushBounds*(c: AsciiCanvas, bounds: Recti) =
  c.boundsStack.add(bounds)

## push new bounds that narrow the existing bounds
proc pushNarrowBounds*(c: AsciiCanvas, bounds: Recti) =
  let cur = effectiveBounds(c)
  pushBounds(c, intersect(cur, bounds))

proc popBounds*(c: AsciiCanvas) =
  if c.boundsStack.isEmpty:
    warn &"Trying to pop empty bounds stack"
  else:
    c.boundsStack.setLen(c.boundsStack.len - 1)

proc equalContents*(a: ref AsciiBuffer, b: ref AsciiBuffer) : bool =
  if a.isNil or b.isNil: false
  elif a.dimensions != b.dimensions: false
  elif a.dimensions.x <= 0 or a.dimensions.y <= 0: true
  else: cmpMem(a.buffer[0].addr, b.buffer[0].addr, a.dimensions.x * a.dimensions.y * sizeof(Char)) == 0


proc clear*(buff: ref AsciiBuffer) =
  zeroMem(buff.buffer[0].addr, buff.dimensions.x * buff.dimensions.y * sizeof(Char))

proc clear*(c: AsciiCanvas) =
  c.buffer.clear()
  c.revision.inc

proc newAsciiBuffer*(width: int, height: int) : ref AsciiBuffer =
  result = new AsciiBuffer
  result.dimensions = vec2i(width,height)
  result.buffer.setLen(width * height)

proc addRuneInfo(gfx: AsciiCanvas, r: Rune, info: RuneInfo) =
  if gfx.runeInfo.len <= r.int32:
    gfx.runeInfo.setLen(r.int32+1)
  gfx.runeInfo[r.int32] = info

proc instantiateRuneInfo(gfx: AsciiCanvas, arr: array[12, Rune], doubleHoriz, doubleVert: bool) =
  for e in BoxPieces:
    if e != BoxPieces.None:
      addRuneInfo(gfx, arr[e.ord], RuneInfo(boxPiece: e, doubleVertical: doubleVert, doubleHorizontal: doubleHoriz))

proc instantiateRuneInfo(gfx: AsciiCanvas) =
  instantiateRuneInfo(gfx, SBoxPieces, false, false)


proc newCanvas*(gfx: ref AsciiGraphics) : AsciiCanvas =
  result = AsciiCanvas(
    buffer: newAsciiBuffer(gfx.buffer.dimensions.x, gfx.buffer.dimensions.y),
    resized: false,
    revision: 0,
    renderedRevision: 0,
    colorTable: gfx.colorTable
  )
  instantiateRuneInfo(result)
  gfx.canvases.add(result)


proc runeInfo*(g: AsciiCanvas, r: Rune) : RuneInfo =
  if g.runeInfo.len > r.int32:
    g.runeInfo[r.int32]
  else:
    RuneInfo()

proc runeInfo*(g: AsciiCanvas, x: int, y: int): RuneInfo =
  runeInfo(g, g.buffer[x,y].rune)


proc boxPiecesToConnections(b: BoxPieces): array[4,uint8] =
  case b: # left, right, down, up
    of BoxPieces.TopLeft: [0u8,1u8,1u8,0u8]
    of BoxPieces.TopRight: [1u8,0u8,1u8,0u8]
    of BoxPieces.BottomLeft: [0u8,1u8,0u8,1u8]
    of BoxPieces.BottomRight: [1u8,0u8,0u8,1u8]
    of BoxPieces.Horizontal: [1u8,1u8,0u8,0u8]
    of BoxPieces.Vertical: [0u8,0u8,1u8,1u8]
    of BoxPieces.Cross: [1u8,1u8,1u8,1u8]
    of BoxPieces.RightJoin: [0u8,1u8,1u8,1u8]
    of BoxPieces.LeftJoin: [1u8,0u8,1u8,1u8]
    of BoxPieces.TopJoin: [1u8,1u8,0u8,1u8]
    of BoxPieces.BottomJoin: [1u8,1u8,1u8,0u8]
    of BoxPieces.None: [0u8,0u8,0u8,0u8]
    
proc connectionsToBoxPieces(conn: array[4,uint8]) : BoxPieces =
  # case (conn[0] | (conn[1] << 2) | (conn[2] << 4) | (conn[3] << 8):
  if conn == [0u8,1u8,1u8,0u8]: BoxPieces.TopLeft
  elif conn == [1u8,0u8,1u8,0u8]: BoxPieces.TopRight
  elif conn == [0u8,1u8,0u8,1u8]: BoxPieces.BottomLeft
  elif conn == [1u8,0u8,0u8,1u8]: BoxPieces.BottomRight
  elif conn == [1u8,1u8,0u8,0u8]: BoxPieces.Horizontal
  elif conn == [0u8,0u8,1u8,1u8]: BoxPieces.Vertical
  elif conn == [1u8,1u8,1u8,1u8]: BoxPieces.Cross
  elif conn == [0u8,1u8,1u8,1u8]: BoxPieces.RightJoin
  elif conn == [1u8,0u8,1u8,1u8]: BoxPieces.LeftJoin
  elif conn == [1u8,1u8,0u8,1u8]: BoxPieces.TopJoin
  elif conn == [1u8,1u8,1u8,0u8]: BoxPieces.BottomJoin
  else: BoxPieces.None

proc dimensions*(c: AsciiCanvas) :Vec2i = c.buffer.dimensions

proc joinChar(c : AsciiCanvas, x : int, y : int, z: int8, boxPiece: BoxPieces, colorIndex: uint8) =
  let bounds = effectiveBounds(c)
  if x >= bounds.x and y >= bounds.y and x < bounds.x + bounds.width and y < bounds.y + bounds.height:
    let cur = c.buffer[x,y]
    let info = runeInfo(c, cur.rune)

    let curConn = boxPiecesToConnections(info.boxPiece)
    let addConn = boxPiecesToConnections(boxPiece)
    let effPiece = connectionsToBoxPieces([max(curConn[0],addConn[0]), max(curConn[1],addConn[1]), max(curConn[2],addConn[2]), max(curConn[3],addConn[3])])

    write(c, x, y, Char(rune: SBoxPieces[effPiece.ord], foreground: colorIndex, z: z))


proc drawBox*(c: AsciiCanvas, x,y,z: int, width: int, height: int, color: RGBA, fill: bool, join: bool = true, boxStyle: BoxStyle = BoxStyle.Single) =
  let farX = x + width - 1
  let farY = y + height - 1
  let colorIndex = c.lookupColor(color)

  if join:
    joinChar(c, x, y, z.int8, BoxPieces.TopLeft, colorIndex)
    joinChar(c, farx, y, z.int8, BoxPieces.TopRight, colorIndex)
    joinChar(c, farx, fary, z.int8, BoxPieces.BottomRight, colorIndex)
    joinChar(c, x, fary, z.int8, BoxPieces.BottomLeft, colorIndex)
  else:
    c.write(x,y, Char(rune: SBoxPieces[BoxPieces.TopLeft.ord], foreground: colorIndex, z: z.int8))
    c.write(farX,y, Char(rune: SBoxPieces[BoxPieces.TopRight.ord], foreground: colorIndex, z: z.int8))
    c.write(farx,fary, Char(rune: SBoxPieces[BoxPieces.BottomRight.ord], foreground: colorIndex, z: z.int8))
    c.write(x,fary, Char(rune: SBoxPieces[BoxPieces.BottomLeft.ord], foreground: colorIndex, z: z.int8))

  for ax in x+1 ..< farx:
    if join:
      joinChar(c, ax, y, z.int8, BoxPieces.Horizontal, colorIndex)
      joinChar(c, ax, fary, z.int8, BoxPieces.Horizontal, colorIndex)
    else:
      c.write(ax,y, Char(rune: SBoxPieces[BoxPieces.Horizontal.ord], foreground: colorIndex, z: z.int8))
      c.write(ax,fary, Char(rune: SBoxPieces[BoxPieces.Horizontal.ord], foreground: colorIndex, z: z.int8))

  for ay in y+1 ..< fary:
    if join:
      joinChar(c, x, ay, z.int8, BoxPieces.Vertical, colorIndex)
      joinChar(c, farx, ay, z.int8, BoxPieces.Vertical, colorIndex)
    else:
      c.write(x,ay, Char(rune: SBoxPieces[BoxPieces.Vertical.ord], foreground: colorIndex, z: z.int8))
      c.write(farx,ay, Char(rune: SBoxPieces[BoxPieces.Vertical.ord], foreground: colorIndex, z: z.int8))

  if fill:
    let bw = 1
    for dx in bw ..< width - bw:
      # TODO: actual background colors
      writeColZTested(c, x + dx, y + bw, height - bw * 2, Char(rune: spaceRune, z : z.int8))

  c.revision.inc



proc render(g: AsciiCanvasComponent, world: LiveWorld, display: DisplayWorld) =
  let gfx : ref AsciiGraphics = display[AsciiGraphics]
  clear(gfx.buffer)

  gfx.canvases = gfx.canvases.sortedByIt(it.drawPriority * -1)
  for canvas in gfx.canvases:
    blit(gfx.buffer, canvas.buffer)

  let size = gfx.charDimensions
  let sizef = vec3f(size.x, size.y, 0)
  let f : ArxFont = font(gfx.typeface, size.y)


  var ii,vi = 0

  let blankTC = g.texture.blankTexCoords

  var scale = case g.camera.kind:
    of CameraKind.WindowingCamera: g.camera.windowingScale
    else: 1
  let gcd = display[GraphicsContextData]


  for x in 0 ..< gfx.buffer.dimensions.x:
    for y in 0 ..< gfx.buffer.dimensions.y:
      let c = gfx.buffer[x,y]
      if c.rune != 0.Rune:
        let tc = g.texture[glyphImage(f, c.rune)]
        if c.background != 0u8:
          for q in 0 ..< 4:
            let vt = g.vao[vi+q]
            vt.vertex = vec3f(x * size.x,y * size.y,0) + UnitSquareVertices[q] * sizef
            vt.color = gfx.colorTable.colors[c.background]
            vt.texCoords = blankTC[q]
          g.vao.addIQuad(ii, vi)
        for q in 0 ..< 4:
          let vt = g.vao[vi+q]
          vt.vertex = vec3f(x * size.x,y * size.y,0) + UnitSquareVertices[q] * sizef
          vt.color = gfx.colorTable.colors[c.foreground]
          vt.texCoords = tc[q]
        g.vao.addIQuad(ii, vi)

  g.vao.swap()


method update(g: AsciiCanvasComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let gfx : ref AsciiGraphics = display[AsciiGraphics]

  var modified = false
  for canvas in gfx.canvases:
    if canvas.revision > canvas.renderedRevision:
      modified = true

  if modified:
    render(g, world, display)
    for canvas in gfx.canvases:
      canvas.revision = canvas.renderedRevision

  @[draw(g.vao, g.shader, @[g.texture], g.camera)]


# ┌-┐
# | |

# proc onChanged(v: AsciiTextWidget) =
#   v.revision.inc
#
# template getterSetter(obj: untyped, t: untyped): untyped {.dirty.} =
#   proc `t=`*(w: `obj`, value: typeof(`obj`.`t`)) =
#     if w.`t` != value:
#       onChanged(w)
#       w.`t` = value
#
#   proc `t`*(w: `obj`): typeof(`obj`.`t`) = w.`t`



proc sampleImage(img: Image, x,y: float32) : RGBA =
  let xi = (x * img.width.float32).int32.min(img.width-1)
  let yi = (y * img.height.float32).int32.min(img.height-1)
  img[xi,img.height - 1 - yi][]


proc pickPrimaryAndSecondaryColor(img: Image, x: float32, y: float32, w: float32, h: float32) : (RGBA, Option[RGBA]) =
  var sumByColor: seq[(RGBA, int)]

  let startPixelX = x * img.width.float32
  let startPixelY = y * img.height.float32
  let endPixelX = (x + w) * img.width.float32
  let endPixelY = (y + h) * img.height.float32

  var px = startPixelX
  while px < endPixelX:
    var py = startPixelY
    while py < endPixelY:
      let sample = img[min(px.int32, img.width-1), img.height - 1 - min(py.int32, img.height - 1)]
      var found = false
      for i in 0 ..< sumByColor.len:
        if sumByColor[i][0] == sample[]:
          sumByColor[i][1].inc
          found = true
      if not found:
        sumByColor.add((sample[], 1))
      py = py + 1.0f32
    px = px + 1.0f32

  if sumByColor.len > 1:
    sumByColor.sort((a,b) => cmp(-a[1],-b[1]))
    (sumByColor[0][0], some(sumByColor[1][0]))
  else:
    (sumByColor[0][0], none(RGBA))





type BitPattern = object
  values: array[2, uint64]

proc setBit(b: var BitPattern, i: int) =
  let vi = i shr 6
  setBit(b.values[vi], bitand(i, 63))

proc difference(a: BitPattern, b: BitPattern) : int =
  countSetBits(bitxor(a.values[0], b.values[0])) + countSetBits(bitxor(a.values[1], b.values[1]))


proc imgToBitPattern(img: Image) : BitPattern =
  var i = 0

  for x in 0 ..< img.width:
    for y in 0 ..< img.height:
      if img[x,y][].a > 0:
        setBit(result, i)
      i.inc


var runeBitPatterns {.threadvar.}: seq[BitPattern]

proc imageToAscii*(buff: ref AsciiBuffer, gfx: ref AsciiGraphics, img: Image, outDim: Vec2i, outPos: Vec3i) =
  if runeBitPatterns.isEmpty:
    let f = font(gfx.typeface, gfx.baseCharDimensions.y)
    for i in 0 ..< allRuneInts.len:
      let gImg = glyphImage(f, allRuneInts[i].Rune)
      let bp = imgToBitPattern(gImg)
      runeBitPatterns.add(bp)


  var sampleCounts: seq[(RGBA,int)]

  let xdf = (1f32 / outDim.x.float32) / (gfx.baseCharDimensions.x).float32
  let ydf = (1f32 / outDim.y.float32) / (gfx.baseCharDimensions.y).float32

  let subpixelDim = vec2i(outDim.x * gfx.baseCharDimensions.x, outDim.y * gfx.baseCharDimensions.y)

  for x in 0 ..< outDim.x:
    for y in 0 ..< outDim.y:
      let subX = x * gfx.baseCharDimensions.x
      let subY = y * gfx.baseCharDimensions.y

      let xf = x.float32 / outDim.x.float32
      let yf = y.float32 / outDim.y.float32

      let (primary, secondaryOpt) = pickPrimaryAndSecondaryColor(img, xf, yf, 1f32 / outDim.x.float32, 1f32 / outDim.y.float32)

      let (r, invert) = if secondaryOpt.isNone:
        (ShadingRunes[3], false)
      else:
        var targetPattern : BitPattern
        var i = 0
        for charX in 0 ..< gfx.baseCharDimensions.x:
          for charY in 0 ..< gfx.baseCharDimensions.y:
            let sample = sampleImage(img, (subX + charX).float32 / subpixelDim.x.float32, (subY + charY).float32 / subpixelDim.y.float32)
            if sample == primary:
              setBit(targetPattern, i)
            i.inc

        var bestRune : Rune = ShadingRunes[0]
        let maxError = (gfx.baseCharDimensions.x * gfx.baseCharDimensions.y).int
        var bestError = maxError
        var invert: bool
        for rIndex in 0 ..< allRuneInts.len:
          let r = allRuneInts[rIndex].Rune
          if r == ShadingRunes[3]: continue
          var error = difference(targetPattern, runeBitPatterns[rIndex])

          if error < bestError:
            bestError = error
            bestRune = r
            invert = false
          elif (maxError - error) < bestError:
            bestError = (maxError - error)
            bestRune = r
            invert = true

        (bestRune, invert)

      let secIndex = secondaryOpt.map((it) => lookupColor(gfx.colorTable, it)).get(0u8)
      let priIndex = lookupColor(gfx.colorTable, primary)
      let foreground = if invert: secIndex else: priIndex
      let background = if invert: priIndex else: secIndex
      buff[x, y] = Char(rune: r, foreground: foreground, background: background, z: outPos.z.int8)



proc layout(runes: seq[Rune], minDim: Vec2i, maxDim: Vec2i,  multiLine: bool, hAlign: HorizontalAlignment): seq[(int, main_core.ClosedIntRange)] =
  result = @[]
  let cWidth = maxDim.x
  let cHeight = maxDim.y

  var lines: seq[ClosedIntRange]
  if cWidth > 0:
    if not multiLine:
      let runeLen = runes.len
      lines.add(0 ..< min(cWidth, runes.len))
    else:
      var lstart : int = 0
      var i : int
      while i < runes.len and lines.len < cHeight:
        let r = runes[i]
        if r == newlineRune:
          lines.add(lstart ..< i)
          lstart = i+1
        elif i - lstart >= cWidth:
          lines.add(lstart ..< i)
          lstart = i

        i.inc

      if lines.len < cHeight and lstart < runes.len:
        lines.add(lstart ..< runes.len)

    for l in lines:
      case hAlign:
        of HorizontalAlignment.Left:
          result.add((0, l))
        of HorizontalAlignment.Right:
          result.add(( cWidth - l.width, l))
        of HorizontalAlignment.Center:
          result.add(( (cWidth - l.width) div 2, l))

method onEvent*(g: AsciiCanvasComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  discard



method initialize(g: AsciiCanvasComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "AsciiCanvasComponent"
  g.initializePriority = 100
  g.updatePriority = 100
  g.vao = newVAO[SimpleVertex, uint32]()
  g.shader = initShader("shaders/simple")
  g.texture = newTextureBlock(1024, 1, false)
  g.camera = createWindowingCamera(1)

  let gcd : ref GraphicsContextData = display[GraphicsContextData]
  let baseSize = 16
  let size = 40
  # let typeface = loadArxTypeface("resources/fonts/Px437_SanyoMBC775.ttf")
  # let typeface = loadArxTypeface("resources/fonts/Px437_Acer710_Mono.ttf")
  # let typeface = loadArxTypeface("resources/fonts/Px437_ToshibaSat_8x16.ttf")
  let typeface = loadArxTypeface("resources/fonts/Px437_SanyoMBC775-2y.ttf")
  let f : ArxFont = font(typeface, size)
  let boxImg = glyphImage(f, toRunes("█")[0])

  let charDims = boxImg.dimensions

  let baseCharDims = glyphImage(font(typeface, baseSize), toRunes("█")[0]).dimensions
  display.attachData(
    AsciiGraphics(
      baseCharDimensions: baseCharDims,
      charDimensions: charDims,
      buffer: newAsciiBuffer(gcd.framebufferSize.x div charDims.x, gcd.framebufferSize.y div charDims.y),
      colorTable: AsciiColorTable(),
      typeface: typeface,
      font: f
    )
  )
  info &"Effective resolution: {gcd.framebufferSize.x div size}x{gcd.framebufferSize.y div size}"



proc handleEventWrapper(ws: WindowingSystemRef, event: WidgetEvent, world: LiveWorld, display: DisplayWorld) : bool =
  result = handleEvent(ws, event, world, display)
  if not result:
    display.addEvent(event)

method onEvent*(g: AsciiWindowingSystemComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  let gcd = display[GraphicsContextData]
  let ws = display[WindowingSystem]
  let agfx = display[AsciiGraphics]

  proc pixelToWorld(px: Vec2f): Vec2f =
    let pxf = px.x / gcd.windowSize.x.float32
    let pyf = px.y / gcd.windowSize.y.float32
    vec2f((pxf * agfx.buffer.dimensions.x.float32).round.int32, (pyf * agfx.buffer.dimensions.y.float32).round.int32)

  ifOfType(UIEvent, event):
    ifOfType(WidgetEvent, event):
      if handleEvent(ws, event, world, display):
        event.consume()
    var shouldConsume = false
    matchType(event):
      extract(MouseMove, position, modifiers):
        let wsPos = pixelToWorld(position)
        ws.lastMousePosition = wsPos.xy
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseMove(widget: widget, position: wsPos.xy, modifiers: modifiers), world, display)
      extract(MouseDrag, position, button, modifiers, origin):
        let wsPos = pixelToWorld(position)
        let wsOrigin = pixelToWorld(origin)
        ws.lastMousePosition = wsPos.xy
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseDrag(widget: widget, position: wsPos.xy, origin: wsOrigin.xy, button: button, modifiers: modifiers), world, display)
      extract(MousePress, position, button, modifiers, doublePress):
        let wsPos = pixelToWorld(position)
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMousePress(widget: widget, position: wsPos.xy, modifiers: modifiers, doublePress: doublePress), world, display)
      extract(MouseRelease, position, button, modifiers):
        let wsPos = pixelToWorld(position)
        var widget = ws.widgetAtPosition(wsPos.xy)
        shouldConsume = handleEventWrapper(ws, WidgetMouseRelease(widget: widget, position: wsPos.xy, modifiers: modifiers), world, display)
      extract(KeyPress, key, repeat, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetKeyPress(widget: widget, key: key, repeat: repeat, modifiers: modifiers), world, display)
      extract(KeyRelease, key, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetKeyRelease(widget: widget, key: key, modifiers: modifiers), world, display)
      extract(RuneEnter, rune, modifiers):
        if ws.focusedWidget.isSome:
          let widget = ws.focusedWidget.get
          shouldConsume = handleEventWrapper(ws, WidgetRuneEnter(widget: widget, rune: rune, modifiers: modifiers), world, display)
    if shouldConsume:
      event.consume()




      
method initialize(g: AsciiWindowingSystemComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "AsciiWindowingSystemComponent"
  g.initializePriority = 50
  g.updatePriority = 50

  let gfx = display[AsciiGraphics]
  let canvas = newCanvas(gfx)
  let clearIndex = canvas.lookupColor(rgba(255,255,255,0))

  let windowingSystem = createWindowingSystemWithCustomRenderer(display, ProjectName & "/widgets/", AsciiWidgetPlugin(), noDefaultComponents = true)
  windowingSystem.pixelScale = 1
  windowingSystem.components.add(AsciiTextWidgetPlugin())
  windowingSystem.components.add(ListWidgetComponent())
  windowingSystem.components.add(AsciiImageWidgetPlugin())
  windowingSystem.desktop.width = fixedSize(canvas.dimensions.x)
  windowingSystem.desktop.height = fixedSize(canvas.dimensions.y)
  windowingSystem.desktop.attachData(AsciiWidget(border: AsciiWidgetBorder(width: bindable(1), fill: true)))
  display.attachDataRef(windowingSystem)

  display.attachData(AsciiWindowing(canvas: canvas))



proc renderWidgetToCanvas(widget: Widget, canvas: AsciiCanvas, beforeChildren: bool) =
  let aw = widget.data(AsciiWidget)
  for comm in aw.drawCommands:
    if comm.beforeChildren == beforeChildren:
      case comm.kind:
        of AsciiDrawCommandKind.Box:
          drawBox(canvas, comm.position.x, comm.position.y, comm.position.z, comm.dimensions.x, comm.dimensions.y, comm.foreground, comm.fill, join = comm.join)
        of AsciiDrawCommandKind.Chars:
          for i in 0 ..< comm.chars.len:
            write(canvas, comm.position.x + i, comm.position.y, comm.chars[i])
        of AsciiDrawCommandKind.Buffer:
          blit(canvas, comm.buffer, comm.position.xy)

proc renderWidget(widget: Widget, canvas: AsciiCanvas) =
  if widget.showing:
    renderWidgetToCanvas(widget, canvas, true)
    pushNarrowBounds(canvas, rect(widget.resolvedPosition.xy + widget.clientOffset.xy, widget.resolvedDimensions.xy - widget.clientOffset.xy * 2))
    for c in widget.children.sortedByIt(it.resolvedPosition.z):
      renderWidget(c, canvas)
    popBounds(canvas)
    renderWidgetToCanvas(widget, canvas, false)

method update(g: AsciiWindowingSystemComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let ws = display[WindowingSystem]
  if ws.update(nil, world, display):
    let asciiWS = display[AsciiWindowing]
    asciiWS.canvas.clear()
    renderWidget(ws.desktop, asciiWS.canvas)


method customRender*(ws: AsciiWidgetPlugin, display: DisplayWorld, widget: Widget, tb: TextureBlock, bounds: Bounds) =
  if not widget.hasData(AsciiWidget):
    warn &"Widget did not have ascii data: {widget.identifier}"

  let ascii = widget.data(AsciiWidget)
  ascii.drawCommands.clear()
  let border = ascii.border
  if border.width.value > 0:
    let pos = widget.resolvedPosition
    let dim = widget.resolvedDimensions
    let color = if border.color.isSome:
      border.color.get.value
    else:
      White
    # drawBox(display[AsciiWindowing].canvas, pos.x, pos.y, pos.z, dim.x, dim.y, color, false)
    ascii.drawCommands.add(AsciiDrawCommand(kind: AsciiDrawCommandKind.Box, position: pos, dimensions: dim, foreground: color, fill: border.fill, beforeChildren: true, join: border.join))


method clientOffset*(ws: AsciiWidgetPlugin, widget: Widget, axis: Axis): Option[Vec3i] =
  let bw = widget.data(AsciiWidget).border.width.value
  some(vec3i(bw, bw, 0))

method intrinsicSize*(ws: AsciiWidgetPlugin, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] =
  none(int)

method readDataFromConfig*(ws: AsciiWidgetPlugin, cv: ConfigValue, widget: Widget) =
  if not widget.hasData(AsciiWidget):
    widget.attachData(AsciiWidget())
  readInto(cv, widget.data(AsciiWidget)[])

method updateBindings*(ws: AsciiWidgetPlugin, widget: Widget, resolver: var BoundValueResolver) =
  let w = widget.data(AsciiWidget)
  if updateBindings(w.border, resolver):
    markForUpdate(widget, RecalculationFlag.Contents)

method handleEvent*(ws: AsciiWidgetPlugin, widget: Widget, event: UIEvent, display: DisplayWorld) =
  discard

method onCreated*(ws: AsciiWidgetPlugin, widget: Widget) =
  if not widget.hasData(AsciiWidget):
    widget.attachData(AsciiWidget())




method customRender*(ws: AsciiImageWidgetPlugin, display: DisplayWorld, widget: Widget, tb: TextureBlock, bounds: Bounds) =
  if widget.hasData(ImageDisplay):
    let ID = widget.data(ImageDisplay)
    let AIW = widget.data(AsciiImageWidget)
    let gfx = display[AsciiGraphics]
    let ascii = widget.data(AsciiWidget)

    let img = ID.effectiveImage.asImage
    if img.modifiedOnDisk:
      img.reloadImage()
    let pos = widget.resolvedPosition + widget.clientOffset
    let contentDim = (widget.resolvedDimensions - widget.clientOffset.xy * 2)
    let contentPixelDim = contentDim * gfx.baseCharDimensions
    let xRatio = contentPixelDim.x.float32 / img.width.float32
    let yRatio = contentPixelDim.y.float32 / img.height.float32
    let ratio = min(xRatio, yRatio)
    let finalPixelDim = vec2f(img.width.float32 * ratio, img.height.float32 * ratio)
    let asciiDim = vec2i((finalPixelDim.x / gfx.baseCharDimensions.x.float32).int32, (finalPixelDim.y / gfx.baseCharDimensions.y.float32).int32)

    let offset = (contentDim - asciiDim) div 2

    if AIW.buffer.isNil or AIW.buffer.dimensions != asciiDim:
      AIW.buffer = newAsciiBuffer(asciiDim.x, asciiDim.y)

    imageToAscii(AIW.buffer, gfx, img, asciiDim, vec3i(0,0,pos.z))
    ascii.drawCommands.add(AsciiDrawCommand(kind: AsciiDrawCommandKind.Buffer, buffer: AIW.buffer, position: pos + vec3i(offset,0), dimensions: asciiDim))

method readDataFromConfig*(g: AsciiImageWidgetPlugin, cv: ConfigValue, widget: Widget) =
  if cv["type"].asStr("").toLowerAscii == "imagedisplay":
    if not widget.hasData(ImageDisplay):
      var td: ImageDisplay
      readFromConfig(cv, td)
      widget.attachData(td)
    else:
      readFromConfig(cv, widget.data(ImageDisplay)[])

    if not widget.hasData(AsciiImageWidget):
      widget.attachData(AsciiImageWidget())
    cv.readInto(widget.data(AsciiImageWidget)[])

method updateBindings*(g: AsciiImageWidgetPlugin, widget: Widget, resolver: var BoundValueResolver) =
  if (widget.hasData(ImageDisplay) and updateAllBindings(widget.data(ImageDisplay)[], resolver)) or
      (widget.hasData(AsciiImageWidget) and updateBindings(widget.data(AsciiImageWidget)[], resolver)):
    widget.markForUpdate(RecalculationFlag.Contents)


proc lookupColor(w: Widget, color: RGBA): uint8 =
  w.windowingSystem.display[AsciiWindowing].canvas.lookupColor(color)


proc updateCharsFor(w: Widget, td: ref TextDisplay) : seq[Char] =
  let txt = td.effectiveText
  var chars: seq[Char]

  proc addTextForSection(str: string, color: RGBA) =
    let colorIndex = lookupColor(w, color)
    let rs = toRunes(str)
    for r in rs:
      chars.add(Char(rune: r, foreground: colorIndex))

  for section in txt.sections:
    var effColor = rgba(1.0f, 1.0f, 1.0f, 1.0f)

    if section.color.isSome:
      effColor = section.color.get
    elif td.color.isSome:
      effColor = td.color.get.value

    if txt.tint.isSome:
      effColor = mix(effColor, txt.tint.get, 0.5)
    if td.tintColor.isSome:
      effColor = mix(effColor, td.tintColor.get, 0.5)

    case section.kind:
      of SectionKind.Image: warn &"Images are unsupported in ascii rich text"
      of SectionKind.Taxon:
        addTextForSection(section.taxon.displayName, effColor)
      of SectionKind.EnsureSpacing: warn &"Ensure spacing is unsupported in ascii rich text"
      of SectionKind.VerticalBreak:
        addTextForSection("\n", effColor)
      of SectionKind.Text:
        # TODO: format ranges
        addTextForSection(section.text, effColor)

  chars

proc charsFor(g: AsciiTextWidgetPlugin, w: Widget, td: ref TextDisplay): seq[Char] =
  g.charsCache.getOrCreate(w):
    updateCharsFor(w, td)

proc dimensions*(l: CharLayout): Vec2i =
  var maxX = 0
  for line in l.lines:
    maxX = max(maxX, line.charRange.width + line.offset)
  vec2i(maxX, l.lines.len)

proc layoutChars(chars: seq[Char], multiLine: bool, maxDims: Vec2i, hAlign: HorizontalAlignment) : CharLayout =
  let cWidth = maxDims.x
  let cHeight = maxDims.y
  if cWidth > 0:
    if not multiLine:
      let runeLen = chars.len
      result.lines.add(CharLine(offset: 0, charRange: 0 ..< min(cWidth, chars.len)))
    else:
      var lines : seq[ClosedIntRange]
      var lstart : int = 0
      var lastBreakPoint : int = 0
      var i : int
      while i < chars.len and lines.len < cHeight:
        let r = chars[i].rune
        if r == newlineRune:
          lines.add(lstart ..< i)
          lstart = i+1
        else:
          if isWhiteSpace(r):
            lastBreakPoint = i

          if i - lstart >= cWidth :
            if lastBreakPoint > lstart:
              lines.add(lstart ..< lastBreakPoint)
              i = lastBreakPoint
              lstart = lastBreakPoint+1
            else:
              lines.add(lstart ..< i)
              lstart = i



        i.inc

      if lines.len < cHeight and lstart < chars.len:
        lines.add(lstart ..< chars.len)

      for l in lines:
        case hAlign:
          of HorizontalAlignment.Left:
            result.lines.add(CharLine(offset: 0, charRange: l))
          of HorizontalAlignment.Right:
            result.lines.add(CharLine(offset: cWidth - l.width, charRange: l))
          of HorizontalAlignment.Center:
            result.lines.add(CharLine(offset: (cWidth - l.width) div 2, charRange: l))


method intrinsicSize*(g: AsciiTextWidgetPlugin, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] =
  if widget.hasData(TextDisplay):
    let td : ref TextDisplay = widget.data(TextDisplay)

    var maxDims = maximums
    if not widget.width.isIntrinsic:
      maxDims.x = min(maxDims.x, widget.resolvedDimensions.x - widget.clientOffset.x * 2)

    let layout = layoutChars(charsFor(g, widget, td), td.multiLine, maxDims, HorizontalAlignment.Left)
    some(max(dimensions(layout)[axis], minimums[axis]))
  else:
    none(int)

method updateBindings*(g: AsciiTextWidgetPlugin, widget: Widget, resolver: var BoundValueResolver) =
  if widget.hasData(TextDisplay):
    procCall updateBindings(TextDisplayRenderer(g), widget, resolver)
    if isMarkedForUpdate(widget, RecalculationFlag.Contents):
      g.charsCache[widget] = updateCharsFor(widget, widget.data(TextDisplay))


method customRender*(g: AsciiTextWidgetPlugin, display: DisplayWorld, widget: Widget, tb: TextureBlock, bounds: Bounds) =
  if widget.hasData(TextDisplay):
    let ascii = widget.data(AsciiWidget)
    let c : AsciiCanvas = display[AsciiWindowing].canvas
    let td = widget.data(TextDisplay)

    let chars = charsFor(g, widget, td)
    let co = widget.clientOffset
    let dimensions = widget.resolvedDimensions - co.xy * 2
    let layout = layoutChars(chars, td.multiLine, dimensions, td.horizontalAlignment.get(HorizontalAlignment.Left))

    let position = widget.resolvedPosition + co

    for lineNumber in 0 ..< layout.lines.len:
      let line = layout.lines[lineNumber]
      var ax = position.x
      let ay = position.y + lineNumber

      let endOffset = line.offset
      let endText = endOffset + line.charRange.width
      let endContent = dimensions.x

      var lineChars: seq[Char]
      for i in 0 ..< endContent:
        var r = if i < endOffset: Char(rune: spaceRune)
        elif i < endText: chars[line.charRange.min + i - endOffset]
        else: Char(rune: spaceRune)
        r.z = position.z.int8
        lineChars.add(r)
      ascii.drawCommands.add(AsciiDrawCommand(kind: AsciiDrawCommandKind.Chars, position: vec3i(ax, ay, position.z), dimensions: vec2i(chars.len,1), chars: lineChars, beforeChildren: false))
    c.revision.inc
