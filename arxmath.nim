import glm

type Rect*[T] = object
    position* : Vec2[T]
    dimensions* : Vec2[T]

type Rectf* = Rect[float]
type Recti* = Rect[int]

proc rect*[T](pos : Vec2[T], dim : Vec2[T]) : Rect[T] =
    Rect[T](position : pos, dimensions : dim)

proc width*[T](r : Rect[T]) : T = r.dimensions.x
proc height*[T](r : Rect[T]) : T = r.dimensions.y
proc x*[T](r : Rect[T]) : T = r.position.x
proc y*[T](r : Rect[T]) : T = r.position.y

proc `==`*[T](a : Rect[T], b : Rect[T]) : bool = 
    a.position == b.position and a.dimensions == b.dimensions

