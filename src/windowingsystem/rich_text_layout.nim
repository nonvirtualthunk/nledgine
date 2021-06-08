import rich_text
import worlds/taxonomy
import graphics/image_extras
import windowing_rendering
import glm
import prelude
import arxmath
import graphics/color
import unicode
import resources
import vmath
import stb_image/write as stbiw
import graphics/fonts
import options
import noto
import graphics/taxonomy_display
import pixie/fonts as pfonts

const SpaceRune = Rune(32)
const TabRune = Rune(9)
const NewlineRune = Rune(10)

type QuadGroup = object
  startIndex: int
  endIndex: int
  verticalAlignment: VerticalAlignment


proc layout*(richText: RichText, size: int, bounds: Recti, pixelScale: int, renderSettings: RichTextRenderSettings): TextLayout =
  var res: TextLayout
  var minPos: Vec2i = vec2i(0, 0)
  var maxPos: Vec2i = vec2i(0, 0)

  var cursor = vec2i(0, 0)

  let richTextSize = if richText.size == 0.0: 1.0 else: richText.size

  let overallFont = if richText.font != nil:
      richText.font
    elif renderSettings.defaultFont.isSome:
      renderSettings.defaultFont.get
    else:
      resources.font(DefaultFontName)

  res.lineInfo = @[LineInfo(maximumHeight: 0, startIndex: 0, startY: 0)]
  var quadGroups: seq[QuadGroup] = @[]
  var sectionIndex = 0

  proc addQuad(quad: WQuad, solidQuad: bool, subIndex: int) =
    res.quads.add(quad)
    res.quadOrigins.add(RichTextIndex(sectionIndex:sectionIndex, subIndex: subIndex))
    if solidQuad:
      case quad.shape.kind:
        of WShapeKind.Rect:
          res.lineInfo[res.lineInfo.len-1].maximumHeight.maxWith((quad.shape.position.y.int + quad.shape.dimensions.y) - cursor.y)
          minPos.minAll(vec2i(quad.shape.position.x.int, quad.shape.position.y.int))
          maxPos.maxAll(vec2i(quad.shape.position.x.int + quad.shape.dimensions.x.int, quad.shape.position.y.int + quad.shape.dimensions.y.int))
        else:
          warn &"Non-rect wquad in text layout"
  proc splitQuadGroup() =
    let alignment = quadGroups[quadGroups.len-1].verticalAlignment
    quadGroups[quadGroups.len-1].endIndex = res.quads.len
    quadGroups.add(QuadGroup(startIndex: res.quads.len, verticalAlignment: alignment))
  proc endQuadGroup() =
    quadGroups[quadGroups.len-1].endIndex = res.quads.len
  proc endLine(startNew: bool) =
    if startNew: splitQuadGroup()
    res.lineInfo[res.lineInfo.len-1].endIndex = res.quads.len
    if startNew: res.lineInfo.add(LineInfo(startIndex: res.quads.len, startY: cursor.y))

  proc renderSection(section: RichTextSection) =
    quadGroups.add(QuadGroup(startIndex: res.quads.len, verticalAlignment: section.verticalAlignment))

    var effColor = rgba(1.0f, 1.0f, 1.0f, 1.0f)

    if section.color.isSome:
      effColor = section.color.get
    elif renderSettings.baseColor.isSome:
      effColor = renderSettings.baseColor.get
    elif section.kind == Text:
      effColor = rgba(0.0f, 0.0f, 0.0f, 1.0f)

    if richText.tint.isSome:
      effColor = mix(effColor, richText.tint.get, 0.5)
    if renderSettings.tint.isSome:
      effColor = mix(effColor, renderSettings.tint.get, 0.5)

    var effSize = richTextSize * size.float
    if section.size != 0.0: effSize *= section.size.float

    case section.kind:
    of Text:
      let fontRoot = if section.font != nil:
        section.font
      else:
        overallFont

      let font = fontRoot.font((effSize).round.int)
      let span = newSpan(section.text, font)
      let arrangement = typeset(@[span], vmath.vec2(bounds.dimensions.x.float, bounds.dimensions.y.float), haLeft, vaTop, true, vmath.vec2(cursor.x.float, cursor.y.float))
      res.lineHeight = font.lineHeight

      # index into the seq of format ranges, which must be sorted if present
      var formatRangeIndex = 0

      var linesIndex = 0

      for spanIndex, (start, stop) in arrangement.spans:
        let arFont = arrangement.fonts[spanIndex]
        for runeIndex in start .. stop:
          var pos = arrangement.positions[runeIndex]
          pos.y -= font.ascent.float
          let rune = arrangement.runes[runeIndex]

          res.lineInfo[res.lineInfo.len-1].maximumHeight.maxWith(font.lineHeight.int)
          maxPos.y.maxWith(font.maxCharHeight.int32)
          let isWhitespace = rune == SpaceRune or rune == TabRune or rune == NewlineRune

          # Note: check if this should really be >= rather than >
          # detect if we've crossed into a new line
          if runeIndex > arrangement.lines[linesIndex][1]:
            linesIndex.inc
            cursor.y += font.lineHeight.int32
            endLine(true)

          while formatRangeIndex < section.formatRanges.len and runeIndex >= section.formatRanges[formatRangeIndex].endIndex:
            formatRangeIndex.inc


          let subColor = if formatRangeIndex < section.formatRanges.len and runeIndex >= section.formatRanges[formatRangeIndex].startIndex:
            section.formatRanges[formatRangeIndex].color.get(effColor)
          else:
            effColor

          let img = font.glyphImage(rune)
          addQuad(WQuad(
            shape: rectShape(
              position = vec3f(pos.x, pos.y, 0.0f),
              dimensions = img.dimensions,
              forward = vec2f(1.0f, 0.0f)
            ),
            texCoords: simpleTexCoords(false, true),
            image: imageLike(img),
            color: subColor,
            beforeChildren: true), not isWhitespace, runeIndex)
          cursor.x = (pos.x.int + img.width).int32 + 1
    of SectionKind.Taxon:
      let lib = library(TaxonomyDisplay)
      let tdisp = lib.get(section.taxon)
      if tdisp.isSome and tdisp.get.icon.isSome:
        let disp = tdisp.get
        let copiedSection = RichTextSection(kind: SectionKind.Image, image: disp.icon.get, verticalAlignment: section.verticalAlignment, size: section.size, color: section.color)
        cursor.x += 5
        renderSection(copiedSection)
        cursor.x += 5
      else:
        let copiedSection = RichTextSection(kind: SectionKind.Text, text: " " & section.taxon.displayName & " ", verticalAlignment: section.verticalAlignment, size: section.size,
            color: section.color)
        renderSection(copiedSection)
    of SectionKind.Image:
      let font = overallFont.font((effSize).round.int)

      let img = section.image.asImage

      let effDim = vec2i(img.dimensions.x * pixelScale, img.dimensions.y * pixelScale)
      # let offset = typographyFont.ascent * (typographyFont.size / typographyFont.unitsPerEm) - effDim.y.float
      # let offset = -effDim.y.float
      # let offset =  typographyFont.typeface.ascent * typographyFont.scale - effDim.y.float

      # Center the image within the line. So far that seems like the best average point
      let ascent = font.ascent
      let offset = if richText.sections.len == 1:
        0.0f
      elif effDim.y < ascent:
        (ascent - effDim.y).float + 1.0f
      else:
        (font.lineHeight - effDim.y).float * 0.5f
      # echo "effDim: ", effDim.y.float, " line height: ", font.lineHeight, " ascent: ", font.ascent

      # Note: The offset * 0.5f is probably wrong, we may not be properly accounting for pixelScale at some
      # level
      addQuad(WQuad(
        shape: rectShape(
          position = vec3f(cursor.x.float, cursor.y.float + offset, 0.0f),
          dimensions = effDim,
          forward = vec2f(1.0f, 0.0f),
        ),
        texCoords: simpleTexCoords(),
        image: img,
        color: effColor,
        beforeChildren: true
      ), true, 0)
      cursor.x += (img.dimensions.x * pixelScale).int32
      if cursor.x >= bounds.x + bounds.width:
        cursor.x = 0
        cursor.y += res.lineInfo[res.lineInfo.len-1].maximumHeight.int32
    of VerticalBreak:
      let font = overallFont.font((effSize).round.int)

      cursor.y += font.lineHeight.int32 + (section.verticalOffset * pixelScale).int32
      cursor.x = 0
      endLine(true)
    of EnsureSpacing:
      cursor.x += section.spacing.int32
    endQuadGroup()


  for section in richText.sections:
    renderSection(section)
    sectionIndex.inc

  res.bounds = rect(minPos, maxPos - minPos)
  endLine(false)


  let halign = renderSettings.horizontalAlignment.get(richText.horizontalAlignment)
  if halign != HorizontalAlignment.Left:
    for line in res.lineInfo:
      if line.startIndex != line.endIndex:
        var maxX = 0
        for i in line.startIndex ..< line.endIndex:
          maxX.maxWith(res.quads[i].position.x.int + res.quads[i].dimensions.x.int)
        let widthDelta = bounds.width - maxX
        let shift =
          if halign == HorizontalAlignment.Center:
            widthDelta div 2
          else:
            widthDelta
        for i in line.startIndex ..< line.endIndex:
          res.quads[i].move(shift.float32, 0.0f, 0.0f)



  return res




when isMainModule:

  var rt = RichText(
    tint: some(rgba(1.0f, 1.0f, 1.0f, 1.0f)),
    size: 1.0f,
    # font : resources.font("november.regular.ttf"),
    font: resources.font("return-of-ganon.regular.ttf"),
    # font : resources.font("Goethe.ttf"),
    sections: @[
      RichTextSection(color: some(rgba(1.0f, 1.0f, 1.0f, 1.0f)), size: 1.0f, verticalAlignment: VerticalAlignment.Bottom, kind: SectionKind.Text, text: "This is text, not all")
    ]
  )


  let settings = RichTextRenderSettings(
    baseColor: none(color.RGBA),
    tint: none(color.RGBA),
    defaultFont: some(resources.font("november.regular.ttf"))
  )
  discard layout(rt, 16, rect(vec2i(0, 0), vec2i(200, 100)), 1, settings)
