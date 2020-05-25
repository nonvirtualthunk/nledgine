import glm
import metric
import sugar
import times

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