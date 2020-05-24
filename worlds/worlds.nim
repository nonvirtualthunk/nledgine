import sequtils
import sugar
import macros
import tables
import typetraits
import options
import ../reflects/reflect_types
import hashes
import ../engines/event_types

{.experimental.}

type Entity* = distinct int  
type WorldEventClock* = distinct int
type WorldModifierClock* = distinct int

let WorldEntity = 0.Entity

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
        lastAppliedEvent : WorldEventClock
        lastAppliedIndex : WorldModifierClock
        events* : seq[Event]

    World* = ref object
        view* : WorldView
        modificationContainer : ModificationContainer
        currentTime* : WorldEventClock
        entityCounter : int
        eventModificationTimes : seq[WorldModifierClock]  # the "current modifier time" when the event was created, all modifications < that time are included

    DisplayWorld* = ref object
        entities : seq[Entity]
        dataContainers : seq[AbstractDataContainer]
        events* : EventBuffer
        entityCounter : int
        eventClock : WorldEventClock



converter toView*(world : World) : WorldView = world.view

var worldCallsForAllTypes* : seq[proc(world: World)] = @[]
var displayWorldCallsForAllTypes* : seq[proc(world: DisplayWorld)] = @[]

proc hash*(e : Entity) : int =
    return e.int.hash
proc `==`*(a : Entity, b : Entity) : bool {.borrow.}
proc `+`*(a : WorldModifierClock, b : int) : WorldModifierClock = return (a.int + b).WorldModifierClock
proc `-`*(a : WorldModifierClock, b : int) : WorldModifierClock = return (a.int - b).WorldModifierClock

proc `$`*(e : Entity) : string =
    return $e.int

proc currentTime*(view : WorldView) : WorldEventClock =
    (view.lastAppliedEvent.int+1).WorldEventClock

proc addModification*(world : World, modification : EntityModification)

proc createEntity*(world : World) : Entity =
    result = world.entityCounter.Entity
    world.entityCounter.inc
    
    addModification(world, EntityModification(entity : result, dataTypeIndex : -1))

proc createEntity*(world : DisplayWorld) : Entity =
    result = world.entityCounter.Entity
    world.entities.add(result)
    world.entityCounter.inc

proc createWorld*() : World = 
    var ret = new World
    ret.view = new WorldView
    ret.view.entities = @[]
    ret.view.dataContainers = newSeq[AbstractDataContainer]()
    ret.view.lastAppliedIndex = (-1).WorldModifierClock
    ret.view.lastAppliedEvent = (-1).WorldEventClock
    ret.view.events = @[]
    
    ret.modificationContainer = ModificationContainer(modifications : @[])

    for setup in worldCallsForAllTypes:
        setup(ret)

    # create world entity, 0
    discard ret.createEntity()

    return ret

proc createDisplayWorld*() : DisplayWorld = 
    var ret = new DisplayWorld
    ret.dataContainers = newSeq[AbstractDataContainer]()
    ret.events = createEventBuffer()

    for setup in displayWorldCallsForAllTypes:
        setup(ret)

    # create world entity, 0
    discard ret.createEntity()

    return ret

proc addEventToView(view : WorldView, evt : Event, eventTime : WorldEventClock) =
    view.events.add(evt)
    view.lastAppliedEvent = eventTime

proc addEvent*(world : World, evt : Event) : WorldEventClock {.discardable.} =
    result = world.currentTime
    world.eventModificationTimes.add(world.modificationContainer.modificationClock)
    addEventToView(world.view, evt, world.currentTime)
    world.currentTime.inc

proc addEvent*(world : DisplayWorld, evt : Event) : WorldEventClock {.discardable.} =
    result = world.eventClock
    world.events.addEvent(evt)
    world.eventClock.inc

proc setUpType*[C](world : World, dataType : DataType[C]) =
    if world.view.dataContainers.len <= dataType.index:
        world.view.dataContainers.setLen(dataType.index + 1)
    world.view.dataContainers[dataType.index] = DataContainer[C](dataStore : Table[Entity, ref C](), defaultValue : new C)

proc setUpType*[C](world : DisplayWorld, dataType : DataType[C]) =
    if world.dataContainers.len <= dataType.index:
        world.dataContainers.setLen(dataType.index + 1)
    world.dataContainers[dataType.index] = DataContainer[C](dataStore : Table[Entity, ref C](), defaultValue : new C)

method applyModification(container : AbstractDataContainer, entMod : EntityModification) {.base.} =
    {.warning[LockLevel]:off.}
    discard
    

method applyModification[T](container : DataContainer[T], entMod : EntityModification) {.base.} =
    var data = container.dataStore.getOrDefault(entMod.entity, nil)
    # todo: warn when we have no existing data and the modification is not an initial setting mod
    if data == nil:
        data = new T
        container.dataStore[entMod.entity] = data
    entMod.modification.apply(data)

