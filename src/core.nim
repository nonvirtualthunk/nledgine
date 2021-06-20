import reflects/reflect_types
import noto

type
  Reduceable*[T] = object
    max: T
    reducedBy: T
  

proc reduceable*[T](v: T): Reduceable[T] =
  Reduceable[T](max: v)

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
