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


type
  Char* = object
    rune*: Rune
    foreground*: uint8
    background*: uint8
    z*: int8

  AsciiBuffer* = object
    dimensions*: Vec2i
    buffer: seq[Char]

  AsciiCanvas* = ref object
    buffer*: ref AsciiBuffer
    resized*: bool
    revision*: int
    renderedRevision: int
    drawPriority*: int
    runeInfo: seq[RuneInfo]
    colors: ref seq[RGBA]
    r_colors: ref Table[RGBA, uint8]

  AsciiGraphics* = object
    buffer*: ref AsciiBuffer
    colors: ref seq[RGBA]
    r_colors: ref Table[RGBA, uint8]
    typeface*: ArxTypeface
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

  AsciiWindowingSystem* = ref object of GraphicsComponent
    texture: TextureBlock

  AsciiWindowing* = object
    canvas*: AsciiCanvas
    textWidgets: Table[AsciiWidgetId, (AsciiTextWidget, AsciiWidgetState)]
    textWidgetsByZ: seq[AsciiTextWidget]

  AsciiWidgetState = object
    renderedRevision: uint64

  AsciiWindowingComponent* = ref object of WindowingComponent

  AsciiWidgetBorder* = object
    kind*: AsciiWidgetBorderKind
    color*: RGBA
    join*: bool

  AsciiWidgetBorderKind* {.pure.} = enum
    SingleBorder
    DoubleBorder
    NoBorder

  AsciiWidgetIdKind* {.pure.} = enum
    Int
    String
    Taxon

  AsciiWidgetId* = object
    case kind*: AsciiWidgetIdKind
    of AsciiWidgetIdKind.Int:
      id*: int
    of AsciiWidgetIdKind.String:
      name*: string
    of AsciiWidgetIdKind.Taxon:
      taxon*: Taxon

  AsciiWidgetKind* {.pure.} = enum
    Text
    List

  AsciiTextWidget* = ref object
    id*: AsciiWidgetId
    parent: Option[AsciiTextWidget]
    z: int
    position: Vec2i
    maxDimensions: Vec2i
    minDimensions: Vec2i
    border: AsciiWidgetBorder
    runes : seq[Rune]
    textAlignment: HorizontalAlignment
    multiLine: bool
    data*: BoundValue
    revision: uint64
    # case kind*: AsciiWidgetKind
    #   of AsciiWidgetKind.Text:
    text : string
    textColor: RGBA
      # of AsciiWidgetKind.List:
      #   i_listItems: seq[AsciiTextWidget]


  BindableAsciiWidgetBorder* = object
    width*: Bindable[int]
    color*: Bindable[RGBA]
    join*: bool

  AsciiWidget* = object
    border*: BindableAsciiWidgetBorder

  AsciiTextWidgetComponent* = ref object of TextDisplayRenderer
    charsCache: Table[Widget, seq[Char]]

  CharLine* = object
    offset*: int
    charRange*: ClosedIntRange

  CharLayout* = object
    lines*: seq[CharLine]

defineDisplayReflection(AsciiGraphics)
defineDisplayReflection(AsciiWindowing)

defineDisplayReflection(AsciiWidget)


const newlineRune = Rune 0x0000A
const spaceRune = Rune 0x00020

const SBoxPieces : array[12, Rune] = [toRunes(" ")[0],
                                      toRunes("┌")[0], toRunes("┐")[0], toRunes("└")[0], toRunes("┘")[0],
                                      toRunes("─")[0], toRunes("│")[0], toRunes("┼")[0],
                                      toRunes("├")[0], toRunes("┤")[0], toRunes("┴")[0], toRunes("┬")[0]]
# ┌─┬─┐
# │a│b│
# ├─┼─┤
# └─┴─┘

proc NoParent() : Option[AsciiTextWidget] = none(AsciiTextWidget)


proc `==`*(a,b: AsciiWidgetId) : bool =
  if a.kind != b.kind: false
  else:
    case a.kind:
      of AsciiWidgetIdKind.Taxon: a.taxon == b.taxon
      of AsciiWidgetIdKind.Int: a.id == b.id
      of AsciiWidgetIdKind.String: a.name == b.name

