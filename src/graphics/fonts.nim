
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


type
   GlyphInfo* = object
      image* : Image
      offset* : Vec2f
   ArxFontRoot* = ref object
      font* : Font
      basePointSize* : int
      baseLineHeight* : int
      pixelFont* : bool
      fonts : Table[int, ArxFont]
   ArxFont* = ref object
      fontRoot* : ArxFontRoot
      pointSize* : int
      lineHeight : int
      glyphs* : Table[string, GlyphInfo]
      


proc withPointSize*(root : ArxFontRoot, pointSize : int) : ArxFont =
   let effPointSize = if root.pixelFont : (pointSize div root.basePointSize) * root.basePointSize else : pointSize
   let lineHeight = if root.pixelFont : (pointSize div root.basePointSize) * root.baseLineHeight else : 0
   if root.fonts.contains(effPointSize):
      result = root.fonts[effPointSize]
   else:
      result = ArxFont(
         fontRoot : root,
         pointSize : effPointSize,
         lineHeight : lineHeight
      )
      root.fonts[effPointSize] = result

proc withPixelSize*(root : ArxFontRoot, pixelSize : int) : ArxFont =
   root.withPointSize((pixelSize.float * 0.75f).round.int)

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


proc typographyFont(font : ArxFont) : Font =
   result = font.fontRoot.font
   result.sizePt = font.pointSize.float
   result.lineHeight = if font.lineHeight != 0: font.lineHeight.float else : (result.ascent - result.descent) * result.scale
   
proc glyph*(font : ArxFont, character : string) : GlyphInfo =
   if font.glyphs.contains(character):
      return font.glyphs[character]
   else:
      let f = font.typographyFont()
      var offsets : vmath.Vec2
      let img = if character == "\n" or character == "\t":
         createImage(vec2i(1,1))
      else:
         let baseImg = getGlyphImage(f, character, offsets)
         createImage(baseImg.data,glm.vec2i(baseImg.width.int32, baseImg.height.int32), true)
      result = GlyphInfo(image : img, offset : glm.vec2f(offsets.x, offsets.y))
      font.glyphs[character] = result
      

proc typeset*(font : ArxFont, text : string, position : Vec2i, offset : Vec2i, size : Vec2i) : seq[GlyphPosition] =
   let rawFont = font.typographyFont()
   
   result = layout_fork.typeset(rawFont, toRunes(text), vmath.vec2(position.x.float, position.y.float), vmath.vec2(offset.x.float, offset.y.float), vmath.vec2(size.x.float, size.y.float))
   for gp in result.mitems:
      let ginfo = font.glyph(gp.character)
      gp.rect.y += ginfo.offset.y