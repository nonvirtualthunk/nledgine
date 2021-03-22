
import typography
import glm
import images
import unicode
import tables
import os
import config/config_core
import math
import vmath
import layout_fork
import options
import strutils
import strformat
import graphics/color

{.experimental.}

type
   GlyphInfo* = object
      image* : Image
      offset* : Vec2f
   ArxFontRoot* = ref object
      font* : Font
      basePointSize* : int
      baseLineHeight* : int
      prerenderedPath* : Option[string]
      pixelFont* : bool
      fonts : Table[int, ArxFont]
      useRawSizes* : bool
   ArxFont* = ref object
      fontRoot* : ArxFontRoot
      pointSize* : int
      lineHeight : int
      glyphs* : Table[string, GlyphInfo]
      


proc withPointSize*(root : ArxFontRoot, pointSize : int, pixelScale : int) : ArxFont =
   let effPointSize = 
      if root.pixelFont : 
         if pointSize >= root.basePointSize:
            (pointSize.float / root.basePointSize.float).round.int * root.basePointSize 
         else:
            # root.basePointSize div pixelScale
            root.basePointSize
      else : 
         pointSize
   let lineHeight = 
      if root.pixelFont : 
         if pointSize >= root.basePointSize:
            (pointSize.float / root.basePointSize.float).round.int * root.baseLineHeight
         else:
            # root.baseLineHeight div pixelScale
            root.baseLineHeight
      else : 
         root.font.lineHeight.int

   if root.fonts.contains(effPointSize):
      result = root.fonts[effPointSize]
   else:
      result = ArxFont(
         fontRoot : root,
         pointSize : effPointSize,
         lineHeight : lineHeight
      )
      root.fonts[effPointSize] = result

proc withPixelSize*(root : ArxFontRoot, pixelSize : int, pixelScale : int) : ArxFont =
   root.withPointSize((pixelSize.float * 0.75f).round.int, pixelScale)

proc loadArxFont*(path : string) : ArxFontRoot =
   result = ArxFontRoot(
      basePointSize : 12,
      baseLineHeight : 0,
      pixelFont : true,
      font : readFontTtf(path)
   )

   let confPath = path & ".sml"
   if fileExists(confPath):
      let conf = parseConfig(readFile(confPath))
      conf["pixelFont"].readInto(result.pixelFont)
      conf["basePointSize"].readInto(result.basePointSize)
      conf["baseLineHeight"].readInto(result.baseLineHeight)
      conf["useRawSizes"].readInto(result.useRawSizes)
      if conf["prerendered"].asBool(false):
         var prePath = path
         prePath.removeSuffix(".ttf")
         result.prerenderedPath = some(prePath)

proc setFontSize(arxFont : ArxFont, font : Font, pointSize : int) =
   if arxFont.fontRoot.useRawSizes:
      font.size = pointSize.float
   else:
      font.sizePt = pointSize.float
   font.lineHeight = if arxFont.lineHeight != 0: arxFont.lineHeight.float
                     else :
                        (font.typeface.ascent - font.typeface.descent) * font.scale

proc typographyFont*(font : ArxFont) : Font =
   result = font.fontRoot.font
   setFontSize(font, result, font.pointSize)
   
proc glyph*(font : ArxFont, character : string) : GlyphInfo =
   if font.glyphs.contains(character):
      return font.glyphs[character]
   else:
      let f = font.typographyFont()
      var offsets : vmath.Vec2
      let img = 
         if character == "\n" or character == "\t" or character == " ":
            createImage(vec2i(1,1))
         else:
            if font.fontRoot.prerenderedPath.isSome:
               loadImage(font.fontRoot.prerenderedPath.get & "/chars/" & $int(character[0]) & ".png")
            else:
               # if font.fontRoot.pixelFont and font.pointSize != font.fontRoot.basePointSize*2:
               # #    # let prevSize = f.size
               # #    # let prevLH = f.lineHeight
               # #    # setFontSize(font, f, font.fontRoot.basePointSize)
               # #    # echo "prev size : ", prevSize
               # #    # echo "subsequent size : ", f.size
               # #    # let multiple = prevSize / f.size
               #    let baseImg = getGlyphImage(f, character, offsets)
               # #    # offsets.x *= multiple
               # #    # offsets.y *= multiple
               # #    # let retImg = createImage(baseImg.data,glm.vec2i(baseImg.width.int32, baseImg.height.int32), true)
               # #    # f.size = prevSize
               # #    # f.lineHeight = prevLH
               # #    # retImg
               #    font.fontRoot.withPointSize(font.fontRoot.basePointSize*2, 1).glyph(character).image
               # else:
               let baseImg = getGlyphImage(f, character, offsets)
               let img = createImage(cast[ptr uint8](baseImg.data[0].unsafeAddr),glm.vec2i(baseImg.width.int32, baseImg.height.int32), true)

               for x in 0 ..< img.width:
                  for y in 0 ..< img.height:
                     let pixel = img[x,y]
                     pixel.r = 1.0f
                     pixel.g = 1.0f
                     pixel.b = 1.0f
                     # pixel.r = 1.0f
                     # pixel.g = 1.0f
                     # pixel.b = 1.0f

               img

      discard font.typographyFont()
      result = GlyphInfo(image : img, offset : glm.vec2f(offsets.x, offsets.y))
      font.glyphs[character] = result
      

proc typeset*(font : ArxFont, text : string, position : Vec2i, offset : Vec2i, size : Vec2i) : seq[GlyphPosition] =
   let rawFont = font.typographyFont()

   var boundsMin, boundsMax : vmath.Vec2
   result = layout_fork.typeset(
         rawFont,
         toRunes(text),
         vmath.vec2(position.x.float, position.y.float),
         vmath.vec2(offset.x.float, offset.y.float),
         vmath.vec2(size.x.float, size.y.float),
         boundsMin = boundsMin,
         boundsMax = boundsMax)
   for gp in result.mitems:
      let ginfo = font.glyph(gp.character)
      gp.rect.y += ginfo.offset.y