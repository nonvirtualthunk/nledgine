import glm
import metric
import sugar
import times
import options
import worlds
import macros
import strutils
import bitops
import strformat
import tables

export metric
export sugar
export worlds
export strformat
export tables

type
   UnitOfTime* = Metric[metric.Time, float]

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

   Watcher*[T] = object
      function: () -> T
      lastValue: Option[T]

   Watchable*[T] = object
      value: T
      noChangeFlag: bool

   ComparisonKind* {.pure.} = enum
      GreaterThanOrEqualTo
      GreaterThan
      LessThan
      LessThanOrEqualTo
      EqualTo
      NotEqualTo


let programStartTime* = now()


proc `<`*(a: UnitOfTime, b: UnitOftime): bool =
   a.val < b.val

proc microseconds*(f: float): UnitOfTime =
   (f / 1000000.0) * metric.second

proc seconds*(f: float): UnitOfTime =
   (f) * metric.second

proc relTime*(): UnitOfTime =
   let dur = now() - programStartTime
   return inMicroseconds(dur).float.microseconds

proc inSeconds*(u: UnitOfTime): float =
   u.as(second)

proc `$`*(t: UnitOfTime): string =
   fmt"{t.as(second)}s"

# proc vec3f*(v : Vec3i) : Vec3f =
#    vec3f(v.x.float, v.y.float, v.z.float)

proc vec2i*(x: int, y: int): Vec2i =
   vec2i(x.int32, y.int32)

proc vec2f*(x: int, y: int): Vec2f =
   vec2f(x.float, y.float)

proc vec3f*(x: int, y: int, z: int): Vec3f =
   vec3f(x.float, y.float, z.float)

proc Vec2f*(v: Vec2i): Vec2f = vec2f(v.x, v.y)

converter toVec2i*(v: Vec2[int]): Vec2i = vec2i(v.x.int32, v.y.int32)
converter toVec2int*(v: Vec2i): Vec2[int] = vec2(v.x.int, v.y.int)

proc minIndexBy*[T, U](s: seq[T], mapFn: (T) -> U): Option[int] =
   result = none(int)
   var lowestMapped: Option[U] = none(U)
   for i, v in s:
      let mapped = mapFn(v)
      if not lowestMapped.isSome or lowestMapped.get < mapped:
         lowestMapped = some(mapped)
         result = some(i)



proc minBy*[T, U](s: seq[T], mapFn: (T) -> U): Option[T] =
   result = none(T)
   var lowestMapped: Option[U] = none(U)
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
   let op = newLit(" " & arg[0].repr & " ")
   let lhs = arg[1]
   let rhs = arg[2]

   let li = newLit($lineInfoObj(arg))
   result = quote do:
      if not (`arg`):
         echo `li`
         raise newException(AssertionError, $`lhs` & `op` & $`rhs`)

iterator enumValues*[T](t: typedesc[T]): T =
   for o in ord(low(t))..ord(high(t)):
      yield T(o)

iterator axes*(): Axis =
   yield Axis.X
   yield Axis.Y
   yield AXis.Z

iterator axes3d*(): Axis =
   yield Axis.X
   yield Axis.Y
   yield AXis.Z

iterator axes2d*(): Axis =
   yield Axis.X
   yield Axis.Y

proc is2D*(axis: Axis): bool = axis == Axis.X or axis == Axis.Y

proc oppositeAxis2d*(axis: Axis): Axis =
   if axis == Axis.X:
      Axis.Y
   else:
      Axis.X

converter toOrd*(axis: Axis): int = axis.ord



proc `[]=`*(v: var Vec3i, axis: Axis, value: int) =
   v[axis.ord] = value.int32

proc `[]`*(v: Vec3i, axis: Axis): int = v[axis.ord]

proc `[]=`*(v: var Vec2i, axis: Axis, value: int) =
   v[axis.ord] = value.int32

proc `[]`*(v: Vec2i, axis: Axis): int = v[axis.ord]

proc `[]=`*(v: var Vec2f, axis: Axis, value: float) =
   v[axis.ord] = value

proc `[]`*(v: Vec2f, axis: Axis): float = v[axis.ord]

proc `*`*(v: Vec2i, m: int): Vec2i = vec2i(v.x * m, v.y * m)

proc `div`*(a: Vec2i, b: int): Vec2i =
   vec2i(a.x div b, a.y div b)

proc `=~=`*[A, B](a: A, b: B): bool =
   abs(b.A - a) < 0.000001.A


