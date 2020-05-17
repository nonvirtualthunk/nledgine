import sequtils
import sugar
import macros
import tables
import typetraits

{.experimental.}

type Entity = int

type 
    DataType[C]=object
        name : string
        index : int

    Field[C, T]=object
        name : string
        setter : (ref C,T) -> void
        getter : (C) -> T

    OperationKind = enum
        okAdd
        okSub
        okAppend

    Operation[T]=ref object of RootObj

    AddOperation[T]=ref object of Operation[T]
        adder : T
    AppendOperation[T, U]=ref object of Operation[T]
        value : U

type
    AbstractDataContainer=ref object of RootObj

    Modification[T]=object
        appliedAt : int
        entity : int
        application : (ref T) -> void
        

    DataContainer[T]=ref object of AbstractDataContainer
        appliedTo : int
        dataStore : Table[int, ref T]
        modifications : seq[Modification[T]]


    World=ref object
        dataContainers : seq[AbstractDataContainer]

proc hash[C](dt : DataType[C]) = 
    name.hash()


# dumpTree:
type
    CharacterInfo=object
        x1:int
        x2:string
        x3:seq[int]
        
        # x1field {.global.}  : Field[A,int] = Field[A,int](name : "x1")

macro defineFields(t: typedesc): untyped =
    result = newStmtList()
    let tname : string = $t
    let tnameIdent = newIdentNode(tname)
    let tDesc = getType(getType(t)[1])
    for field in tDesc[2].children:
        let tfield = field
        let newFieldName = newIdentNode(tname & $field)
        let oldFieldNameStr = newLit($tfield)
        let fieldRef = newDotExpr(t, field)
        let objIdent = newIdentNode("obj")
        let objDotExpr = newDotExpr(objIdent, field)
        let fieldType = getType(tfield)
        let tmp = quote do:
            let `newFieldName` = Field[`tnameIdent`,typeof(`fieldRef`)](name:`oldFieldNameStr`, setter: proc (`objIdent` :ref `tnameIdent`, value: `fieldType`) = 
                (`objDotExpr` = value), getter: proc(`objIdent`:`tnameIdent`) : `fieldType` = 
                `objDotExpr`)
        result.add(tmp)

expandMacros:
    defineFields(CharacterInfo)



var addOp = new(AddOperation[int])
addOp.adder = 3
let tmp : Operation[int] = addOp

var appendOp = new(AppendOperation[seq[int],int])
appendOp.value = 4
let tmp2 : Operation[seq[int]] = appendOp

proc `+`[C,T](field : Field[C,T], delta : T) : Operation[T] =
    var appendOp = new(AddOperation[T])
    appendOp.adder = delta
    appendOp


proc append[C,T,U](field : Field[C,T], value : U) : Operation[T] =
    var appendOp = new(AppendOperation[T,U])
    appendOp.value = 4  
    appendOp

let tmp3 = CharacterInfox3.append(1)

type
    genCharacterInfo=object
        x1:Field[CharacterInfo,int]
        x2:Field[CharacterInfo,string]
        x3:Field[CharacterInfo,seq[int]]
    
let CharacterInfoC = genCharacterInfo(x1 : CharacterInfox1, x2 : CharacterInfox2, x3 : CharacterInfox3)


# dumpTree:
#     let Ax1 = Field[A,typeof(A.x1)](name:"x1", setter: (obj:ref A, value:int) => (obj.x1 = value), getter: (obj:A) => obj.x1)

let CharacterInfoType = DataType[CharacterInfo](name : "CharacterInfo", index : 0)
# let Ax1 = Field[A,typeof(A.x1)](name:"x1", setter: proc (obj:ref A, value:typeof(A.x1)) =
#      (obj.x1 = value), getter: (obj:A) => obj.x1)
# let Ax2 = Field[A,string](name:"x2", setter: (obj:ref A, value:string) => (obj.x2 = value), getter: (obj:A) => obj.x2)

proc printDataType[T](world : World, dt : DataType[T]) = 
    echo "Data type name : " & dt.name

template printData (world : World, t : typed) =
    let dtname {.compileTime.} = $t & "Type"
    world.printDataType(bindSym(dtname))


type
    ModificationBuilder[C]=object
        entity : int
        world : var World
        dataType : DataType[C]

    CharacterInfoModificationBuilder=object
        entity : int
        world : var World
        x1 : Field[CharacterInfo, int]

    CharacterInfoFieldModificationBuilder=object
        entity : int
        world : var World
        field : Field[CharacterInfo, int]


# proc add (builder : CharacterInfoFieldModificationBuilder, d : int) =
#     world.addModification(builder.entity, )

template `[]`(ent : int, t : typed) =
    let dtname {.compileTime.} = $t & "Type"
    ModificationBuilder[t](entity : ent, world : world, dataType : bindSym(dtname))


