import glm
# import metric
import sugar
import times
import options
import worlds
import macros
import strutils
import bitops
import strformat
import tables
import sets
import math

# export metric
export sugar
export worlds
export strformat
export tables
export options
import hashes

type
  # UnitOfTime* = Metric[metric.Time, float]

  UnitOfTime* = object
    seconds*: float

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

  OneShot* = object
    fired*: bool

  ComparisonKind* {.pure.} = enum
    GreaterThanOrEqualTo
    GreaterThan
    LessThan
    LessThanOrEqualTo
    EqualTo
    NotEqualTo

  BooleanOperator* = enum
    OR,
    AND,
    XOR,
    NOT

  Vec2d* = Vec2[float64]
  Vec3s* = Vec3[int16]
  Vec3i8* = Vec3[int8]

  Cardinals2D* {.pure.} = enum
    Left
    Up
    Right
    Down


let CardinalVectors2D* = [vec2i(-1,0), vec2i(0,1), vec2i(1,0), vec2i(0,-1)]
let CardinalVectors3D* = [vec3i(-1,0,0), vec3i(0,1,0), vec3i(1,0,0), vec3i(0,-1,0), vec3i(0,0,-1), vec3i(0,0,1)]
let CardinalVectors3Df* = [vec3f(-1,0,0), vec3f(0,1,0), vec3f(1,0,0), vec3f(0,-1,0), vec3f(0,0,-1), vec3f(0,0,1)]

proc cardinalVector*(c : Cardinals2D) : Vec2i = CardinalVectors2D[c.ord]
proc cardinalVector3D*(c : Cardinals2D) : Vec3i = CardinalVectors3D[c.ord]
proc cardinalVector3Df*(c : Cardinals2D) : Vec3f = CardinalVectors3Df[c.ord]

proc opposite*(c: Cardinals2D): Cardinals2D =
  case c:
    of Cardinals2D.Left: Cardinals2D.Right
    of Cardinals2D.Right: Cardinals2D.Left
    of Cardinals2D.Up: Cardinals2D.Down
    of Cardinals2D.Down: Cardinals2D.Up

proc fire*(oneShot: var OneShot): bool =
  if oneShot.fired:
    false
  else:
    oneShot.fired = true
    true

let programStartTime* = now()


proc `<`*(a: UnitOfTime, b: UnitOftime): bool =
  a.seconds < b.seconds

proc `<=`*(a: UnitOfTime, b: UnitOftime): bool =
  a.seconds <= b.seconds

proc `>=`*(a: UnitOfTime, b: UnitOftime): bool =
  a.seconds >= b.seconds

proc `>`*(a: UnitOfTime, b: UnitOftime): bool =
  a.seconds > b.seconds

proc microseconds*(f: float): UnitOfTime =
  UnitOfTime(seconds: (f / 1000000.0))

proc seconds*(f: float): UnitOfTime =
  UnitOfTime(seconds: f)

proc relTime*(): UnitOfTime =
  let dur = now() - programStartTime
  return inMicroseconds(dur).float.microseconds

proc inSeconds*(u: UnitOfTime): float =
  u.seconds

proc `$`*(t: UnitOfTime): string =
  let seconds = t.seconds
  if seconds < 0.1:
    let millis = seconds * 1000.0f
    fmt"{millis:.2f}ms"
  else:
    fmt"{t.seconds:.2f}s"

proc `+`*(a,b : UnitOfTime): UnitOfTime =
  UnitOfTime(seconds: a.seconds + b.seconds)

proc `-`*(a,b : UnitOfTime): UnitOfTime =
  UnitOfTime(seconds: a.seconds - b.seconds)

proc `/`*(a : UnitOfTime, b : float): UnitOfTime =
  UnitOfTime(seconds: a.seconds / b)

# proc vec3f*(v : Vec3i) : Vec3f =
#   vec3f(v.x.float, v.y.float, v.z.float)

proc vec2i*(x: int, y: int): Vec2i =
  vec2i(x.int32, y.int32)

proc vec3i*(x: int, y: int, z: int): Vec3i =
  vec3i(x.int32, y.int32, z.int32)

proc vec3i*(v: Vec2i, z: int): Vec3i =
  vec3i(v.x, v.y, z.int32)

proc vec2f*(x: int, y: int): Vec2f =
  vec2f(x.float, y.float)


proc vec2d*(x: int, y: int): Vec2d =
  vec2d(x.float, y.float)

proc vec3f*(x: int, y: int, z: int): Vec3f =
  vec3f(x.float, y.float, z.float)

proc vec2f*(v: Vec2i): Vec2f = vec2f(v.x, v.y)
proc vec2d*(v: Vec2i): Vec2d = vec2d(v.x, v.y)