proc parseIntOpt*(str: string): Option[int] =
   try:
      some(parseInt(str))
   except ValueError:
      none(int)

proc parseFloatOpt*(str: string): Option[float] =
   try:
      some(parseFloat(str))
   except ValueError:
      none(float)

proc removeAll*[T](s: var seq[T], toRemove: seq[T]) =
   var newSeq: seq[T]
   for v in s:
      if not toRemove.contains(v):
         newSeq.add(v)
   s = newSeq

iterator items*[T](opt: Option[T]): T =
   if opt.isSome:
      yield opt.get


const a: uint64 = 0xffffda61.uint64
proc permute*(x: int): int =
   ((a * (x.uint64.bitand(0xffffffff.uint64))) + (x shr 32).uint64).int.abs

proc isEmpty*[T](s: seq[T]): bool = s.len == 0
proc nonEmpty*[T](s: seq[T]): bool = s.len != 0

proc nonEmpty*[K, V](t: Table[K, V]): bool = s.len != 0

proc hasChanged*[T](w: var Watcher[T]): bool =
   if w.lastValue.isNone:
      w.lastValue = some(w.function())
      true
   else:
      let newValue = w.function()
      if newValue != w.lastValue.get:
         w.lastValue = some(newValue)
         true
      else:
         false

proc peekChanged*[T](w: Watcher[T]): bool =
   if w.lastValue.isNone:
      true
   else:
      w.function() == w.lastValue.get

proc hasChanged*[T](w: var Watchable[T]): bool =
   result = not w.noChangeFlag
   w.noChangeFlag = true

proc peekChanged*[T](w: Watchable[T]): bool =
   result = not w.noChangeFlag

proc setTo*[T](w: var Watchable[T], v: T) =
   if w.value != v:
      w.value = v
      w.noChangeFlag = false

converter toWatchedValue*[T](w: Watchable[T]): T = w.value


proc watcher*[T](f: () -> T): Watcher[T] =
   Watcher[T](function: f)

macro watch*(stmts: typed): untyped =
   result = quote do:
      Watcher[typeof(`stmts`)](function: proc(): typeof(`stmts`) =
         `stmts`
      )

proc currentValue*[T](w: Watcher[T]): T =
   if w.lastValue.isSome:
      w.lastValue.get
   else:
      w.function()

proc clear*[T](s: var seq[T]) =
   s.setLen(0)

proc last*[T](s: seq[T]): T = s[s.len-1]

proc maxWith*[T](v: var T, other: T) =
   v = max(v, other)

proc minWith*[T](v: var T, other: T) =
   v = min(v, other)


template matcher*(value: typed, stmts: untyped) =
   block:
      let matchTarget {.inject.} = value
      stmts

template caseSome*(var1: untyped, stmts: untyped): untyped =
   if matchTarget.isSome:
      let `var1` {.inject.} = matchTarget.get
      stmts
      break

template caseNone*(stmts: untyped): untyped =
   if matchTarget.isNone:
      stmts
      break

template getOrCreate*[K, V](t: var Table[K, V], k: K, stmts: typed): V =
   if t.contains(k):
      t[k]
   else:
      let tmp = stmts
      t[k] = tmp
      tmp


proc `x=`*(v: var Vec3i, t: int) =
   v[0] = t.int32

proc `y=`*(v: var Vec3i, t: int) =
   v[1] = t.int32

proc `z=`*(v: var Vec3i, t: int) =
   v[2] = t.int32

proc toSignedString*[T](t: T): string =
   if t < 0:
      $t
   else:
      &"+{t}"

proc normalizeSafe*(v: Vec3f): Vec3f =
   let l = v.length
   if l > 0.0:
      v.normalize
   else:
      v

template ifPresent*[T](opt: Option[T], stmts: untyped) =
   if opt.isSome:
      let it {.inject.} = opt.get
      stmts

template ifPresent*[T](opt: Option[T], varName: untyped, stmts: untyped) =
   if opt.isSome:
      let `varName` {.inject.} = opt.get
      stmts

proc addOpt*[T](s: var seq[T], opt: Option[T]) =
   if opt.isSome:
      s.add(opt.get)

proc isTrueFor*[T](comp: ComparisonKind, a: T, b: T): bool =
   case comp:
   of ComparisonKind.GreaterThan: a > b
   of ComparisonKind.GreaterThanOrEqualTo: a >= b
   of ComparisonKind.LessThan: a < b
   of ComparisonKind.LessThanOrEqualTo: a <= b
   of ComparisonKind.EqualTo: a == b
   of ComparisonKind.NotEqualTo: a != b
