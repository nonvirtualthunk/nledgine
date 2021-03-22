import worlds/taxonomy
import graphics/image_extras
import windowing_rendering
import glm
import prelude
import arxmath
import graphics/color
import resources
import graphics/fonts
import options
import noto


# const DefaultFontName* = "ChevyRaySoftsquare.ttf"
const DefaultFontName* = "pf_ronda_seven.ttf"

resources.preloadFont(DefaultFontName)

type
   SectionKind* {.pure.} = enum
      Text
      Taxon
      Image
      VerticalBreak
      EnsureSpacing

   TextPreference* {.pure.} = enum
      None
      Prefer
      Force

   RichTextFormatRange* = object
      color*: Option[color.RGBA]
      underline*: Option[color.RGBA]
      background*: Option[color.RGBA]
      startIndex*: int
      endIndex*: int

   RichTextSection* = object
      color*: Option[color.RGBA]
      size*: float
      verticalAlignment*: VerticalAlignment

      case kind*: SectionKind
      of SectionKind.Text:
         text*: string
         font*: ArxFontRoot
         formatRanges*: seq[RichTextFormatRange]
      of SectionKind.Taxon:
         taxon*: Taxon
      of SectionKind.Image:
         image*: ImageLike
      of SectionKind.VerticalBreak:
         verticalOffset*: int
      of SectionKind.EnsureSpacing:
         spacing*: int

   RichText* = object
      sections*: seq[RichTextSection]
      tint*: Option[color.RGBA]
      size*: float
      font*: ArxFontRoot
      horizontalAlignment*: HorizontalAlignment

   RichTextRenderSettings* = object
      baseColor*: Option[color.RGBA]
      tint*: Option[color.RGBA]
      defaultFont*: Option[ArxFontRoot]
      horizontalAlignment*: Option[HorizontalAlignment]
      textPreference*: TextPreference

   RichTextIndex* = object
      sectionIndex*: int
      subIndex*: int

   LineInfo* = object
      startY*: int
      startIndex*: int
      endIndex*: int
      maximumHeight*: int

   TextLayout* = object
      quads*: seq[WQuad]
      quadOrigins*: seq[RichTextIndex]
      bounds*: Recti
      lineInfo*: seq[LineInfo]
      lineHeight*: int

proc `==`*(a, b: RichTextSection): bool =
   a.kind == b.kind and
   (case a.kind:
   of SectionKind.Text: a.text == b.text and a.font == b.font
   of SectionKind.Taxon: a.taxon == b.taxon
   of SectionKind.Image: a.image == b.image
   of SectionKind.VerticalBreak: a.verticalOffset == b.verticalOffset
   of SectionKind.EnsureSpacing: a.spacing == b.spacing)

proc `==`*(a, b: RichText): bool =
   a.tint == b.tint and
   a.size == b.size and
   a.font == b.font and
   a.sections == b.sections

proc isEmpty*(r: RichText): bool =
   r.sections.isEmpty

proc nonEmpty*(r: RichText): bool =
   not isEmpty(r)



proc richText*(sections: seq[RichTextSection]): RichText =
   RichText(
      sections: sections,
      size: 1.0f
   )

proc richText*(section: RichTextSection): RichText =
   richText(@[section])

proc richText*(texts: varargs[RichText]): RichText =
   var s: seq[RichTextSection] = @[]
   for t in texts:
      s.add(t.sections)
   richText(s)

proc `&`*(a, b: RichText): RichText =
   result = a
   result.sections.add(b.sections)

proc add*(a: var RichText, b: RichText) =
   a.sections.add(b.sections)

proc add*(a: var RichText, b, c: RichText) =
   a.sections.add(b.sections)
   a.sections.add(c.sections)

proc richText*(str: string, size: float = 1.0f, color: Option[color.RGBA] = none(color.RGBA)): RichText =
   richText(RichTextSection(size: size, verticalAlignment: VerticalAlignment.Bottom, kind: SectionKind.Text, text: str, color: color))

proc richText*(img: ImageLike, size: float = 1.0f): RichText =
   richText(RichTextSection(size: size, verticalAlignment: VerticalAlignment.Bottom, kind: SectionKind.Image, image: img))

proc richText*(taxon: Taxon, size: float = 1.0f): RichText =
   richText(RichTextSection(size: size, kind: SectionKind.Taxon, taxon: taxon))

proc richTextSpacing*(spacing: int): RichText =
   richText(RichTextSection(size: 1.0f, kind: SectionKind.EnsureSpacing, spacing: spacing))

proc richTextVerticalBreak*(offset: int = 0): RichText =
   richText(RichTextSection(size: 1.0f, kind: SectionKind.VerticalBreak, verticalOffset: offset))

proc join*(s: seq[RichText], separator: RichText): RichText =
   var first = true
   for elem in s:
      if not first:
         result.add(separator)
      result.add(elem)
      first = false

proc readFromConfig*(v: ConfigValue, b: var RichText) =
   if v.isStr:
      b = richText(v.asStr)
   else:
      warn &"Invalid config to read into rich text value : {v}"


