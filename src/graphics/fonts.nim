import glm except vec2
import images
import unicode
import tables
import os
import config/config_core
import math
import vmath
import options
import strutils
import strformat
import graphics/color
import pixie/fonts as pixie_fonts
import pixie
import stb_image/write as stbi

{.experimental.}









type
  ArxTypeface* = ref object
    typeface* : Typeface
    glyphLibrary*: Table[(Rune,int), images.Image]
    pixelFont*: bool
    baseSize*: int

  ArxFont* = object
    arxTypeface* : ArxTypeface
    font*: Font


converter toFont*(f : ArxFont): Font = f.font
converter toTypeface*(t : ArxTypeface): Typeface = t.typeface


proc loadArxTypeface*(path: string) : ArxTypeface =
  ArxTypeface(
    typeface: readFont(path).typeface
  )


proc glyphImage*(f: ArxFont, r: Rune) : images.Image =
  if f.arxTypeface.glyphLibrary.contains((r, f.font.size.int)):
    f.arxTypeface.glyphLibrary[(r, f.font.size.int)]
  else:
    var path = f.font.typeface.getGlyphPath(r)
    let bounds = f.computeBounds($r)
    if bounds.x <= 0.0f or bounds.y <= 0.0f:
      echo "zero Rune: ", r, " Bounds: ", bounds
      createImage(vec2i(1,1))
    else:
      let gimg = newImage(bounds.x.int, ((f.font.typeface.ascent - f.font.typeface.descent) * f.scale).int)

      path.transform(translate(vec2(0,f.font.typeface.ascent * f.scale)) * scale(vec2(f.scale,f.scale)))
      gimg.fillPath(path, Paint(kind: PaintKind.pkSolid, color: rgbx(255,255,255,255)), vec2(0,0))
      let arxImg = createImage(cast[ptr uint8](gimg.data[0].unsafeAddr),glm.vec2i(gimg.width.int32, gimg.height.int32), false)
      arxImg.writeToFile(&"/tmp/{r}.png")
      f.arxTypeface.glyphLibrary[(r, f.font.size.int)] = arxImg
      arxImg


proc font*(t: ArxTypeface, size: int): ArxFont =
  ArxFont(
    arxTypeface: t,
    font: Font(
      typeface: t.typeface,
      size: size.float32,
      paint: Paint(kind: PaintKind.pkSolid, color: rgbx(255,255,255,255)),
      lineHeight: AutoLineHeight
    )
  )

proc lineHeight*(f: ArxFont): int =
  if f.font.lineHeight > 0.0:
    f.font.lineHeight.int
  else:
    f.font.defaultLineHeight.int

proc maxCharHeight*(f: ArxFont): int =
  ((f.arxTypeface.typeface.ascent - f.arxTypeface.typeface.descent) * f.font.scale).int

proc ascent*(f: ArxFont): int =
  (f.arxTypeface.typeface.ascent * f.font.scale).int


when isMainModule:

  let typeface = loadArxTypeface("resources/fonts/pf_ronda_seven.ttf")

  let arxFont = typeface.font(32)

  # font.font.paint = Paint(kind: PaintKind.pkSolid, color: rgbx(0,0,0,255))
  let span = newSpan("query", arxFont.font)
  let arrangement = typeset(@[span])

  let pimg = newImage(400,100)

  proc writeImg(timg: pixie.Image, path: string) =
    let img = createImage(cast[ptr uint8](timg.data[0].unsafeAddr),glm.vec2i(timg.width.int32, timg.height.int32), false)
    writeToFile(img, path)

  for spanIndex, (start, stop) in arrangement.spans:
    let arFont = arrangement.fonts[spanIndex]
    for runeIndex in start .. stop:
      let img = arxFont.glyphImage(arrangement.runes[runeIndex])
      writeToFile(img, &"/tmp/out_{runeIndex}.png")



  fillText(pimg, arrangement)
  writeImg(pimg, "/tmp/out.png")






