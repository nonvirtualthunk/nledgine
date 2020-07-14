import reflects/reflect_types

type Reduceable*[T] = object
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


proc `increaseMaxBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, T] =
   field.changeMaxBy(delta)

proc `decreaseMaxBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, T] =
   field.changeMaxBy(-delta)

proc `reduceBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, T] =
   field -= delta

proc `recoverBy`*[C, T](field: Field[C, Reduceable[T]], delta: T): FieldModification[C, T] =
   field += delta


proc add*[T](r: var Reduceable[T], v: T) =
   r.reducedBy -= v
proc sub*[T](r: var Reduceable[T], v: T) =
   r.reducedBy += v
