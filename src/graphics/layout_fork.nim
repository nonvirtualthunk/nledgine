import typography
import unicode
import tables
import vmath



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
    clip = true,
    tabWidth: float32 = 0.0
  ): seq[GlyphPosition] =
  ## Typeset runes and return glyph positions that is ready to draw.

  assert font.size != 0
  assert font.unitsPerEm != 0

  result = @[]
  var
    at = pos + offset
    lineStart = pos.x
    prev = ""
    scale = font.size / font.unitsPerEm
    ## Figure out why some times the scale is ignored this way:
    #scale = font.size / (font.ascent - font.descent)
    boundsMin = vec2(0, 0)
    boundsMax = vec2(0, 0)
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

  at.y += ceil(font.size / 2 + lineHeight / 2 + font.descent * scale)

  for rune in runes:
    var c = $rune
    if rune == Rune(10): # New line "\n".
      # Add special small width glyph on this line.
      var selectRect = rect(
        floor(at.x),
        floor(at.y) - font.size,
        font.glyphs[" "].advance * scale,
        lineHeight
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

    if c notin font.glyphs:
      # TODO: Make missing glyphs work better.
      c = " " # If glyph is missing use space for now.
      if c notin font.glyphs:
        ## Space is missing!?
        continue

    var glyph = font.glyphs[c]
    at.x += font.kerningAdjustment(prev, c) * scale

    var subPixelShift = at.x - floor(at.x)
    var glyphPos = vec2(floor(at.x), floor(at.y))
    var glyphSize = font.getGlyphSize(glyph)

    if rune == Rune(32):
      glyphSize.x = glyph.advance * scale

    if glyphSize.x != 0 and glyphSize.y != 0:
      # Does it need to wrap?
      if size.x != 0 and at.x - pos.x + glyphSize.x > size.x and rune != Rune(32):
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
      floor(at.y) - font.size,
      glyphSize.x + 1,
      lineHeight
    )

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
      boundsMax.x = at.x + glyphSize.x
      boundsMin.x = at.x
      boundsMax.y = at.y + font.size
      boundsMin.y = at.y
    else:
      boundsMax.x = max(boundsMax.x, at.x + glyphSize.x)
      boundsMin.x = min(boundsMin.x, at.x)
      boundsMax.y = max(boundsMax.y, at.y + font.size)
      boundsMin.y = min(boundsMin.y, at.y)

    inc glyphIndex
    at.x += glyph.advance * scale
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

  if hAlign == Center:
    let offset = floor((size.x - boundsSize.x) / 2.0)
    for pos in result.mitems:
      pos.rect.x += offset

  if vAlign == Bottom:
    let offset = floor(size.y - boundsSize.y + font.descent * scale)
    for pos in result.mitems:
      pos.rect.y += offset

  if vAlign == Middle:
    let offset = floor((size.y - boundsSize.y) / 2.0)
    for pos in result.mitems:
      pos.rect.y += offset