proc hash*(a: AsciiWidgetId): Hash =
  case a.kind:
    of AsciiWidgetIdKind.Taxon: hash(a.taxon)
    of AsciiWidgetIdKind.Int: hash(a.id)
    of AsciiWidgetIdKind.String: hash(a.name)




# proc readFromConfig*(cv: ConfigValue, v: var BindableAsciiWidgetBorder) =
#   cv["width"].
defineSimpleReadFromConfig(BindableAsciiWidgetBorder)
defineSimpleReadFromConfig(AsciiWidget)

proc createTextWidget*(windowing: ref AsciiWindowing, id: AsciiWidgetId, parent: Option[AsciiTextWidget], text: string, position: Vec2i, minDimensions: Vec2i, maxDimensions:Vec2i,
                        z: int = 0,
                        border: AsciiWidgetBorder = AsciiWidgetBorder(kind: AsciiWidgetBorderKind.SingleBorder, join: true),
                        hAlignment: HorizontalAlignment = HorizontalAlignment.Left,
                        textColor: RGBA = White,
                        multiLine: bool = false) : AsciiTextWidget =
  result = AsciiTextWidget(
    id: id,
    z: z,
    position: position,
    maxDimensions: maxDimensions,
    minDimensions: minDimensions,
    border: border,
    text: text,
    runes: toRunes(text),
    textAlignment: hAlignment,
    textColor: textColor,
    multiLine: multiLine,
    revision: 1
  )
  windowing.textWidgetsByZ.add(result)
  windowing.textWidgetsByZ.sort((a,b) => cmp(a.z, b.z))
  windowing.textWidgets[id] = (result, AsciiWidgetState(renderedRevision: 0))



proc `[]`*(buff: ref AsciiBuffer, x: int, y: int): Char =
  if x < 0 or y < 0 or x >= buff.dimensions.x or y >= buff.dimensions.y:
    warn &"Out of bounds read from ascii buffer: {x}, {y}"
    Char(rune: spaceRune)
  else:
    buff.buffer[x * buff.dimensions.y + y]

proc `[]=`*(buff: ref AsciiBuffer, x: int, y: int, v: Char) =
  if x < 0 or y < 0 or x >= buff.dimensions.x or y >= buff.dimensions.y:
    warn &"Out of bounds: {x}, {y}"
  else:
    buff.buffer[x * buff.dimensions.y + y] = v

proc writeZTested*(buff: ref AsciiBuffer, x: int, y: int, v: Char) =
  if x < 0 or y < 0 or x >= buff.dimensions.x or y >= buff.dimensions.y:
    warn &"Out of bounds: {x}, {y}"
  let index = x * buff.dimensions.y + y
  if buff.buffer[index].z <= v.z:
    buff.buffer[index] = v

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
    colors: gfx.colors,
    r_colors: gfx.r_colors,
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

proc equalContents*(a: ref AsciiBuffer, b: ref AsciiBuffer) : bool =
  if a.isNil or b.isNil: false
  elif a.dimensions != b.dimensions: false
  elif a.dimensions.x <= 0 or a.dimensions.y <= 0: true
  else: cmpMem(a.buffer[0].addr, b.buffer[0].addr, a.dimensions.x * a.dimensions.y * sizeof(Char)) == 0

proc blit*(writeTo: ref AsciiBuffer,readFrom : ref AsciiBuffer) =
  if writeTo.dimensions != readFrom.dimensions:
    warn &"Cannot blit buffers of different sizes: {writeTo.dimensions}, {readFrom.dimensions}"
    return


  for i in 0 ..< writeTo.dimensions.x * writeTo.dimensions.y:
    let c = readFrom.buffer[i]
    if c.rune != 0.Rune:
      writeTo.buffer[i] = c

proc write*(buf: ref AsciiBuffer, x: int, y: int, z: int8, s: string, colorIndex: uint8) =
  let runes = toRunes(s)
  if x < 0 or y < 0 or y >= buf.dimensions.y or x + runes.len >= buf.dimensions.x: warn &"Drawing out of bounds: {x}, {y}, {s}"
  else:
    # let cursor = x * buf.dimensions.y + y
    # for i in 0 ..< runes.len:
    #   buf.buffer[cursor + i].rune = runes[i]
    for i in 0 ..< runes.len:
      buf[x + i,y] = Char(rune: runes[i], foreground: colorIndex)

