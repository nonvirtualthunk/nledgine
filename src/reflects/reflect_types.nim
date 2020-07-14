import sugar
import sequtils
import tables
import macros
import noto

var dataTypeIndexCounter* {.compileTime.} = 0

type ReflectInitializers* = seq[proc() {.gcsafe.}]
var reflectInitializers*: ReflectInitializers

macro extractSeqValue*[T](t: typedesc[T]) =
   let seqType = t[1]
   if seqType.len > 1:
      result = seqType[1]
   else:
      result = bindSym("int8")

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
      setter*: (ref C, T) -> void
      getter*: (C) -> T
      varGetter*: (ref C) -> var T
      dataType*: DataType[C]

   OperationKind* {.pure.} = enum
      Add
      Mul
      Div
      Append
      Remove
      Put
      Set
      ChangeMaximum

   TaggedOperation*[T] = object
      case kind*: OperationKind
      of OperationKind.Add, OperationKind.Mul, OperationKind.Div, OperationKind.ChangeMaximum, OperationKind.Set:
         arg*: T
      of OperationKind.Append, OperationKind.Remove:
         discard
         # seqArg* : extractSeqValue(T)
      of OperationKind.Put:
         discard
         # newKey* : typeof(extractTableKey(T))
         # newValue* : typeof(extractTableValue(T))

   AbstractModification* = ref object of RootObj

   FieldModification*[C, T] = ref object of AbstractModification
      operation*: TaggedOperation[T]
      field*: Field[C, T]

   TableFieldModification*[C, K, V] = ref object of AbstractModification
      field*: Field[C, Table[K, V]]
      key*: K
      operation: TaggedOperation[V]

   InitialAssignmentModification*[C] = ref object of AbstractModification
      value*: C
# let x : typeof(seq[int]) = 9

type
   DataTypeCallbackable* = concept d
      d.callback(DataType)

proc apply*[T](operation: TaggedOperation[T], value: var T) =
   case operation.kind:
   of OperationKind.Add:
      when compiles(value += operation.arg):
         value += operation.arg
      else:
         warn &"+= operation on type that does not support it {value}"
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
         warn &"*= operation on type that does not support it {value}"
   of OperationKind.Div:
      when compiles(value /= operation.arg):
         value /= operation.arg
      else:
         warn &"/= operation on type that does not support it {value}"
   of OperationKind.Append:
      when compiles(value.add(operation.seqArg)):
         value.add(operation.seqArg)
      else:
         warn &"append operation on type that does not support it {value}"
   of OperationKind.Remove:
      when compiles(value.filterNot(x => x == operation.seqArg)):
         value.filterNot(x => x == operation.seqArg)
      else:
         warn &"remove operation on type that does not support it {value}"
   of OperationKind.Put:
      when compiles(value[operation.newKey] = operation.newValue):
         value[operation.newKey] = operation.newValue
      else:
         warn &"put operation on type that does not support it {value}"
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
   modification.operation.apply(modification.field.varGetter(target))

method apply*[C, K, V](modification: TableFieldModification[C, K, V], target: ref C) {.base.} =
   modification.operation.apply(modification.field.varGetter(target).mgetOrPut(modification.key, default(V)))

method apply*[C](modification: InitialAssignmentModification[C], target: ref C) {.base.} =
   target[] = modification.value


proc `:=`*[C, T](field: Field[C, T], value: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Set, arg: value), field: field)

proc setTo*[C, T](field: Field[C, T], value: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Set, arg: value), field: field)

proc `+`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Add, arg: delta), field: field)

proc `+=`*[C, T](field: Field[C, T], delta: T): FieldModification[C, T] =
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Add, arg: delta), field: field)

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
   FieldModification[C, T](operation: TaggedOperation[T](kind: OperationKind.Append, seqArg: delta), field: field)

proc `[]=`*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): FieldModification[C, Table[K, V]] =
   FieldModification[C, Table[K, V]](operation: TaggedOperation[Table[K, V]](kind: OperationKind.Put, newKey: k, newValue: v), field: field)

proc `put`*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): TableFieldModification[C, K, V] =
   TableFieldModification[C, K, V](key: k, operation: TaggedOperation[V](kind: OperationKind.Set, arg: v), field: field)

proc `addToKey`*[C, K, V](field: Field[C, Table[K, V]], k: K, v: V): TableFieldModification[C, K, V] =
   TableFieldModification[C, K, V](key: k, operation: TaggedOperation[V](kind: OperationKind.Add, arg: v), field: field)


macro class*(t: typedesc): untyped =
   result = newIdentNode($t & "Type")
