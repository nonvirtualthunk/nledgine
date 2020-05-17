import sequtils
import sugar
import macros
import tables
import typetraits
import options
import reflects/reflect_types
import hashes

{.experimental.}

type Entity* = distinct int  
type GameEventClock* = distinct int
type WorldModifierClock* = distinct int

type
    AbstractDataContainer=ref object of RootObj

    EntityModification=object
        modification : AbstractModification
        entity : Entity
        dataTypeIndex : int

    ModificationContainer=object
        modifications : seq[EntityModification]
        modificationClock : WorldModifierClock

    DataContainer[T]=ref object of AbstractDataContainer
        lastAppliedIndex : int
        dataStore : Table[Entity, ref T]
        defaultValue : ref T

    WorldView* = ref object
        entities* : seq[Entity]
        baseView : Option[WorldView]
        dataContainers : seq[AbstractDataContainer]
        currentTime* : GameEventClock
        lastAppliedIndex : WorldModifierClock

    World* = ref object
        view* : WorldView
        modificationContainer : ModificationContainer
        currentTime* : GameEventClock
        entityCounter : int

converter toView*(world : World) : WorldView = world.view

var worldCallsForAllTypes* : seq[proc(world: var World)] = @[]

proc hash*(e : Entity) : int =
    return e.int.hash
proc `==`*(a : Entity, b : Entity) : bool {.borrow.}
proc `+`*(a : WorldModifierClock, b : int) : WorldModifierClock = return (a.int + b).WorldModifierClock
proc `-`*(a : WorldModifierClock, b : int) : WorldModifierClock = return (a.int - b).WorldModifierClock

proc createWorld*() : World = 
    var ret = new World
    ret.view = new WorldView
    ret.view.entities = @[]
    ret.view.dataContainers = newSeq[AbstractDataContainer]()
    ret.view.lastAppliedIndex = (-1).WorldModifierClock
    
    ret.modificationContainer = ModificationContainer(modifications : @[])

    for setup in worldCallsForAllTypes:
        setup(ret)
    return ret


proc createEntity*(world : var World) : Entity =
    result = world.entityCounter.Entity
    world.entityCounter.inc
    world.view.entities.add(result)
    
    world.modificationContainer.modifications.add(EntityModification(entity : result, dataTypeIndex : -1))
    world.modificationContainer.modificationClock = world.modificationContainer.modificationClock + 1

proc setUpType*[C](world : var World, dataType : DataType[C]) =
    if world.view.dataContainers.len <= dataType.index:
        world.view.dataContainers.setLen(dataType.index + 1)
    world.view.dataContainers[dataType.index] = DataContainer[C](dataStore : Table[Entity, ref C](), defaultValue : new C)

method applyModification(container : AbstractDataContainer, entMod : EntityModification) {.base.} =
    {.warning[LockLevel]:off.}
    discard
    

method applyModification[T](container : DataContainer[T], entMod : EntityModification) {.base.} =
    var data = container.dataStore.getOrDefault(entMod.entity, nil)
    if data == nil:
        data = new T
        container.dataStore[entMod.entity] = data
    entMod.modification.apply(data)
    # for i in container.lastAppliedIndex ..< modContainer.modifications.len:
    #     let modifier : EntityModification = modContainer.modifications[i]
    #     if modifier.modificationTime > targetTime:
    #         break
    #     var data = container.dataStore[modifier.entity]
    #     modifier.modification.apply(data)
    #     container.lastAppliedIndex = i


proc createView*(world : World) : WorldView =
    deepCopy(world.view)

proc advance*(view : var WorldView, world : World, targetTime : WorldModifierClock) =
    for i in view.lastAppliedIndex.int+1 .. min(world.modificationContainer.modificationClock.int-1, targetTime.int):
        let modifier : EntityModification = world.modificationContainer.modifications[i]
        if modifier.dataTypeIndex == -1:
            view.entities.add(modifier.entity)
        else:
            view.dataContainers[modifier.dataTypeIndex].applyModification(modifier)
        view.lastAppliedIndex = WorldModifierClock(i)



# proc attachData*[C] (world : var World, entity : Entity, dataType : DataType[C]) =
#     attachData(world, entity, dataType, C())

proc attachData*[C] (world : var World, entity : Entity, dataType : DataType[C], dataValue : C = C()) =
    let entityMod = EntityModification(entity : entity, dataTypeIndex : dataType.index, modification : InitialAssignmentModification[C](value : dataValue))
    world.addModification(dataType, entityMod)