# targetEntity.modify(CharacterInfo).health + 

var world = World(dataContainers : @[(AbstractDataContainer) new(DataContainer[CharacterInfo])])

# world.printData(CharacterInfo)



proc addModification[T,C](container : var DataContainer[T], entity : int, appliedAt : int, field : Field[T,C], newValue : C) =
    container.modifications.add(Modification[T](entity:entity, application: (obj:ref T) => field.setter(obj, newValue), appliedAt : appliedAt))

proc addModification[C,T](world : var World, dataType : DataType[C], entity : int, appliedAt : int, field : Field[C,T], newValue : T) =
    let dc : DataContainer[C] = (DataContainer[C]) world.dataContainers[dataType.index]
    dc.modifications.add(Modification[C](entity:entity, application: (obj:ref C) => field.setter(obj, newValue), appliedAt : appliedAt))


macro modify(world : var World, expression : untyped) =
    result = newStmtList()
    if expression.kind == nnkInfix:
        let inf = unpackInfix(expression)
        if inf.left.kind == nnkDotExpr:
            let fieldDef = inf.left[1]
            let assignmentDef = inf.right
            if inf.left[0].kind == nnkDotExpr:
                let entityDef = inf.left[0][0]
                let typeDef = inf.left[0][1]
                echo "Parsed: entity(" & entityDef.strVal & ") type(" & typeDef.strVal & ") field(" & fieldDef.strVal & ")"
                let fieldName = newIdentNode(typeDef.strVal & fieldDef.strVal)
                let typeDefIdent = newIdentNode(typeDef.strVal & "Type")
                
                result = quote do:
                    world.addModification(`typeDefIdent`, `entityDef`, 0, `fieldName`, `assignmentDef`)

    # let toplevelkind = newLit(expression.kind)
    # result.add(quote do:
    #     echo `toplevelkind`)
    # for node in expression:
    #     let nodekind = newLit($node.kind)
    #     result.add(quote do:
    #         echo `nodekind`
    #     )

let targetEntity = 3
dumpTree:
    world.modify(targetEntity.CharacterInfo.x1 + 1)

echo "---------------"
expandMacros:
    world.modify(targetEntity.CharacterInfo.x1 + 1)

proc addData[T](container : DataContainer[T], entity : int) =
    container.dataStore[entity] = new(T)

proc addData[T](entity : int, dataType : DataType[T], world : World) =
    let dc : DataContainer[T] = (DataContainer[T]) world.dataContainers[dataType.index]
    addData[T](dc, entity)

proc data[T](container : DataContainer[T], entity : int) : ref T =
    container.dataStore[entity]

proc data[C](world : World, dataType : DataType[C], entity : int) : ref C = 
    let dc : DataContainer[C] = (DataContainer[C]) world.dataContainers[dataType.index]
    data(dc, entity)

template data[T](e : Entity, dt : DataType[T]) : ref T =
    data[T](world, dt, e)

method advance(container : AbstractDataContainer) {.base.} =
    {.warning[LockLevel]:off.}
    discard
    

method advance[T](container : DataContainer[T]) =
    for i in container.appliedTo ..< container.modifications.len:
        let modifier : Modification[T] = container.modifications[i]
        var data = container.dataStore[modifier.entity]
        modifier.application(data)
    container.appliedTo = container.modifications.len - 1

proc advance(world : var World) =
    # let dc : ref DataContainer[C] = (ref DataContainer[C]) world.dataContainers[dataType.index]
    # advance(dc)
    for dc in world.dataContainers:
        advance(dc)


let e : Entity = 1

e.addData(CharacterInfoType, world)
let cid = e.data(CharacterInfoType)

var container = new(DataContainer[CharacterInfo])

container.addData(0)

assert container.data(0).x1 == 0

addModification(container, 0, 1, CharacterInfox1, 12)

assert container.data(0).x1 == 0

advance(container)

assert container.data(0).x1 == 12


let ent = 3
ent.addData(CharacterInfoType, world)

let entA = world.data(CharacterInfoType, ent)

assert entA.x1 == 0

world.addModification(CharacterInfoType, ent, 0, CharacterInfox1, 13)

assert entA.x1 == 0

world.advance()

assert entA.x1 == 13

echo "Assertions passed"
# let chosenField = A.x1field
        


# type
#     A=object
#         x1:int
#         x2:string


# macro auxData(auxType : typed): untyped =
#     let fields = auxType.getType[1].getTypeImpl[2]
#     for i in 0 ..< fields.len:
#         echo "FIELD"
#         echo fields[i]

# auxData(A)

# template defineMeta(a typed)
#     for fieldName, value in a.fieldPairs:
#         echo fieldName # etc

# for fieldName, value in A().fieldPairs:
#     echo fieldName # etc