proc write*(c: AsciiCanvas, x: int, y: int, z: int8, s: string, colorIndex: uint8 = 0) =
  c.buffer.write(x,y,z,s,colorIndex)
  c.revision.inc

proc lookupColor*(c: AsciiCanvas, color: RGBA): uint8 =
  let colorLen = c.r_colors.len.uint8
  result = c.r_colors.mgetOrPut(color, colorLen)
  if result == colorLen:
    c.colors[].add(color)

proc write*(c: AsciiCanvas, x: int, y: int, z: int8, s: string, color: RGBA) =
  let colorIndex = lookupColor(c, color)
  c.buffer.write(x,y,z,s,colorIndex)
  c.revision.inc

proc write*(c: AsciiCanvas, x: int, y: int, v: Char) =
  let cur = c.buffer[x,y]
  if cur.z <= v.z:
    c.buffer.writeZTested(x,y,v)

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

proc joinChar(c : AsciiCanvas, x : int, y : int, boxPiece: BoxPieces) =
  let cur = c.buffer[x,y]
  let info = runeInfo(c, cur.rune)
  
  let curConn = boxPiecesToConnections(info.boxPiece)
  let addConn = boxPiecesToConnections(boxPiece)
  let effPiece = connectionsToBoxPieces([max(curConn[0],addConn[0]), max(curConn[1],addConn[1]), max(curConn[2],addConn[2]), max(curConn[3],addConn[3])])

  c.buffer[x,y] = Char(rune: SBoxPieces[effPiece.ord])

proc drawBox*(c: AsciiCanvas, x: int, y: int, width: int, height: int, join: bool = true, doubleV: bool = false, doubleH: bool = false) =
  let farX = x + width - 1
  let farY = y + height - 1

  if join:
    joinChar(c, x, y, BoxPieces.TopLeft)
    joinChar(c, farx, y, BoxPieces.TopRight)
    joinChar(c, farx, fary, BoxPieces.BottomRight)
    joinChar(c, x, fary, BoxPieces.BottomLeft)
  else:
    c.buffer[x,y] = Char(rune: SBoxPieces[BoxPieces.TopLeft.ord])
    c.buffer[farX,y] = Char(rune: SBoxPieces[BoxPieces.TopRight.ord])
    c.buffer[farx,fary] = Char(rune: SBoxPieces[BoxPieces.BottomRight.ord])
    c.buffer[x,fary] = Char(rune: SBoxPieces[BoxPieces.BottomLeft.ord])

  for ax in x+1 ..< farx:
    c.buffer[ax,y] = Char(rune: SBoxPieces[BoxPieces.Horizontal.ord])
    c.buffer[ax,fary] = Char(rune: SBoxPieces[BoxPieces.Horizontal.ord])

  for ay in y+1 ..< fary:
    c.buffer[x,ay] = Char(rune: SBoxPieces[BoxPieces.Vertical.ord])
    c.buffer[farx,ay] = Char(rune: SBoxPieces[BoxPieces.Vertical.ord])
  c.revision.inc

converter intToId(i: int): AsciiWidgetId =
  AsciiWidgetId(kind: AsciiWidgetIdKind.Int, id: i)
converter stringToId(str: string): AsciiWidgetId =
  AsciiWidgetId(kind: AsciiWidgetIdKind.String, name: str)
converter taxonToId(taxon: Taxon): AsciiWidgetId =
  AsciiWidgetId(kind: AsciiWidgetIdKind.Taxon, taxon: taxon)