# type
#   GlyphInfo* = object
#     image* : images.Image
#     offset* : Vec2f
#   ArxFontRoot* = ref object
#     font* : Font
#     basePointSize* : int
#     baseLineHeight* : int
#     prerenderedPath* : Option[string]
#     pixelFont* : bool
#     fonts : Table[int, ArxFont]
#     useRawSizes* : bool
#   ArxFont* = ref object
#     fontRoot* : ArxFontRoot
#     pointSize* : int
#     lineHeight : int
#     glyphs* : Table[string, GlyphInfo]
#
#
#
# proc withPointSize*(root : ArxFontRoot, pointSize : int, pixelScale : int) : ArxFont =
#   let effPointSize =
#     if root.pixelFont :
#       if pointSize >= root.basePointSize:
#         (pointSize.float / root.basePointSize.float).round.int * root.basePointSize
#       else:
#         # root.basePointSize div pixelScale
#         root.basePointSize
#     else :
#       pointSize
#   let lineHeight =
#     if root.pixelFont :
#       if pointSize >= root.basePointSize:
#         (pointSize.float / root.basePointSize.float).round.int * root.baseLineHeight
#       else:
#         # root.baseLineHeight div pixelScale
#         root.baseLineHeight
#     else :
#       root.font.lineHeight.int
#
#   if root.fonts.contains(effPointSize):
#     result = root.fonts[effPointSize]
#   else:
#     result = ArxFont(
#       fontRoot : root,
#       pointSize : effPointSize,
#       lineHeight : lineHeight
#     )
#     root.fonts[effPointSize] = result
#
# proc withPixelSize*(root : ArxFontRoot, pixelSize : int, pixelScale : int) : ArxFont =
#   root.withPointSize((pixelSize.float * 0.75f).round.int, pixelScale)
#
# proc loadArxFont*(path : string) : ArxFontRoot =
#   result = ArxFontRoot(
#     basePointSize : 12,
#     baseLineHeight : 0,
#     pixelFont : true,
#     font : readFont(path)
#   )
#
#   let confPath = path & ".sml"
#   if fileExists(confPath):
#     let conf = parseConfig(readFile(confPath))
#     conf["pixelFont"].readInto(result.pixelFont)
#     conf["basePointSize"].readInto(result.basePointSize)
#     conf["baseLineHeight"].readInto(result.baseLineHeight)
#     conf["useRawSizes"].readInto(result.useRawSizes)
#     if conf["prerendered"].asBool(false):
#       var prePath = path
#       prePath.removeSuffix(".ttf")
#       result.prerenderedPath = some(prePath)
#
# proc setFontSize(arxFont : ArxFont, font : var Font, pointSize : int) =
#   font.size = pointSize.float
#   # font.lineHeight = if arxFont.lineHeight != 0: arxFont.lineHeight.float
#   #              else :
#   #                (font.typeface.ascent - font.typeface.descent) * font.scale
#
# proc typographyFont*(font : ArxFont) : Font =
#   result = font.fontRoot.font
#   setFontSize(font, result, font.pointSize)
#
# proc glyph*(font : ArxFont, character : string) : GlyphInfo =
#   if font.glyphs.contains(character):
#     return font.glyphs[character]
#   else:
#     let f = font.typographyFont()
#     var offsets : vmath.Vec2
#     let img =
#       if character == "\n" or character == "\t" or character == " ":
#         createImage(vec2i(1,1))
#       else:
#         if font.fontRoot.prerenderedPath.isSome:
#           loadImage(font.fontRoot.prerenderedPath.get & "/chars/" & $int(character[0]) & ".png")
#         else:
#           let glyphImg = newImage(100,100)
#           f.getGlyphPath(
#           let baseImg = getGlyphImage(f, character, offsets)
#           let img = createImage(cast[ptr uint8](baseImg.data[0].unsafeAddr),glm.vec2i(baseImg.width.int32, baseImg.height.int32), true)
#
#           for x in 0 ..< img.width:
#             for y in 0 ..< img.height:
#               let pixel = img[x,y]
#               pixel.r = 1.0f
#               pixel.g = 1.0f
#               pixel.b = 1.0f
#               # pixel.r = 1.0f
#               # pixel.g = 1.0f
#               # pixel.b = 1.0f
#
#           img
#
#     discard font.typographyFont()
#     result = GlyphInfo(image : img, offset : glm.vec2f(offsets.x, offsets.y))
#     font.glyphs[character] = result
#
#
# proc typeset*(font : ArxFont, text : string, position : Vec2i, offset : Vec2i, size : Vec2i) : seq[GlyphPosition] =
#   let rawFont = font.typographyFont()
#
#
#
#   var boundsMin, boundsMax : vmath.Vec2
#   result = pixie_fonts.typeset(
#       rawFont,
#       toRunes(text),
#       vmath.vec2(position.x.float, position.y.float),
#       vmath.vec2(offset.x.float, offset.y.float),
#       vmath.vec2(size.x.float, size.y.float),
#       boundsMin = boundsMin,
#       boundsMax = boundsMax)
#   for gp in result.mitems:
#     let ginfo = font.glyph(gp.character)
#     gp.rect.y += ginfo.offset.y