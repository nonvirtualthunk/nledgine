import sequtils
import sugar
import macros
import tables
import typetraits
import options
import reflects/reflect_types

{.experimental.}

type Entity* = int  
type GameEventClock* = int

type
    AbstractDataContainer=ref object of RootObj

    EntityModification=object
        modification : AbstractModification
        modificationTime : GameEventClock
        entity : Entity
        

    ModificationContainer=object
        modifications : seq[EntityModification]

    DataContainer[T]=ref object of AbstractDataContainer
        lastAppliedIndex : int
        dataStore : Table[Entity, ref T]

    WorldView* = ref object
        baseView : Option[WorldView]
        dataContainers : seq[AbstractDataContainer]
        currentTime* : GameEventClock

    World* = ref object
        view* : WorldView
        modificationContainers : seq[ModificationContainer]
        currentTime* : GameEventClock

converter toView*(world : World) : WorldView = world.view

var worldCallsForAllTypes* : seq[proc(world: var World)] = @[]

proc createWorld*() : World = 
    var ret = new World
    ret.view = new WorldView
    ret.view.dataContainers = newSeq[AbstractDataContainer]()
    
    ret.modificationContainers = newSeq[ModificationContainer]()
    for setup in worldCallsForAllTypes:
        setup(ret)
    return ret


proc setUpType*[C](world : var World, dataType : DataType[C]) =
    if world.view.dataContainers.len <= dataType.index:
        world.view.dataContainers.setLen(dataType.index + 1)
    world.view.dataContainers[dataType.index] = DataContainer[C](dataStore : Table[Entity, ref C]())

    if world.modificationContainers.len <= dataType.index:
        world.modificationContainers.setLen(dataType.index + 1)
    world.modificationContainers[dataType.index] = ModificationContainer(modifications : @[])

method advance(container : AbstractDataContainer, targetTime : GameEventClock) {.base.} =
    {.warning[LockLevel]:off.}
    discard
    

method advance[T](container : DataContainer[T], modContainer : ModificationContainer, targetTime : GameEventClock) {.base.} =
    for i in container.lastAppliedIndex ..< modContainer.modifications.len:
        let modifier : EntityModification = modContainer.modifications[i]
        if modifier.modificationTime > targetTime:
            break
        var data = container.dataStore[modifier.entity]
        modifier.modification.apply(data)
        container.lastAppliedIndex = i

proc advance(world : var World, targetTime : GameEventClock) =
    for dc in world.view.dataContainers:
        advance(dc, targetTime)


proc attachData*[C] (world : var World, entity : Entity, dataType : DataType[C], dataValue : C) =
    let entityMod = EntityModification(entity : entity, modificationTime : world.currentTime, modification : InitialAssignmentModification[C](value : dataValue))
    world.addModification(dataType, entityMod)

proc modify*[C,T] (world : var World, entity : Entity, modification : FieldModification[C,T]) =
    world.addModification(modification.field.dataType, EntityModification(entity : entity, modificationTime : world.currentTime, modification : modification))


proc addModification*[C] (world : var World, dataType : DataType[C], modification : EntityModification) =
    let entity = modification.entity
    var mc = world.modificationContainers[dataType.index]

    var dc = (DataContainer[C]) world.view.dataContainers[dataType.index]
    var existingRef = dc.dataStore.getOrDefault(entity)
    if existingRef == nil:
        existingRef = new C
        dc.dataStore[entity] = existingRef
    modification.modification.apply(existingRef)

    mc.modifications.add(modification)


proc data*[C] (view : WorldView, entity : Entity, dataType : DataType[C]) : ref C =
    var dc = (DataContainer[C]) view.dataContainers[dataType.index]
    return dc.dataStore[entity]

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