proc render(g: AsciiCanvasComponent, world: LiveWorld, display: DisplayWorld) =
  let gfx : ref AsciiGraphics = display[AsciiGraphics]
  clear(gfx.buffer)

  gfx.canvases = gfx.canvases.sortedByIt(it.drawPriority * -1)
  for canvas in gfx.canvases:
    blit(gfx.buffer, canvas.buffer)

  let size = 32
  let f : ArxFont = font(gfx.typeface, 32)


  var ii,vi = 0

  var scale = case g.camera.kind:
    of CameraKind.WindowingCamera: g.camera.windowingScale
    else: 1
  let gcd = display[GraphicsContextData]

  for x in 0 ..< gfx.buffer.dimensions.x:
    for y in 0 ..< gfx.buffer.dimensions.y:
      let c = gfx.buffer[x,y]
      if c.rune != 0.Rune:
        let tc = g.texture[glyphImage(f, c.rune)]
        for q in 0 ..< 4:
          let vt = g.vao[vi+q]
          vt.vertex = vec3f(x * size,y * size,0) + UnitSquareVertices[q] * size.float32
          vt.color = gfx.colors[c.foreground]
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


proc onChanged(v: AsciiTextWidget) =
  v.revision.inc

template getterSetter(obj: untyped, t: untyped): untyped {.dirty.} =
  proc `t=`*(w: `obj`, value: typeof(`obj`.`t`)) =
    if w.`t` != value:
      onChanged(w)
      w.`t` = value

  proc `t`*(w: `obj`): typeof(`obj`.`t`) = w.`t`



proc text*(w: AsciiTextWidget): string = w.text
proc `text=`*(w: var AsciiTextWidget, s : string) =
  w.text = s
  w.runes = toRunes(s)
  w.revision.inc

getterSetter(AsciiTextWidget, z)
getterSetter(AsciiTextWidget, position)
getterSetter(AsciiTextWidget, maxDimensions)
getterSetter(AsciiTextWidget, minDimensions)
getterSetter(AsciiTextWidget, textAlignment)
getterSetter(AsciiTextWidget, textColor)
getterSetter(AsciiTextWidget, multiLine)
getterSetter(AsciiTextWidget, border)


proc parent*(w: AsciiTextWidget): Option[AsciiTextWidget] = w.parent
proc `parent=`*(w: var AsciiTextWidget, s : AsciiTextWidget) =
  if w.parent.is_none or w.parent.get.id != s.id:
    w.parent = some(s)
    w.revision.inc

proc borderWidth*(b: AsciiWidgetBorder): int =
  case b.kind:
    of AsciiWidgetBorderKind.NoBorder: 0
    else: 1

proc absolutePosition*(w: AsciiTextWidget): Vec2i =
  if w.parent.isSome:
    w.parent.get.absolutePosition + w.position
  else:
    w.position




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

proc layout(w: AsciiTextWidget): seq[(int, main_core.ClosedIntRange)] =
  layout(w.runes, w.minDimensions, w.maxDimensions - vec2i(w.border.borderWidth, w.border.borderWidth) * 2, w.multiLine, w.textAlignment)

proc drawBorder(c: AsciiCanvas, w: AsciiWidgetBorder, x: int, y: int, width: int, height: int) =
  if w.kind != AsciiWidgetBorderKind.NoBorder:
    drawBox(c, x, y, width, height, w.join)

proc render*(windowing: ref AsciiWindowing, w: AsciiTextWidget) =
  let c : AsciiCanvas = windowing.canvas
  let lines = layout(w)
  let bw = borderWidth(w.border)
  var dimensions = w.minDimensions
  dimensions.y = max(dimensions.y, lines.len + bw * 2).int32
  let position = w.absolutePosition

  for l in lines:
    let (offset, runeRange) = l
    dimensions.x = max(dimensions.x, offset + runeRange.max - runeRange.min + 1 + bw * 2).int32

  drawBorder(c, w.border, w.position.x, w.position.y, dimensions.x, dimensions.y)

  for lineOffset in 0 ..< lines.len:
    let (offset, runeRange) = lines[lineOffset]
    let ay = position.y + bw + lineOffset
    var ax = position.x + offset + bw

    let endBorder = bw
    let endOffset = endBorder + offset
    let endText = endOffset + runeRange.width
    let endContent = dimensions.x - bw

    for i in endBorder ..< endContent:
      let r = if i < endOffset: Char(rune: spaceRune)
      elif i < endText: Char(rune: w.runes[runeRange.min + i - endOffset])
      else: Char(rune: spaceRune)
      write(c, w.position.x + i, ay, r)

    # for i in 0 ..< offset:
    #   write(c, w.position.x + bw + i, ay, Char(rune: spaceRune))
    #
    # for i in runeRange.width ..< (dimensions.x - bw):
    #   write(c, w.position.x + bw + i, ay, Char(rune: spaceRune))
    #
    # for i in runeRange:
    #   write(c, ax, ay, Char(rune: w.runes[i]))
    #   ax.inc

