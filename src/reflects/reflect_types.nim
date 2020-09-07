import sugar
import sequtils
import tables
import macros
import noto
import strutils

var dataTypeIndexCounter* {.compileTime.} = 0
var displayDataTypeIndexCounter* {.compileTime.} = 0

type ReflectInitializers* = seq[proc() {.gcsafe.}]
var reflectInitializers*: ReflectInitializers

macro extractSeqValue*[T](t: typedesc[T]) =
   result = quote do:
      int8
   if t.getTypeInst.len > 1:
      let seqType = t.getTypeInst[1]
      if seqType.len > 1:
         result = seqType[1]


macro extractTableValue*(t: typed) =
   # echo getTypeInst(t)[1][2].repr
   let tableType = getTypeInst(t)[1]
   if tableType.len > 2:
      result = tableType[2]
   else:
      result = bindSym("int8")

macro extractTableKey*(t: typedesc) =
   let tableType = getTypeInst(t)[1]
   if tableType.len > 1:
      result = tableType[1]
   else:
      result = bindSym("int8")

proc anyExample*[T](t: typedesc[T]): auto =
   var tmp: T
   tmp[0]

type
   # TODO: This doesn't actually need to be ref object of RootRef
   DataType*[C] = ref object of RootRef
      typeName*: string
      index*: int
      fields*: seq[ref AbstractField[C]]

   AbstractField*[C] = ref object of RootRef
      name*: string
      index*: int

   Field*[C, T] = ref object of AbstractField[C]
      setter*: (var C, T) -> void
      getter*: (C) -> T
      varGetter*: (var C) -> var T
      dataType*: DataType[C]

   OperationKind* {.pure.} = enum
      Add
      Mul
      Div
      Append
      Incl
      Remove
      # Put
      Set
      ChangeMaximum

   # SeqHolder*[Z] = object
   #    when compiles(anyExample(Z)):
   #       arg*: typeof(anyExample(Z))
   #    else:
   #       arg*: int8

   TaggedOperation*[T] = object
      case kind*: OperationKind
      of OperationKind.Add, OperationKind.Mul, OperationKind.Div, OperationKind.ChangeMaximum, OperationKind.Set:
         arg*: T
      of OperationKind.Append, OperationKind.Remove, OperationKind.Incl:
         seqArg*: T

   AbstractModification* = ref object of RootObj


   FieldModification*[C, T] = ref object of AbstractModification
      operation*: TaggedOperation[T]
      field*: Field[C, T]

   TableFieldModification*[C, K, V] = ref object of AbstractModification
      field*: Field[C, Table[K, V]]
      key*: K
      operation*: TaggedOperation[V]

   TableFieldTableModification*[C, K1, K2, V] = ref object of AbstractModification
      field*: Field[C, Table[K1, Table[K2, V]]]
      keyA*: K1
      keyB*: K2
      operation*: TaggedOperation[V]

   NestedFieldModification*[C, T, U] = ref object of AbstractModification
      field*: Field[C, T]
      nestedField*: Field[T, U]
      operation*: TaggedOperation[U]

   NestedTableFieldModification*[C, T, K, V] = ref object of AbstractModification
      field*: Field[C, T]
      tableModification*: TableFieldModification[T, K, V]


   InitialAssignmentModification*[C] = ref object of AbstractModification
      value*: C
# let x : typeof(seq[int]) = 9

type
   DataTypeCallbackable* = concept d
      d.callback(DataType)


proc removeFrom[T](v: var seq[T], o: seq[T]) =
   var i = 0
   while i < v.len:
      if o.contains(v[i]):
         v.delete(i, i)
      else:
         i.inc

