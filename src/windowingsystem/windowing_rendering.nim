import glm
import arxmath
import graphics/color
import graphics/images
import noto

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

   WShapeKind* {.pure.} = enum
      Rect
      Polygon

   WShape* = object
      case kind*: WShapeKind
      of WShapeKind.Rect:
         position*: Vec3f
         dimensions*: Vec2i
         forward* : Vec2f
      of WShapeKind.Polygon:
         points*: array[4, Vec3f]

   WQuad* = object
      shape*: WShape
      image* : Image
      texCoords* : WTexCoords
      color* : RGBA
      beforeChildren* : bool

   ImageMetrics* = object
      borderWidth* : int
      centerColor* : RGBA
      outerOffset* : int


proc rectShape*(position: Vec3f, dimensions: Vec2i, forward: Vec2f = vec2f(1.0f,0.0f)): WShape = WShape(kind: WShapeKind.Rect, position: position, dimensions: dimensions, forward: forward)
proc polyShape*(points: array[4, Vec3f]) : WShape = WShape(kind: WShapeKind.Polygon, points : points)

proc move*(w: var WQuad, x : float, y : float, z : float) =
   case w.shape.kind:
      of WShapeKind.Rect:
         w.shape.position.x += x
         w.shape.position.y += y
         w.shape.position.z += z
      of WShapeKind.Polygon:
         for i in 0 ..< 4:
            w.shape.points[i].x += x
            w.shape.points[i].y += y
            w.shape.points[i].z += z

proc position*(w : WQuad): Vec3f =
   case w.shape.kind:
      of WShapeKind.Rect:
         w.shape.position
      of WShapeKind.Polygon:
         w.shape.points[0]

proc dimensions*(w: WQuad): Vec2i =
   case w.shape.kind:
      of WShapeKind.Rect:
         w.shape.dimensions
      of WShapeKind.Polygon:
         warn &"Doesn't really make sense to ask for the dimensions of a WQuad that's a poly"
         vec2i(0,0)

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