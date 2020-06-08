import glm
import arxmath
import graphics/color
import graphics/image_extras

type
   Bounds* = object
      origin* : Vec2f
      direction* : Vec2f
      dimensions* : Vec2f

   WVertex* = object
      vertex* : Vec3f
      color* : RGBA
      texCoords* : Vec2f
      boundsOrigin* : Vec2f
      boundsDirection* : Vec2f
      boundsDimensions* : Vec2f

   WTexCoordKind* = enum
      NoImage
      Simple
      SubRect
      RawTexCoords
      NormalizedTexCoords
      

   WTexCoords* = object
      case kind*: WTexCoordKind
      of NoImage:
         discard
      of Simple: 
         flip* : Vec2b
      of RawTexCoords: 
         rawTexCoords* : array[4,Vec2f]
      of NormalizedTexCoords:
         texCoords* : array[4,Vec2f]
      of SubRect: 
         subRect* : Rectf
         flipSubRect* : Vec2b

   WQuad* = object
      position* : Vec3f
      dimensions* : Vec2i
      forward* : Vec2f
      image* : ImageLike
      texCoords* : WTexCoords
      color* : RGBA
      beforeChildren* : bool

   ImageMetrics* = object
      borderWidth* : int
      centerColor* : RGBA
      outerOffset* : int

proc simpleTexCoords*(flipX : bool = false, flipY : bool = false) : WTexCoords =
   WTexCoords(kind : Simple, flip : vec2(flipX, flipY))
proc rawTexCoords*(tc : array[4,Vec2f]) : WTexCoords =
   WTexCoords(kind : RawTexCoords, rawTexCoords : tc)
proc normTexCoords*(tc : array[4,Vec2f]) : WTexCoords =
   WTexCoords(kind : NormalizedTexCoords, texCoords : tc)
proc subRectTexCoords*(sr : Rectf, flipX : bool = false, flipY : bool = false) : WTexCoords =
   WTexCoords(kind : SubRect, subRect : sr, flipSubRect : vec2(flipX,flipY))
proc noImageTexCoords*() : WTexCoords =
   WTexCoords(kind : NoImage)