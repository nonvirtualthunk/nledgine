import glm
import options

type Rect*[T] = object
   position*: Vec2[T]
   dimensions*: Vec2[T]

type Rectf* = Rect[float32]
type Recti* = Rect[int32]

proc rect*[T](pos: Vec2[T], dim: Vec2[T]): Rect[T] =
   Rect[T](position: pos, dimensions: dim)

proc width*[T](r: Rect[T]): T = r.dimensions.x
proc height*[T](r: Rect[T]): T = r.dimensions.y
proc x*[T](r: Rect[T]): T = r.position.x
proc y*[T](r: Rect[T]): T = r.position.y

proc `==`*[T](a: Rect[T], b: Rect[T]): bool =
   a.position == b.position and a.dimensions == b.dimensions



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

