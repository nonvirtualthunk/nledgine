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

const DefaultFontName* = "ChevyRaySoftsquare.ttf"

resources.preloadFont(DefaultFontName)

type
   SectionKind* = enum
      Text
      Taxon
      Image
      VerticalBreak
      EnsureSpacing



   RichTextSection* = object
      color* : Option[color.RGBA]
      size* : float
      verticalAlignment* : VerticalAlignment

      case kind : SectionKind
      of Text: 
         text : string
         font : ArxFontRoot
      of Taxon: 
         taxon : Taxon
      of Image: 
         image : ImageLike
      of VerticalBreak: 
         verticalOffset : int
      of EnsureSpacing: 
         spacing : int

   RichText* = object 
      sections* : seq[RichTextSection]
      tint* : Option[color.RGBA]
      size* : float
      font* : ArxFontRoot



   TextLayout* = object
      quads* : seq[WQuad]
      bounds* : Recti

type QuadGroup = object
   startIndex : int
   len : int
   center : bool

proc `==`*(a,b : RichTextSection) : bool =
   a.kind == b.kind and
   (case a.kind:
   of SectionKind.Text: a.text == b.text and a.font == b.font
   of SectionKind.Taxon: a.taxon == b.taxon
   of SectionKind.Image: a.image == b.image
   of SectionKind.VerticalBreak: a.verticalOffset == b.verticalOffset
   of SectionKind.EnsureSpacing: a.spacing == b.spacing)

proc `==`*(a,b : RichText) : bool =
   a.tint == b.tint and
   a.size == b.size and
   a.font == b.font and
   a.sections == b.sections



proc layout*(richText : RichText, baseColor : RGBA, tint : Option[color.RGBA], defaultFont : ArxFontRoot, size : int, bounds : Recti, pixelScale : int) : TextLayout =
   var minPos : Vec2i = vec2i(0,0)
   var maxPos : Vec2i = vec2i(0,0)

   var cursor = vec2i(0,0)

   let richTextSize = if richText.size == 0.0 : 1.0 else: richText.size

   for section in richText.sections:
      case section.kind:
      of Text: 
         let fontRoot = if section.font != nil:
            section.font
         elif richText.font != nil:
            richText.font
         elif defaultFont != nil:
            defaultFont
         else:
            resources.font(DefaultFontName)
            # resources.font("return-of-ganon.regular.ttf")
            # resources.font("pf_ronda_seven.ttf")
            # resources.font("ChevyRaySoftsquare.ttf")
         
         let sectionSize = if section.size == 0.0 : 1.0 else: section.size
         let font = fontRoot.withPixelSize((size.float * sectionSize * richTextSize).round.int, pixelScale)
         let typesetting = typeset(font, section.text, vec2i(0,0), cursor, bounds.dimensions)
         var effColor = baseColor
         if section.color.isSome:
            effColor = section.color.get
         if richText.tint.isSome:
            effColor = mix(effColor, richText.tint.get, 0.5)
         if tint.isSome:
            effColor = mix(effColor, tint.get, 0.5)

         
         # var img = createImage(vec2i(200,100))
         for glyphPos in typesetting:
            let glyphInfo = font.glyph(glyphPos.character)
            let rect = glyphPos.rect
            minPos.minAll(vec2i(rect.x.int, rect.y.int))
            maxPos.maxAll(vec2i(rect.x.int + rect.w.int, rect.y.int + rect.h.int))

            result.quads.add(WQuad(
               position : vec3f(rect.x.float, rect.y.float, 0.0f),
               dimensions : vec2i(rect.w.int, rect.h.int), 
               forward : vec2f(1.0f,0.0f), 
               texCoords : simpleTexCoords(), 
               image : imageLike(glyphInfo.image),
               color : effColor,
               beforeChildren : true))
            # echo "glyph offset: ", glyphOffset
            # echo "Drawing rect ", rect

            # img.copyFrom(glyphInfo.image, vec2i(rect.x.int, rect.y.int))
         
            # discard stbiw.writePNG(
            #    "/tmp/out.png",
            #    img.width,
            #    img.height,
            #    img.channels,
            #    img.data)

         result.bounds = rect(minPos, maxPos - minPos)
      of Taxon:
         warn "Taxon rendering in rich text not yet implemented"
         discard
      of Image:
         warn "Image rendering in rich text not yet implemented"
         discard
      of VerticalBreak:
         warn "Vertical break rendering in rich text not yet implemented"
         discard
      of EnsureSpacing:
         warn "Ensure spacing in rich text not yet implemented"
         discard

      # case section.kind:
      # of Text:
      # of Taxon:
      # of Image:
      # of VerticalBreak:
      # of EnsureSpacing:


   discard



proc richTextSection*(str : string, size : float = 1.0f, color : Option[color.RGBA] = none(color.RGBA)) : RichTextSection =
   RichTextSection(size : size, verticalAlignment : VerticalAlignment.Bottom, kind : SectionKind.Text, text : str, color : color)

proc richTextSection*(img : ImageLike, size : float = 1.0f) : RichTextSection =
   RichTextSection(size : 1.0f, verticalAlignment : VerticalAlignment.Bottom, kind : SectionKind.Image, image : img)

proc richText*(str : string) : RichText =
   RichText(
      size: 1.0f,
      sections : @[richTextSection(str)]
   )

proc readFromConfig*(v : ConfigValue, b : var RichText) =
   if v.isStr:
      b = richText(v.asStr)
   else:
      warn "Invalid config to read into rich text value : ", v



when isMainModule:

   var rt = RichText(
      tint : some(rgba(1.0f,1.0f,1.0f,1.0f)),
      size : 1.0f,
      # font : resources.font("november.regular.ttf"),
      font : resources.font("return-of-ganon.regular.ttf"),
      # font : resources.font("Goethe.ttf"),
      sections : @[
         RichTextSection(color : some(rgba(1.0f,1.0f,1.0f,1.0f)), size : 1.0f, verticalAlignment : VerticalAlignment.Bottom, kind : SectionKind.Text, text : "This is text, not all")
      ]
   )

   

   discard layout(rt, rgba(0.0f,0.0f,0.0f,1.0f), none(color.RGBA), resources.font("november.regular.ttf"), 16, rect(vec2i(0,0), vec2i(200, 100)))

