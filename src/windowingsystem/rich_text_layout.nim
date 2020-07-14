import rich_text
import worlds/taxonomy
import graphics/image_extras
import windowing_rendering
import glm
import prelude
import arxmath
import graphics/color
import typography
import unicode
import resources
import flippy
import vmath
import stb_image/write as stbiw
import graphics/fonts
import options
import noto
import graphics/taxonomy_display

type QuadGroup = object
   startIndex: int
   endIndex: int
   verticalAlignment: VerticalAlignment

type LineInfo = object
   startY: int
   startIndex: int
   endIndex: int
   maximumHeight: int


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

   var lineInfo: seq[LineInfo] = @[LineInfo(maximumHeight: 0, startIndex: 0, startY: 0)]
   var quadGroups: seq[QuadGroup] = @[]

   proc addQuad(quad: WQuad, solidQuad: bool) =
      res.quads.add(quad)
      if solidQuad:
         lineInfo[lineInfo.len-1].maximumHeight.maxWith((quad.position.y.int + quad.dimensions.y) - cursor.y)
         minPos.minAll(vec2i(quad.position.x.int, quad.position.y.int))
         maxPos.maxAll(vec2i(quad.position.x.int + quad.dimensions.x.int, quad.position.y.int + quad.dimensions.y.int))
   proc splitQuadGroup() =
      let alignment = quadGroups[quadGroups.len-1].verticalAlignment
      quadGroups[quadGroups.len-1].endIndex = res.quads.len
      quadGroups.add(QuadGroup(startIndex: res.quads.len, verticalAlignment: alignment))
   proc endQuadGroup() =
      quadGroups[quadGroups.len-1].endIndex = res.quads.len
   proc endLine(startNew: bool) =
      if startNew: splitQuadGroup()
      lineInfo[lineInfo.len-1].endIndex = quadGroups.len
      if startNew: lineInfo.add(LineInfo(startIndex: quadGroups.len))

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

         let font = fontRoot.withPixelSize((effSize).round.int, pixelScale)
         let typographyFont = font.typographyFont()
         let typesetting = typeset(font, section.text, vec2i(0, 0), cursor, bounds.dimensions)

         for glyphPos in typesetting:
            let glyphInfo = font.glyph(glyphPos.character)
            var rect = glyphPos.rect

            let w = rect.w.int
            let h = rect.h.int

            lineInfo[lineInfo.len-1].maximumHeight.maxWith(typographyFont.lineHeight.int)
            maxPos.y.maxWith(typographyFont.lineHeight.int32)
            let isWhitespace = glyphPos.character == " " or glyphPos.character == "\t" or glyphPos.character == "\n"
            addQuad(WQuad(
               position: vec3f(rect.x.int.float, rect.y.int.float, 0.0f),
               dimensions: vec2i(w, h),
               forward: vec2f(1.0f, 0.0f),
               texCoords: simpleTexCoords(),
               image: imageLike(glyphInfo.image),
               color: effColor,
               beforeChildren: true), not isWhitespace)
            cursor.x = (rect.x + rect.w).int32 + 1
            if rect.y.int32 + rect.h.int32 >= cursor.y + (typographyFont.lineHeight * 0.9).int32:
               endLine(true)
               cursor.y += typographyFont.lineHeight.int32
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
         let img = section.image.asImage

         addQuad(WQuad(
            position: vec3f(cursor.x.float, cursor.y.float, 0.0f),
            dimensions: vec2i(img.dimensions.x * pixelScale, img.dimensions.y * pixelScale),
            forward: vec2f(1.0f, 0.0f),
            texCoords: simpleTexCoords(),
            image: img,
            color: effColor,
            beforeChildren: true
         ), true)
         cursor.x += (img.dimensions.x * pixelScale).int32
         if cursor.x >= bounds.x + bounds.width:
            cursor.x = 0
            cursor.y += lineInfo[lineInfo.len-1].maximumHeight.int32
      of VerticalBreak:
         let lineHeight = (overallFont.baseLineHeight.float * size.float * pixelScale.float).int32
         cursor.y += lineHeight
         cursor.x = 0
         endLine(true)
      of EnsureSpacing:
         warn "Ensure spacing in rich text not yet implemented"
         discard
      endQuadGroup()

   for section in richText.sections:
      renderSection(section)

   res.bounds = rect(minPos, maxPos - minPos)
   endLine(false)

   let halign = renderSettings.horizontalAlignment.get(richText.horizontalAlignment)
   if halign != HorizontalAlignment.Left:
      for line in lineInfo:
         if line.startIndex != line.endIndex:
            var maxX = 0
            for qi in line.startIndex ..< line.endIndex:
               for i in quadGroups[qi].startIndex ..< quadGroups[qi].endIndex:
                  maxX.maxWith(res.quads[i].position.x.int + res.quads[i].dimensions.x.int)
            let widthDelta = bounds.width - maxX
            let shift =
               if halign == HorizontalAlignment.Center:
                  widthDelta div 2
               else:
                  widthDelta
            for qi in line.startIndex ..< line.endIndex:
               for i in quadGroups[qi].startIndex ..< quadGroups[qi].endIndex:
                  res.quads[i].position.x += shift.float32



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