proc apply*[T](operation: TaggedOperation[T], value: var T) =
   case operation.kind:
   of OperationKind.Add:
      when compiles(value += operation.arg):
         value += operation.arg
      else:
         writeStackTrace()
         warn &"+= operation on type that does not support it {value}, {$T}, {operation.arg}"
   of OperationKind.Set:
      # "when compiles" gives an invalid result here, indicating that it cannot compile though that is not true
      # when compiles(value = operation.arg):
      value = operation.arg
      # else:
      #     warn "set = operation on type that does not support it `", value, " = ", operation.arg, "`, `", T, "`"
   of OperationKind.Mul:
      when compiles(value *= operation.arg):
         value *= operation.arg
      else:
         warn &"*= operation on type that does not support it {$T}, {value}"
   of OperationKind.Div:
      when compiles(value /= operation.arg):
         value /= operation.arg
      else:
         warn &"/= operation on type that does not support it {$T}, {value}"
   of OperationKind.Append:
      when compiles(value.add(operation.seqArg)):
         value.add(operation.seqArg)
      else:
         warn &"append operation on type that does not support it {$T}, {value}"
   of OperationKind.Incl:
      when compiles(value.incl(operation.seqArg)):
         value.incl(operation.seqArg)
      else:
         warn &"append operation on type that does not support it {$T}, {value}"
   of OperationKind.Remove:
      when compiles(value.removeFrom(operation.seqArg)):
         # value = value.filterNot(x => x == operation.seqArg.contains(x))
         value.removeFrom(operation.seqArg)
      else:
         warn &"remove operation on type that does not support it {$T}, {value}"
   # of OperationKind.Put:
   #    when compiles(value[operation.newKey] = operation.newValue):
   #       value[operation.newKey] = operation.newValue
   #    else:
   #       warn &"put operation on type that does not support it {value}"
   of OperationKind.ChangeMaximum:
      when compiles(value.changeMaxBy(operation.arg)):
         value.changeMaxBy(operation.arg)
      else:
         warn &"changeMaximum operation on type that does not support it {value}"

method apply*[C](modification: AbstractModification, target: ref C) {.base.} =
   echo "hit base implementation of abstract modification"
   {.warning[LockLevel]: off.}
   discard

method apply*[C, T](modification: FieldModification[C, T], target: ref C) {.base.} =
   # Note: known bug with distinct types and generic methods causes them to misbehave in some circumstances
   modification.operation.apply(modification.field.varGetter(target[]))

method apply*[C, T, U](modification: NestedFieldModification[C, T, U], target: ref C) {.base.} =
   modification.operation.apply(modification.nestedField.varGetter(modification.field.varGetter(target[])))

method apply*[C, K, V](modification: TableFieldModification[C, K, V], target: ref C) {.base.} =
   modification.operation.apply(modification.field.varGetter(target[]).mgetOrPut(modification.key, default(V)))

method apply*[C, K1, K2, V](modification: TableFieldTableModification[C, K1, K2, V], target: ref C) {.base.} =
   modification.operation.apply(modification.field.varGetter(target[]).mgetOrPut(modification.keyA, default(Table[K2, V])).mgetOrPut(modification.keyB, default(V)))

method apply*[C, T, K, V](modification: NestedTableFieldModification[C, T, K, V], target: ref C) {.base.} =
   modification.tableModification.applyVar(modification.field.varGetter(target[]))

method apply*[C](modification: InitialAssignmentModification[C], target: ref C) {.base.} =
   target[] = modification.value


method applyVar*[C](modification: AbstractModification, target: var C) {.base.} =
   echo "hit base implementation of abstract modification"
   {.warning[LockLevel]: off.}
   discard

method applyVar*[C, T](modification: FieldModification[C, T], target: var C) {.base.} =
   modification.operation.apply(modification.field.varGetter(target))

method applyVar*[C, T, U](modification: NestedFieldModification[C, T, U], target: var C) {.base.} =
   modification.operation.apply(modification.nestedField.varGetter(modification.field.varGetter(target)))

method applyVar*[C, K, V](modification: TableFieldModification[C, K, V], target: var C) {.base.} =
   modification.operation.apply(modification.field.varGetter(target).mgetOrPut(modification.key, default(V)))

method applyVar*[C, K1, K2, V](modification: TableFieldTableModification[C, K1, K2, V], target: var C) {.base.} =
   modification.operation.apply(modification.field.varGetter(target).mgetOrPut(modification.keyA, default(Table[K2, V])).mgetOrPut(modification.keyB, default(V)))