proc vec2i8*(x,y: int)  : Vec2[int8] {.inline.} = Vec2[int8](arr: [x.int8, y.int8])
proc vec2i8*(x,y: int8)  : Vec2[int8] {.inline.} = Vec2[int8](arr: [x, y])
proc vec2i8*(v: Vec2i)  : Vec2[int8] {.inline.} = Vec2[int8](arr: [v.x.int8, v.y.int8])

proc vec2s*(x,y: int)  : Vec2[int16] {.inline.} = Vec2[int16](arr: [x.int16, y.int16])
proc vec2s*(x,y: int16)  : Vec2[int16] {.inline.} = Vec2[int16](arr: [x, y])
proc vec2s*(v: Vec2i)  : Vec2[int16] {.inline.} = Vec2[int16](arr: [v.x.int16, v.y.int16])

proc vec3s*(x,y,z: int)  : Vec3[int16] {.inline.} = Vec3[int16](arr: [x.int16, y.int16, y.int16])
proc vec3s*(x,y,z: int16)  : Vec3[int16] {.inline.} = Vec3[int16](arr: [x, y, z])
proc vec3s*(v: Vec3i)  : Vec3[int16] {.inline.} = Vec3[int16](arr: [v.x.int16, v.y.int16, v.z.int16])

proc vec3i8*(x,y,z: int)  : Vec3i8 {.inline.} = Vec3[int8](arr: [x.int8, y.int8, y.int8])
proc vec3i8*(x,y,z: int8)  : Vec3i8 {.inline.} = Vec3[int8](arr: [x, y, z])
proc vec3i8*(v: Vec3i)  : Vec3i8 {.inline.} = Vec3[int8](arr: [v.x.int8, v.y.int8, v.z.int8])

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

proc subseq*[T](s: seq[T], start: int, len: int): seq[T] =
  for i in start ..< min(start + len, s.len):
    result.add(s[i])


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

proc enumValuesSeq*[T](t: typedesc[T]): seq[T] =
  for ev in enumValues(t):
    result.add(ev)

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
proc `*`*(v: Vec3s, f: float32): Vec3s = vec3s((v.x.float32 * f).int16, (v.y.float32 * f).int16, (v.z.float32 * f).int16)

proc `+`*(a,b: Vec3i8) : Vec3i8 = vec3i8(a.x + b.x, a.y + b.y, a.z + b.z)
proc `-`*(a,b: Vec3i8) : Vec3i8 = vec3i8(a.x + b.x, a.y + b.y, a.z + b.z)
proc vec3i*(a: Vec3i8) : Vec3i = vec3i(a.x.int, a.y.int, a.z.int)

proc `div`*(a: Vec2i, b: int): Vec2i =
  vec2i(a.x div b, a.y div b)

proc `=~=`*[A, B](a: A, b: B): bool =
  abs(b.A - a) < 0.000001.A


proc parseIntOpt*(str: string): Option[int] =
  try:
    some(parseInt(str))
  except ValueError:
    none(int)

proc parseBoolOpt*(str: string): Option[bool] =
  try:
    some(parseBool(str))
  except ValueError:
    none(bool)

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
  (((a * (x.uint64.bitand(0xffffffff.uint64))) + (x shr 32).uint64) mod 2000000000).int.abs

proc isEmpty*[T](s: seq[T]): bool = s.len == 0
proc isEmpty*(s: string): bool = s.len == 0
proc nonEmpty*[T](s: seq[T]): bool = s.len != 0
proc nonEmpty*(s: string): bool = s.len != 0

proc nonEmpty*[K, V](t: Table[K, V]): bool = t.len != 0
proc nonEmpty*[K](t: HashSet[K]): bool = t.len != 0
proc isEmpty*[K](t: HashSet[K]): bool = t.len == 0

proc hash*(v : Vec2i) : Hash =
  var h : Hash
  h = h !& v.x
  h = h !& v.y
  !$h

proc hash*(v : Vec3i) : Hash =
  var h : Hash
  h = h !& v.x
  h = h !& v.y
  h = h !& v.z
  !$h

proc incl*[K](t: var HashSet[K], s: seq[K]) =
  for v in s:
    t.incl(v)

proc excl*[K](t: var HashSet[K], s: seq[K]) =
  for v in s:
    t.excl(v)

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

proc max*(v: Vec3i, i: int): Vec3i =
  vec3i(max(v.x, i), max(v.y, i), max(v.y, i))

proc min*(v: Vec3i, i: int): Vec3i =
  vec3i(min(v.x, i), min(v.y, i), min(v.y, i))

proc get*[K,V](t: Table[K,V], k: K) : Option[V] =
  if t.hasKey(k):
    some(t[k])
  else:
    none(V)

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

