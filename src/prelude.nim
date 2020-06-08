import glm
import metric
import sugar
import times
import options
import worlds
import macros
import strutils

export metric
export sugar
export worlds

type 
    UnitOfTime* = Metric[metric.Time,float]

    Axis* = enum
        X
        Y
        Z

    HorizontalAlignment* {.pure.} = enum
        Left
        Right
        Center

    VerticalAlignment* {.pure.} = enum
        Top
        Bottom
        Center


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
    


macro echoAssert*(arg: untyped): untyped =
        # all node kind identifiers are prefixed with "nnk"
        arg.expectKind nnkInfix
        arg.expectLen 3
        # operator as string literal
        let op  = newLit(" " & arg[0].repr & " ")
        let lhs = arg[1]
        let rhs = arg[2]

        let li = newLit($lineInfoObj(arg))
        result = quote do:
            if not (`arg`):
                echo `li`
                raise newException(AssertionError,$`lhs` & `op` & $`rhs`)

iterator enumValues*[T](t : typedesc[T]) : T =
    for o in ord(low(t))..ord(high(t)):
        yield T(o)

iterator axes*() : Axis =
    yield Axis.X
    yield Axis.Y
    yield AXis.Z

iterator axes2d*() : Axis =
    yield Axis.X
    yield Axis.Y

proc oppositeAxis2d*(axis : Axis) : Axis = 
    if axis == Axis.X:
        Axis.Y
    else:
        Axis.X

converter toOrd*(axis : Axis) : int = axis.ord



proc `[]=`*(v : var Vec3i, axis : Axis, value : int) =
    v[axis.ord] = value.int32

proc `[]`*(v : Vec3i, axis : Axis) : int = v[axis.ord]

proc `[]=`*(v : var Vec2i, axis : Axis, value : int) =
    v[axis.ord] = value.int32

proc `[]`*(v : Vec2i, axis : Axis) : int = v[axis.ord]

proc `[]=`*(v : var Vec2f, axis : Axis, value : float) =
    v[axis.ord] = value

proc `[]`*(v : Vec2f, axis : Axis) : float = v[axis.ord]

proc `*`*(v : Vec2i, m : int) : Vec2i = vec2i(v.x * m, v.y * m)

proc `div`*(a : Vec2i, b : int) : Vec2i =
    vec2i(a.x div b, a.y div b)

proc `=~=`*[A,B](a : A, b : B) : bool =
    abs(b.A - a) < 0.000001.A


proc parseIntOpt*(str : string) : Option[int] =
    try:
        some(parseInt(str))
    except ValueError:
        none(int)

proc parseFloatOpt*(str : string) : Option[float] =
    try:
        some(parseFloat(str))
    except ValueError:
        none(float)