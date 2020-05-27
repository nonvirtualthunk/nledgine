import glm
import metric
import sugar
import times
import options

export metric
export sugar

type UnitOfTime* = Metric[metric.Time,float]


let programStartTime* = now()


proc `<`* (a : UnitOfTime, b : UnitOftime): bool =
    a.val < b.val

proc microseconds*(f : float) : UnitOfTime =
    (f / 1000000.0) * metric.second

proc seconds*(f : float) : UnitOfTime =
    (f) * metric.second

proc relTime*() : UnitOfTime =
    let dur = now() - programStartTime
    return inMicroseconds(dur).float.microseconds

# proc vec3f*(v : Vec3i) : Vec3f =
#     vec3f(v.x.float, v.y.float, v.z.float)

proc vec2i*(x : int, y : int) : Vec2i =
    vec2i(x.int32, y.int32)

proc vec2f*(x : int, y : int) : Vec2f =
    vec2f(x.float, y.float)

converter toVec2i*(v : Vec2[int]) : Vec2i = vec2i(v.x.int32, v.y.int32)
converter toVec2int*(v : Vec2i) : Vec2[int] = vec2(v.x.int, v.y.int)

proc minIndexBy*[T, U](s : seq[T], mapFn : (T) -> U) : Option[int] =
    result = none(int)
    var lowestMapped : Option[U] = none(U)
    for i, v in s:
        let mapped = mapFn(v)
        if not lowestMapped.isSome or lowestMapped.get < mapped:
            lowestMapped = some(mapped)
            result = some(i)
    


proc minBy*[T, U](s : seq[T], mapFn : (T) -> U) : Option[T] =
    result = none(T)
    var lowestMapped : Option[U] = none(U)
    for v in s:
        let mapped = mapFn(v)
        if not lowestMapped.isSome or lowestMapped.get < mapped:
            lowestMapped = some(mapped)
            result = some(v)
    