method applyVar*[C, T, K, V](modification: NestedTableFieldModification[C, T, K, V], target: var C) {.base.} =
   modification.tableModification.applyVar(modification.field.varGetter(target))

method applyVar*[C](modification: InitialAssignmentModification[C], target: var C) {.base.} =
   target = modification.value


proc nestedTableFieldModification*[C, T, K, V](field: Field[C, T], tableField: Field[T, Table[K, V]], key: K, operation: TaggedOperation[V]): NestedTableFieldModification[C, T, K, V] =
   NestedTableFieldModification[C, T, K, V](field: field, tableModification: TableFieldModification[T, K, V](key: key, operation: operation, field: tableField))

proc nestedModification*[C, T, K, V](field: Field[C, T], nested: TableFieldModification[T, K, V]): NestedTableFieldModification[C, T, K, V] =
   NestedTableFieldModification[C, T, K, V](field: field, tableModification: nested)

proc `:=`*[C, T](field: Field[C, T], value: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Set, arg: value), field: field)

proc setTo*[C, T](field: Field[C, T], value: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Set, arg: value), field: field)

proc `+`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Add, arg: delta), field: field)

proc `+=`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   result = FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Add, arg: delta), field: field)

proc `changeMaxBy`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.ChangeMaximum, arg: delta), field: field)

proc `-`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Add, arg: -delta), field: field)

proc `-=`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Add, arg: -delta), field: field)

proc `*`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Mul, arg: delta), field: field)

proc `*=`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Mul, arg: delta), field: field)

proc `/`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Div, arg: delta), field: field)

proc `/=`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Div, arg: delta), field: field)

proc append*[C, T, U](field: Field[C, T], delta: U): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Append, seqArg: @[delta]), field: field)

proc incl*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Incl, seqArg: delta), field: field)

proc remove*[C, T, U](field: Field[C, T], delta: U): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Remove, seqArg: @[delta]), field: field)

proc `[]=`*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): TableFieldModification[C, K, V] =
   TableFieldModification[C, K, V](key: k, operation: TaggedOperation[V](kind: OperationKind.Set, arg: v), field: field)

proc `put`*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): TableFieldModification[C, K, V] =
   TableFieldModification[C, K, V](key: k, operation: TaggedOperation[V](kind: OperationKind.Set, arg: v), field: field)

proc `put`*[C, K1, K2, V](field: Field[C, Table[K1, Table[K2, V]]], ka: K1, kb: K2, v: V): TableFieldTableModification[C, K1, K2, V] =
   TableFieldTableModification[C, K1, K2, V](keyA: ka, keyB: kb, operation: TaggedOperation[V](kind: OperationKind.Set, arg: v), field: field)

proc `addToKey`*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): TableFieldModification[C, K, V] =
   TableFieldModification[C, K, V](key: k, operation: TaggedOperation[V](kind: OperationKind.Add, arg: v), field: field)

proc `addToKey`*[C, K1, K2, V](field: Field[C, Table[K1, Table[K2, V]]], ka: K1, kb: K2, v: V): TableFieldTableModification[C, K1, K2, V] =
   TableFieldTableModification[C, K1, K2, V](keyA: ka, keyB: kb, operation: TaggedOperation[V](kind: OperationKind.Add, arg: v), field: field)

proc appendToKey*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): TableFieldModification[C, K, V] =
   TableFieldModification[C, K, V](key: k, operation: TaggedOperation[V](kind: OperationKind.Append, seqArg: v), field: field)

proc removeFromKey*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): TableFieldModification[C, K, V] =
   TableFieldModification[C, K, V](key: k, operation: TaggedOperation[V](kind: OperationKind.Remove, seqArg: v), field: field)


proc appendOperation*[T, U](delta: U, t: typedesc[T]): TaggedOperation[T] =
   TaggedOperation[T](kind: OperationKind.Append, seqArg: @[delta])

proc removeOperation*[T, U](delta: U, t: typedesc[T]): TaggedOperation[T] =
   TaggedOperation[T](kind: OperationKind.Remove, seqArg: @[delta])

macro class*(t: typedesc): untyped =
   result = newIdentNode($t & "Type")