proc normalizeSafe*(v: Vec2f): Vec2f =
  let l2 = v.length2
  if l2 > 0.0:
    v / sqrt(l2)
  else:
    v

proc lengthSafe*(v: Vec2f): float =
  let l2 = v.length2
  if l2 > 0.0f:
    sqrt(l2)
  else:
    0.0f

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

proc distance*[T](x1: T, y1: T, x2: T, y2: T): T =
  let dx = x2-x1
  let dy = y2-y1
  let sq = dx*dx+dy*dy
  if sq != 0:
    sqrt(sq)
  else:
    0

proc distance*[T](x1: T, y1: T, z1: T, x2: T, y2: T, z2: T): T =
  let dx = x2-x1
  let dy = y2-y1
  let dz = z2-z1
  let sq = dx*dx+dy*dy+dz*dz
  if sq != 0:
    sqrt(sq)
  else:
    0

proc distance*[T](a, b: Vec2[T]) : float = distance(a.x.float, a.y.float, b.x.float, b.y.float)
proc distance*[T](a, b: Vec3[T]) : float = distance(a.x.float, a.y.float, a.z.float, b.x.float, b.y.float, b.z.float)

template findIt*[T](s: seq[T], pred: untyped): untyped =
  var result: Option[T]
  for it {.inject.} in items(s):
    if pred: result = some(it)
  result

template indexWhereIt*[T](s: seq[T], pred: untyped): untyped =
  var resultIndex = -1
  var index = 0
  while resultIndex == -1 and index < s.len:
    let it {.inject.} = s[index]
    if pred:
     resultIndex = index
     break
    index.inc
  resultIndex

proc delValue*[T](s : var seq[T], value: T) : bool {.discardable.} =
  let idx = s.find(value)
  if idx == -1:
   false
  else:
   s.del(idx)
   true

proc deleteValue*[T](s : var seq[T], value: T) : bool {.discardable.} =
  let idx = s.find(value)
  if idx == -1:
   false
  else:
   s.delete(idx)
   true

proc withoutValue*[T](s : seq[T], value: T) : seq[T] =
  for v in s:
   if v != value:
    result.add(v)

proc fromCamelCase*(s : string) : string =
  result = ""
  for i in 0 ..< s.len:
   let c = s[i]
   if i != 0 and c.isUpperAscii:
    result.add(' ')
   result.add(c.toLowerAscii)

proc capitalize*(s : string) : string =
  result = ""
  for i in 0 ..< s.len:
   let c = s[i]
   if i == 0 or s[i - 1] == ' ':
    result.add(c.toUpperAscii)
   else:
    result.add(c)


proc getStackTrace*() : seq[PFrame] =
  var tmp = getFrame()
  while tmp != nil:
   result.add(tmp)
   tmp = tmp.prev

proc singleLineStackTrace*() :string =
  var accum = ""
  var tmp = getFrame()
  while tmp != nil:
   let fileStr = ($tmp.filename).split('/')[^1].replace(".nim","")
   accum.add(&"{fileStr}:{tmp.line}.{tmp.procname} <- ")
   tmp = tmp.prev

template anyMatchIt*[T](s : seq[T], stmts) : bool =
  var result: bool = false
  for v in s:
    let it {.inject.} = v
    if stmts:
      result = true
      break

  result

template maxByIt*[T](s: seq[T], stmts) : Option[T] =
  var result: Option[T] = none(T)
  var maxF = MinFloatNormal
  for v in s:
    let it {.inject.} = v
    let f = stmts
    if maxF < f.float:
      maxF = f.float
      result = some(v)
  result


template mapIt*[T](s: Option[T], stmts: untyped): untyped =

  if s.isNone:
    var it{.inject.}: T
    none(typeof(stmts))
  else:
    let it {.inject.} = s.get
    let f = stmts
    some(f)

template flatMapIt*[T](s: Option[T], stmts: untyped): untyped =
  if s.isNone:
    var it{.inject.}: T
    none(typeof(stmts.get))
  else:
    let it {.inject.} = s.get
    let f = stmts
    f


iterator upOrDownIter*[T](s : Slice[T]) : T =
  if s.a > s.b:
    var i = s.a
    while i >= s.b:
      yield i
      i.dec
  else:
    var i = s.a
    while i <= s.b:
      yield i
      i.inc

converter axisToInt*(a: Axis): int = a.ord

proc `[]`*[I, T](arr: var array[I,T], a: Axis): var T = arr[a.ord]
proc `[]`*[I, T](arr: array[I,T], a: Axis): T = arr[a.ord]

template `+`*[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))

template `[]`*[T](p: ptr T, off: int) : T =
  (p + off)[]

template `[]=`*[T](p: ptr T, off: int, val : T) =
  (p + off)[] = val