proc createView*(world : World) : WorldView =
    deepCopy(world.view)

proc applyModificationToView(view : WorldView, modifier : EntityModification, modifierClock : WorldModifierClock) =
    if modifier.dataTypeIndex == -1:
        view.entities.add(modifier.entity)
    else:
        view.dataContainers[modifier.dataTypeIndex].applyModification(modifier)
    view.lastAppliedIndex = modifierClock


proc advance*(view : WorldView, world : World, targetCurrentTime : WorldModifierClock) =
    # add events
    while true:
        let nextEventIndex = view.lastAppliedEvent.int+1
        if world.view.events.len > nextEventIndex and world.eventModificationTimes[nextEventIndex].int <= targetCurrentTime.int:
            addEventToView(view, world.view.events[nextEventIndex], nextEventIndex.WorldEventClock)
            view.lastAppliedEvent = nextEventIndex.WorldEventClock
        else:
            break
    
    # add modifications
    for i in view.lastAppliedIndex.int+1 ..< min(world.modificationContainer.modificationClock.int, targetCurrentTime.int):
        let modifier : EntityModification = world.modificationContainer.modifications[i]
        applyModificationToView(view, modifier, WorldModifierClock(i))

proc advance*(view : WorldView, world : World, targetCurrentTime : WorldEventClock) =
    advance(view, world, world.eventModificationTimes[targetCurrentTime.int - 1])

# proc attachData*[C] (world : var World, entity : Entity, dataType : DataType[C]) =
#     attachData(world, entity, dataType, C())

proc attachData*[C] (world : World, entity : Entity, dataType : DataType[C], dataValue : C = C()) =
    let entityMod = EntityModification(entity : entity, dataTypeIndex : dataType.index, modification : InitialAssignmentModification[C](value : dataValue))
    world.addModification(entityMod)

proc attachData*[C] (world : World, dataType : typedesc[C], dataValue : C = C()) =
    attachData[C](world, WorldEntity, dataType.getDataType())

proc modify*[C,T] (world : World, entity : Entity, modification : FieldModification[C,T]) =
    world.addModification(EntityModification(entity : entity, dataTypeIndex : modification.field.dataType.index, modification : modification))


iterator entitiesWithData*[C](view : WorldView, t : typedesc[C]) : Entity =
    let dataType = t.getDataType()
    var dc = (DataContainer[C]) view.dataContainers[dataType.index]
    for ent in dc.dataStore.keys:
        yield ent

proc addModification* (world : World, modification : EntityModification) =
    world.modificationContainer.modifications.add(modification)
    applyModificationToView(world.view, modification, world.modificationContainer.modificationClock)
    world.modificationContainer.modificationClock.inc


proc data*[C] (view : WorldView, entity : Entity, dataType : DataType[C]) : ref C =
    var dc = (DataContainer[C]) view.dataContainers[dataType.index]
    result = dc.dataStore.getOrDefault(entity, nil)
    if result == nil:
        echo "Warning: read data[", C, "] for entity ", entity.int, " that did not have access to data of that type"
        result = dc.defaultValue

proc data*[C] (view : WorldView, dataType : typedesc[C]) : ref C =
    data[C](view, WorldEntity, dataType.getDataType())

proc hasData*[C] (view : WorldView, entity : Entity, dataType : DataType[C]) : bool =
    var dc = (DataContainer[C]) view.dataContainers[dataType.index]
    result = dc.dataStore.hasKey(entity)

proc data*[C] (world : DisplayWorld, entity : Entity, t : typedesc[C]) : ref C =
    let dataType = t.getDataType()
    var dc = (DataContainer[C]) world.dataContainers[dataType.index]
    result = dc.dataStore.getOrDefault(entity, nil)
    # TODO: Consider auto-attaching data to display worlds
    if result == nil:
        echo "Warning: read display data[", C, "] for entity ", entity.int, " that did not have access to data of that type"
        result = dc.defaultValue

proc data*[C] (world : DisplayWorld, t : typedesc[C]) : ref C =
    data[C](world, WorldEntity, t)

proc attachData*[C] (world : DisplayWorld, entity : Entity, t : typedesc[C], dataValue : C = C()) =
    let dataType = t.getDataType()
    var dc = (DataContainer[C]) world.dataContainers[dataType.index]
    dc.dataStore[entity] = dataValue

proc attachData*[C] (world : DisplayWorld, t : typedesc[C], dataValue : C = C()) =
    attachData(world, WorldEntity, t, dataValue)

macro modify*(world : World, expression : untyped) =
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
