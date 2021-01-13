import glm
import options
import prelude

type Rect*[T] = object
   position*: Vec2[T]
   dimensions*: Vec2[T]

type Rectf* = Rect[float32]
type Recti* = Rect[int32]

proc rect*[T](pos: Vec2[T], dim: Vec2[T]): Rect[T] =
   Rect[T](position: pos, dimensions: dim)

proc rect*[T](x: T, y: T, width: T, height: T): Rect[T] =
   result.position[0] = x
   result.position[1] = y
   result.dimensions[0] = width
   result.dimensions[1] = height

proc rectContaining*[T](vs : seq[Vec2[T]]) : Rect[T] =
   if vs.nonEmpty:
      var minX = vs[0].x
      var minY = vs[0].y
      var maxX = minX
      var maxY = minY
      for i in 1 ..< vs.len:
         let v = vs[i]
         minX = min(v.x, minX)
         maxX = max(v.x, maxX)
         minY = min(v.y, minY)
         maxY = max(v.y, maxY)
      result.position.x = minX
      result.position.y = minY
      result.dimensions.x = maxX - minX
      result.dimensions.y = maxY - minY

proc width*[T](r: Rect[T]): T = r.dimensions.x
proc height*[T](r: Rect[T]): T = r.dimensions.y
proc x*[T](r: Rect[T]): T = r.position.x
proc y*[T](r: Rect[T]): T = r.position.y

proc min*[T](r: Rect[T], axis: Axis): T = r.position[axis.ord]
proc max*[T](r: Rect[T], axis: Axis): T = r.position[axis.ord] + r.dimensions[axis.ord]

proc `==`*[T](a: Rect[T], b: Rect[T]): bool =
   a.position == b.position and a.dimensions == b.dimensions

proc hasIntersection*[T](a: Rect[T], b : Rect[T]): bool =
   let amin = a.position
   let amax = a.position + a.dimensions
   let bmin = b.position
   let bmax = b.position + b.dimensions

   if amin.x > bmax.x or bmin.x > amax.x:
      false
   elif amin.y > bmax.y or bmin.y > amax.y:
      false
   else:
      true

proc minAll*(a: var Vec3i, b: Vec3i) =
   a.x = a.x.min(b.x)
   a.y = a.y.min(b.y)
   a.z = a.z.min(b.z)


proc minAll*(a: var Vec2i, b: Vec2i) =
   a.x = a.x.min(b.x)
   a.y = a.y.min(b.y)

proc maxAll*(a: var Vec2i, b: Vec2i) =
   a.x = a.x.max(b.x)
   a.y = a.y.max(b.y)

proc quadraticSolver*(a: float, b: float, c: float): Option[(float, float)] =
   let d = b*b - 4.0f*a*c
   if d >= 0:
      let r1 = (-b + d) / (a*2.0f)
      let r2 = (-b - d) / (a*2.0f)
      some((r1, r2))
   else:
      none((float, float))

