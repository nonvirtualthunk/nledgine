import reflects/reflect_types
import noto
import options

type
  Reduceable*[T] = object
    max: T
    reducedBy: T

  TickTock*[T] = ref object
    prev*: ref T
    next*: ref T

  IntRange* = object
    min*: Option[int]
    max*: Option[int] #inclusive

  ClosedIntRange* = object
    min*: int
    max*: int


proc contains*(r: IntRange, i: int) : bool = r.min.get(i) <= i and r.max.get(i) >= i
proc contains*(r: ClosedIntRange, i: int) : bool = r.min <= i and r.max >= i
converter fromHSLice*(h: Slice[int]): ClosedIntRange =
  ClosedIntRange(min: h.a, max: h.b)

proc closedRange*(min: int, max: int): ClosedIntRange = ClosedIntRange(min: min, max: max)
proc openTopRange*(min: int): IntRange = IntRange(min: some(min), max: none(int))
proc openBottomRange*(max: int): IntRange = IntRange(min: none(int), max: some(max))

converter fromClosedRange*(r: ClosedIntRange): IntRange =
  IntRange(min: some(r.min), max: some(r.max))

proc width*(r: ClosedIntRange): int = r.max - r.min + 1

iterator items*(r: ClosedIntRange): int =
  for i in r.min .. r.max:
    yield i

proc tickTock*[T]() : TickTock[T] =
  TickTock[T](
    prev: new T,
    next: new T
  )

proc swap*[T](t: TickTock[T]) =
  let tmp = t.prev
  t.prev = t.next
  t.next = tmp

  

proc reduceable*[T](v: T): Reduceable[T] =
  Reduceable[T](max: max(v,0.T))

proc reduceBy*[T](r: var Reduceable[T], delta: T) =
  r.reducedBy += delta
  if r.reducedBy > r.max:
    r.reducedBy = r.max

proc recoverBy*[T](r: var Reduceable[T], delta: T) =
  r.reducedBy -= delta
  if r.reducedBy < 0:
    r.reducedBy = 0

proc changeMaxBy*[T](r: var Reduceable[T], v: T) =
  r.max += v

proc currentValue*[T](r: Reduceable[T]): T = r.max - r.reducedBy
proc maxValue*[T](r: Reduceable[T]): T = r.max
proc currentlyReducedBy*[T](r: Reduceable[T]): T = r.reducedBy


proc `increaseMaxBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, T] =
  field.changeMaxBy(delta)

proc `decreaseMaxBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, T] =
  field.changeMaxBy(-delta)

proc `reduceBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, Reduceable[T]] =
  field += Reduceable[T](max: 0, reducedBy: -delta)

proc `recoverBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, Reduceable[T]] =
  field += Reduceable[T](max: 0, reducedBy: delta)

# this is somewhat of a hack
proc `+=`*[T](a: var Reduceable[T], b: Reduceable[T]) =
  if b.max != 0:
    warn &"+= with redueceables was never intended to change the max"
  if b.reducedBy > 0:
    a.recoverBy(b.reducedBy)
  else:
    a.reduceBy(-b.reducedBy)

proc add*[T](r: var Reduceable[T], v: T) =
  r.reducedBy -= v
proc sub*[T](r: var Reduceable[T], v: T) =
  r.reducedBy += v