proc modify*[C,T] (world : var World, entity : Entity, modification : FieldModification[C,T]) =
    world.addModification(modification.field.dataType, EntityModification(entity : entity, dataTypeIndex : modification.field.dataType.index, modification : modification))


proc addModification*[C] (world : var World, dataType : DataType[C], modification : EntityModification) =
    let entity = modification.entity

    var dc = (DataContainer[C]) world.view.dataContainers[dataType.index]
    var existingRef = dc.dataStore.getOrDefault(entity)
    if existingRef == nil:
        existingRef = new C
        dc.dataStore[entity] = existingRef
    modification.modification.apply(existingRef)
    world.modificationContainer.modifications.add(modification)
    world.modificationContainer.modificationClock = world.modificationContainer.modificationClock + 1
    world.view.lastAppliedIndex = world.view.lastAppliedIndex + 1


proc data*[C] (view : WorldView, entity : Entity, dataType : DataType[C]) : ref C =
    var dc = (DataContainer[C]) view.dataContainers[dataType.index]
    result = dc.dataStore.getOrDefault(entity, nil)
    if result == nil:
        echo "Warning: read data[", C, "] for entity ", entity.int, " that did not have access to data of that type"
        result = dc.defaultValue

proc hasData*[C] (view : WorldView, entity : Entity, dataType : DataType[C]) : bool =
    var dc = (DataContainer[C]) view.dataContainers[dataType.index]
    result = dc.dataStore.hasKey(entity)

macro modify*(world : var World, expression : untyped) =
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
                let fieldName = newDotExpr(newIdentNode(typeDef.strVal & "Type"),newIdentNode(fieldDef.strVal))
                let typeDefIdent = newIdentNode(typeDef.strVal & "Type")
                
                result = quote do:
                    world.modify(`entityDef`, `fieldName`, `assignmentDef`)


macro data*(entity : Entity, view : WorldView, t : typedesc) : untyped =
    let dataTypeIdent = newIdentNode($t & "Type")
    return quote do:
        `view`.data(`entity`, `dataTypeIdent`)

macro hasData*(entity : Entity, view : WorldView, t : typedesc) : untyped =
    let dataTypeIdent = newIdentNode($t & "Type")
    return quote do:
        `view`.hasData(`entity`, `dataTypeIdent`)

macro `[]`*(entity : Entity, t : typedesc) : untyped =
    let dataTypeIdent = newIdentNode($t & "Type")
    result = quote do:
        when compiles(view.data(`entity`, `dataTypeIdent`)):
            view.data(`entity`, `dataTypeIdent`)
        else:
            world.data(`entity`, `dataTypeIdent`)

macro data*(entity : Entity, t : typedesc) : untyped =
    let dataTypeIdent = newIdentNode($t & "Type")
    result = quote do:
        when compiles(view.data(`entity`, `dataTypeIdent`)):
            view.data(`entity`, `dataTypeIdent`)
        else:
            world.data(`entity`, `dataTypeIdent`)

macro attachData*(entity : Entity, t : typed) : untyped =
    let dataTypeIdent = newIdentNode(t[0].strVal & "Type")
    result = quote do:
        world.attachData(`entity`, `dataTypeIdent`, `t`)

macro hasData*(entity : Entity, t : typedesc) : untyped =
    let dataTypeIdent = newIdentNode($t & "Type")
    result = quote do:
        when compiles(view.hasData(`entity`, `dataTypeIdent`)):
            view.data(`entity`, `dataTypeIdent`)
        else:
            world.hasData(`entity`, `dataTypeIdent`)

# template modify*[C,T](entity : Entity, t : FieldModification[C,T]) =
#     world.modify(entity, t)

proc appendToEarliestIdent(n : NimNode, append : string) : bool =
    if n.kind == nnkIdent:
        return true
    else:
        for i in 0 ..< n.len:
            if appendToEarliestIdent(n[i], append):
                if n.kind == nnkDotExpr:
                    n[i] = newIdentNode(n[i].strVal & append)
                    return true
        return false

macro modify*(entity : Entity, expression : untyped) : untyped =
    var argument = expression.copy
    discard appendToEarliestIdent(argument, "Type")
    result = quote do:
        world.modify(`entity`, `argument`)