method onEvent*(g: AsciiCanvasComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  discard




proc renderWindowingSystem*(windowing: ref AsciiWindowing) =
  let canvas = windowing.canvas
  canvas.clear()

  # canvas.drawBox(30,30,10,10)
  # canvas.drawBox(31,31,8,8)
  # canvas.drawBox(32,32,6,6)
  # canvas.drawBox(32,32,3,3)
  # canvas.drawBox(34,34,3,4)
  # canvas.drawBox(39,34,11,3)
  # canvas.write(40,35,"Greetings")
  for w in windowing.textWidgetsByZ:
    render(windowing, w)


method initialize(g: AsciiCanvasComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "AsciiCanvasComponent"
  g.initializePriority = 100
  g.vao = newVAO[SimpleVertex, uint32]()
  g.shader = initShader("shaders/simple")
  g.texture = newTextureBlock(1024, 1, false)
  g.camera = createWindowingCamera(1)
  display.attachData(
    AsciiGraphics(
      buffer: newAsciiBuffer((1680*2) div 32, (1200*2) div 32),
      colors: new(seq[RGBA]),
      r_colors: new(Table[RGBA, uint8]),
      typeface: loadArxTypeface("resources/fonts/Px437_SanyoMBC775.ttf")
    )
  )


proc handleEventWrapper(ws: WindowingSystemRef, event: WidgetEvent, world: LiveWorld, display: DisplayWorld) : bool =
  result = handleEvent(ws, event, world, display)
  if not result:
    display.addEvent(event)

method onEvent*(g: AsciiWindowingSystem, world: LiveWorld, display: DisplayWorld, event: Event) =
  let gcd = display[GraphicsContextData]
  let ws = display[WindowingSystem]

  proc pixelToWorld(px: Vec2f): Vec2f = px

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

        
      
method initialize(g: AsciiWindowingSystem, world: LiveWorld, display: DisplayWorld) =
  g.name = "AsciiWindowingSystem"
  g.initializePriority = 0
  g.texture = newTextureBlock(256, 1, false) #TODO nil?

  let gfx = display[AsciiGraphics]
  let canvas = newCanvas(gfx)
  let whiteIndex = canvas.lookupColor(rgba(255,255,255,255))

  let windowingSystem = createWindowingSystemWithCustomRenderer(display, ProjectName & "/widgets/", AsciiWindowingComponent(), noDefaultComponents = true)
  windowingSystem.pixelScale = 1
  windowingSystem.components.add(AsciiTextWidgetComponent())
  windowingSystem.components.add(ListWidgetComponent())
  windowingSystem.desktop.width = fixedSize(canvas.dimensions.x)
  windowingSystem.desktop.height = fixedSize(canvas.dimensions.y)
  windowingSystem.desktop.attachData(AsciiWidget(border: BindableAsciiWidgetBorder(width: bindable(1))))
  display.attachDataRef(windowingSystem)

  display.attachData(AsciiWindowing(canvas: canvas))
  let windowing = display[AsciiWindowing]

  let testWidget = windowingSystem.createWidget("TestWidgets", "TestBox")
  let testTextWidget = windowingSystem.createWidget("TestWidgets", "TestText")
  let testList = windowingSystem.createWidget("TestWidgets", "TestList")
  var items = @[
                    {"id": bindValue("a"), "content": bindValue("A"), "color": bindValue(rgba(255,255,255,255))}.toTable,
                    {"id": bindValue("b"), "content": bindValue("Longer Item"),  "color": bindValue(rgba(255,255,255,255))}.toTable,
                    {"id": bindValue("c"), "content": bindValue("Last"),  "color": bindValue(rgba(255,255,255,255))}.toTable
                ]
  testList.bindValue("testData.items", items)
  takeFocus(testList, world)
  testList.onEventOfType(WidgetKeyPress, press):
    let i = case press.key:
      of KeyCode.A: 0
      of KeyCode.B: 1
      of KeyCode.C: 2
      else: -1
    if i >= 0:
      let curSel = selectedListIndex(testList).get(-1)
      if curSel == i:
        items[i]["content"] = bindValue(items[i]["content"].asString & "+")
      else:
        selectListIndex(testList, i)
      testList.bindValue("testData.items", items)


  onEventLW(testList):
    extract(ListItemSelect, index, widget, originatingWidget):
      for i in 0 ..< items.len:
        if i == index:
          items[i]["color"] = bindValue(rgba(255,100,100,255))
        else:
            items[i]["color"] = bindValue(rgba(255,255,255,255))
      testList.bindValue("testData.items", items)

  selectListIndex(testList, 0)


method update(g: AsciiWindowingSystem, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  discard display[WindowingSystem].update(g.texture, world, display)

method customRender*(ws: AsciiWindowingComponent, display: DisplayWorld, widget: Widget, tb: TextureBlock, bounds: Bounds) =
  let c : AsciiCanvas = display[AsciiWindowing].canvas


  if widget.data(AsciiWidget).border.width.value > 0:
    let pos = widget.resolvedPosition
    let dim = widget.resolvedDimensions
    drawBox(c, pos.x, pos.y, dim.x, dim.y, )


method clientOffset*(ws: AsciiWindowingComponent, widget: Widget, axis: Axis): Option[Vec3i] =
  let bw = widget.data(AsciiWidget).border.width.value
  some(vec3i(bw, bw, 0))

method intrinsicSize*(ws: AsciiWindowingComponent, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] =
  none(int)

method readDataFromConfig*(ws: AsciiWindowingComponent, cv: ConfigValue, widget: Widget) =
  if not widget.hasData(AsciiWidget):
    widget.attachData(AsciiWidget())
  readInto(cv, widget.data(AsciiWidget)[])

method updateBindings*(ws: AsciiWindowingComponent, widget: Widget, resolver: var BoundValueResolver) =
  let w = widget.data(AsciiWidget)
  if updateBindings(w.border, resolver):
    markForUpdate(widget, RecalculationFlag.Contents)

method handleEvent*(ws: AsciiWindowingComponent, widget: Widget, event: UIEvent, display: DisplayWorld) =
  discard

method onCreated*(ws: AsciiWindowingComponent, widget: Widget) =
  discard


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

proc charsFor(g: AsciiTextWidgetComponent, w: Widget, td: ref TextDisplay): seq[Char] =
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
      var i : int
      while i < chars.len and chars.len < cHeight:
        let r = chars[i].rune
        if r == newlineRune:
          lines.add(lstart ..< i)
          lstart = i+1
        elif i - lstart >= cWidth:
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


method intrinsicSize*(g: AsciiTextWidgetComponent, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] =
  if widget.hasData(TextDisplay):
    let td : ref TextDisplay = widget.data(TextDisplay)

    var maxDims = maximums
    if not widget.width.isIntrinsic:
      maxDims.x = min(maxDims.x, widget.resolvedDimensions.x - widget.clientOffset.x * 2)

    let layout = layoutChars(charsFor(g, widget, td), td.multiLine, maxDims, HorizontalAlignment.Left)
    some(max(dimensions(layout)[axis], minimums[axis]))
  else:
    none(int)

method updateBindings*(g: AsciiTextWidgetComponent, widget: Widget, resolver: var BoundValueResolver) =
  if widget.hasData(TextDisplay):
    procCall updateBindings(TextDisplayRenderer(g), widget, resolver)
    if isMarkedForUpdate(widget, RecalculationFlag.Contents):
      g.charsCache[widget] = updateCharsFor(widget, widget.data(TextDisplay))


method customRender*(g: AsciiTextWidgetComponent, display: DisplayWorld, widget: Widget, tb: TextureBlock, bounds: Bounds) =
  if widget.hasData(TextDisplay):
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

      for i in 0 ..< endContent:
        let r = if i < endOffset: Char(rune: spaceRune, z: position.z.int8)
        elif i < endText: chars[line.charRange.min + i - endOffset]
        else: Char(rune: spaceRune, z: position.z.int8)
        write(c, ax + i, ay, r)