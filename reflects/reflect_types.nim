import sugar
import sequtils
import tables
import macros

var dataTypeIndexCounter* {.compileTime.} = 0

macro extractSeqValue*(t : typed) =
    let seqType = getType(t)[1]
    if seqType.len > 1:
        result = seqType[1]
    else:
        result = bindSym("int8")

macro extractTableValue*(t : typed) =
    # echo getTypeInst(t)[1][2].repr
    let tableType = getTypeInst(t)[1]
    if tableType.len > 2:
        result = tableType[2]
    else:
        result = bindSym("int8")

macro extractTableKey*(t : typedesc) =
    let tableType = getTypeInst(t)[1]
    if tableType.len > 1:
        result = tableType[1]
    else:
        result = bindSym("int8")


type 
    DataType*[C]=ref object of RootRef
        name* : string
        index* : int
        fields* : seq[ref AbstractField[C]]

    AbstractField*[C]=ref object of RootRef
        name* : string
        index* : int

    Field*[C, T]=ref object of AbstractField[C]
        setter* : (ref C,T) -> void
        getter* : (C) -> T
        varGetter* : (ref C) -> var T
        dataType* : DataType[C]

    OperationKind* {.pure.} =enum
        Add
        Mul
        Div
        Append
        Remove
        Put

    TaggedOperation*[T] = object
        case kind* : OperationKind
        of OperationKind.Add, OperationKind.Mul, OperationKind.Div: 
            arg* : T
        of OperationKind.Append, OperationKind.Remove: 
            seqArg* : typeof(extractSeqValue(T))
        of OperationKind.Put: 
            newKey : typeof(extractTableKey(T))
            newValue : typeof(extractTableValue(T))

    AbstractModification* =ref object of RootObj

    FieldModification*[C, T]=ref object of AbstractModification
        operation* : TaggedOperation[T]
        field* : Field[C, T]

    InitialAssignmentModification*[C]=ref object of AbstractModification
        value* : C
# let x : typeof(seq[int]) = 9

proc apply*[T](operation : TaggedOperation[T], value : var T) =
    case operation.kind:
    of OperationKind.Add: 
        when compiles(value += operation.arg):
            echo " += reached ", operation.arg
            value += operation.arg
            echo "value is ", value
        else:
            echo "set += operation on type that does not support it", value
    of OperationKind.Mul: 
        when compiles(value *= operation.arg):
            value *= operation.arg
        else:
            echo "set *= operation on type that does not support it", value
    of OperationKind.Div: 
        when compiles(value /= operation.arg):
            value /= operation.arg
        else:
            echo "set /= operation on type that does not support it", value
    of OperationKind.Append: 
        when compiles(value.add(operation.seqArg)):
            value.add(operation.seqArg)
        else:
            echo "set append operation on type that does not support it", value
    of OperationKind.Remove: 
        when compiles(value.filterNot(x => x == operation.seqArg)):
            value.filterNot(x => x == operation.seqArg)
        else:
            echo "set remove operation on type that does not support it", value
    of OperationKind.Put: 
        when compiles(value[operation.newKey] = operation.newValue):
            value[operation.newKey] = operation.newValue
        else:
            echo "set put operation on type that does not support it", value

method apply*[C](modification : AbstractModification, target : ref C) {.base.} =
    echo "hit base implementation of abstract modification"
    {.warning[LockLevel]:off.}
    discard

method apply*[C, T](modification : FieldModification[C,T], target : ref C) {.base.} =
    modification.operation.apply(modification.field.varGetter(target))

method apply*[C](modification : InitialAssignmentModification[C], target : ref C) {.base.} =
    target[] = modification.value


proc `+`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Add, arg: delta), field : field)

proc `+=`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Add, arg: delta), field : field)


proc `-`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Add, arg: -delta), field : field)

proc `-=`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Add, arg: -delta), field : field)

proc `*`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Mul, arg: delta), field : field)

proc `*=`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Mul, arg: delta), field : field)

proc `/`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Div, arg: delta), field : field)

proc `/=`*[C,T](field : Field[C,T], delta : T) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Div, arg: delta), field : field)

proc append*[C,T, U](field : Field[C,T], delta : U) : FieldModification[C,T] =
    FieldModification[C,T](operation : TaggedOperation[T](kind : OperationKind.Append, seqArg: delta), field : field)