import typography
import bumpy, pixie, typography/font, typography/rasterizer, tables, unicode, vmath



proc canWrap(rune: Rune): bool =
  if rune == Rune(32): return true # Early return for ascii space.
  if rune.isWhiteSpace(): return true
#   if not rune.isAlpha(): return true
  false

proc typeset*(
    font: Font,
    runes: seq[Rune],
    pos: Vec2 = vec2(0, 0),
    offset: Vec2 = vec2(0, 0),
    size: Vec2 = vec2(0, 0),
    hAlign: HAlignMode = Left,
    vAlign: VAlignMode = Top,
    clip: bool = true,
    wrap: bool = true,
    kern: bool = true,
    tabWidth: float32 = 0.0,
    boundsMin: var Vec2,
    boundsMax: var Vec2
  ): seq[GlyphPosition] =
     ## Typeset runes and return glyph positions that is ready to draw.
     assert font.size != 0
     assert font.typeface != nil
     assert font.typeface.unitsPerEm != 0

     result = @[]
     var
       at = pos + offset
       lineStart = pos.x
       prev = ""
       ## Figure out why some times the scale is ignored this way:
       #scale = font.size / (font.ascent - font.descent)
       glyphCount = 0
       tabWidth = tabWidth

     if tabWidth == 0.0:
       tabWidth = font.size * 4

     var
       strIndex = 0
       glyphIndex = 0
       lastCanWrap = 0
       lineHeight = font.lineHeight

     if lineHeight == normalLineHeight:
       lineHeight = font.size

     let selectionHeight = max(font.size, lineHeight)

     at.y += font.baseline

     for rune in runes:
       var c = $rune
       if rune == Rune(10): # New line "\n".
         # Add special small width glyph on this line.
         var selectRect = rect(
           floor(at.x),
           floor(at.y) - font.baseline,
           font.typeface.glyphs[" "].advance * font.scale,
           selectionHeight
         )
         result.add GlyphPosition(
           font: font,
           fontSize: font.size,
           subPixelShift: 0,
           rect: rect(0, 0, 0, 0),
           selectRect: selectRect,
           rune: rune,
           character: c,
           count: glyphCount,
           index: strIndex
         )
         prev = c
         inc glyphCount
         strIndex += c.len

         at.x = lineStart
         at.y += lineHeight
         continue
       elif rune == Rune(9): # tab \t
         at.x = ceil(at.x / tabWidth) * tabWidth
         continue

       if canWrap(rune):
         lastCanWrap = glyphIndex + 1

       if c notin font.typeface.glyphs:
         # TODO: Make missing glyphs work better.
         c = " " # If glyph is missing use space for now.
         if c notin font.typeface.glyphs:
           ## Space is missing!?
           continue

       var glyph = font.typeface.glyphs[c]
       if kern:
         at.x += font.kerningAdjustment(prev, c) * font.scale

       let q =
         if font.size < 20: 0.1
         elif font.size < 25: 0.2
         elif font.size < 30: 0.5
         else: 1.0
       var subPixelShift = quantize(at.x - floor(at.x), q)
       var glyphPos = vec2(floor(at.x), floor(at.y))
       var glyphSize = font.getGlyphSize(glyph)

       if rune == Rune(32):
         glyphSize.x = glyph.advance * font.scale

       if glyphSize.x != 0 and glyphSize.y != 0:
         # Does it need to wrap?
         if wrap and size.x != 0 and at.x - pos.x + glyphSize.x > size.x:
           # Wrap to next line.
           let goBack = lastCanWrap - glyphIndex
           if lastCanWrap != -1 and goBack < 0:
             lastCanWrap = -1
             at.y += lineHeight
             if clip and size.y != 0 and at.y - pos.y > size.y:
               # Delete glyphs that would wrap into next line
               # that is clipped.
               result.setLen(result.len + goBack)
               return

             # Wrap glyphs on prev line down to next line.
             let shift = result[result.len + goBack].rect.x - pos.x
             for i in result.len + goBack ..< result.len:
               result[i].rect.x -= shift
               result[i].rect.y += lineHeight
               result[i].selectRect.x -= shift
               result[i].selectRect.y += lineHeight

             at.x -= shift
           else:
             at.y += lineHeight
             at.x = lineStart

           glyphPos = vec2(floor(at.x), floor(at.y))

         if clip and size.y != 0 and at.y - pos.y > size.y:
           # Reached the bottom of the area, clip.
           return

       var selectRect = rect(
         floor(at.x),
         floor(at.y) - font.baseline,
         glyphSize.x,
         selectionHeight
       )

       if result.len > 0:
         # Adjust selection rect width to next character
         if result[^1].selectRect.y == selectRect.y:
           result[^1].selectRect.w = floor(at.x) - result[^1].selectRect.x

       result.add GlyphPosition(
         font: font,
         fontSize: font.size,
         subPixelShift: subPixelShift,
         rect: rect(glyphPos, glyphSize),
         selectRect: selectRect,
         character: c,
         rune: rune,
         count: glyphCount,
         index: strIndex
       )
       if glyphCount == 0:
         # First glyph.
         boundsMax.x = selectRect.x + selectRect.w
         boundsMin.x = selectRect.x
         boundsMax.y = selectRect.y + selectRect.h
         boundsMin.y = selectRect.y
       else:
         boundsMax.x = max(boundsMax.x, selectRect.x + selectRect.w)
         boundsMin.x = min(boundsMin.x, selectRect.x)
         boundsMax.y = max(boundsMax.y, selectRect.y + selectRect.h)
         boundsMin.y = min(boundsMin.y, selectRect.y)

       inc glyphIndex
       at.x += glyph.advance * font.scale
       prev = c
       inc glyphCount
       strIndex += c.len

     ## Shifts layout by alignMode.
     if result.len == 0: return

     let boundsSize = boundsMax - boundsMin

     if hAlign == Right:
       let offset = floor(size.x - boundsSize.x)
       for pos in result.mitems:
         pos.rect.x += offset
         pos.selectRect.x += offset

     if hAlign == Center:
       let offset = floor((size.x - boundsSize.x) / 2.0)
       for pos in result.mitems:
         pos.rect.x += offset
         pos.selectRect.x += offset

     if vAlign == Bottom:
       let offset = floor(size.y - boundsSize.y)
       for pos in result.mitems:
         pos.rect.y += offset
         pos.selectRect.y += offset

     if vAlign == Middle:
       let offset = floor((size.y - boundsSize.y) / 2.0)
       for pos in result.mitems:
         pos.rect.y += offset
         pos.selectRect.y += offset