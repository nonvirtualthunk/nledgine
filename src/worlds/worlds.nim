import sequtils
import sugar
import macros
import tables
import typetraits
import options
import reflects/reflect_types
import hashes
import engines/core_event_types
import resources
import noto
import sets

{.experimental.}

type Entity* = object
  id*: int
type DisplayEntity* = object
  id*: int
type WorldEventClock* = distinct int
type WorldModifierClock* = distinct int

const SentinelEntity* = Entity(id: 0)
const SentinelDisplayEntity* = DisplayEntity(id: 0)

let WorldEntity* = Entity(id: 1)
let WorldDisplayEntity = DisplayEntity(id: 1)

type
  AbstractDataContainer = ref object of RootObj

  EntityModification = object
    modification: AbstractModification
    entity: Entity
    dataTypeIndex: int

  ModificationContainer = object
    modifications: seq[EntityModification]
    modificationClock: WorldModifierClock

  DataContainer[T] = ref object of AbstractDataContainer
    dataTypeIndex: int
    lastAppliedIndex: int
    dataStore: Table[int, ref T]
    defaultValue: ref T

  WorldView* = ref object
    entities*: seq[Entity]
    baseView: Option[WorldView]
    dataContainers: seq[AbstractDataContainer]
    lastAppliedEvent: WorldEventClock
    lastAppliedIndex: WorldModifierClock
    events*: seq[Event]
    overlayActive*: bool

  World* = ref object
    view*: WorldView
    modificationContainer: ModificationContainer
    currentTime*: WorldEventClock
    entityCounter: int
    eventModificationTimes: seq[WorldModifierClock] # the "current modifier time" when the event was created, all modifications < that time are included
    eventCallbacks*: seq[(Event) -> void]

  DisplayWorld* = ref object
    entities: seq[DisplayEntity]
    dataContainers: seq[AbstractDataContainer]
    events*: EventBuffer
    entityCounter: int
    eventClock: WorldEventClock
    dataCopyFunctions*: seq[(DisplayWorld, DisplayEntity, DisplayEntity) -> void]

  # A game world not based on journaled modifications
  LiveWorld* = ref object
    entities: HashSet[Entity]
    dataContainers: seq[AbstractDataContainer]
    events*: EventBuffer
    entityCounter: int
    eventClock: WorldEventClock
    eventCallbacks*: seq[(Event) -> void]
    dataCopyFunctions*: seq[(LiveWorld, Entity, Entity) -> void]


converter toView*(world: World): WorldView = world.view

var worldCallsForAllTypes* {.threadvar.}: seq[proc(world: WorldView) {.gcsafe.}]
var liveWorldCallsForAllTypes* {.threadvar.}: seq[proc(world: LiveWorld) {.gcsafe.}]
var displayWorldCallsForAllTypes* {.threadvar.}: seq[proc(world: DisplayWorld) {.gcsafe.}]

proc hash*(e: Entity): int = e.id.hash
proc `==`*(a: Entity, b: Entity): bool = a.id == b.id
proc hash*(e: DisplayEntity): int = e.id.hash
proc `==`*(a: DisplayEntity, b: DisplayEntity): bool = a.id == b.id
proc `+`*(a: WorldModifierClock, b: int): WorldModifierClock = return (a.int + b).WorldModifierClock
proc `-`*(a: WorldModifierClock, b: int): WorldModifierClock = return (a.int - b).WorldModifierClock
proc `==`*(a, b: WorldEventClock): bool {.borrow.}
proc `==`*(a, b: WorldModifierClock): bool {.borrow.}
proc `<`*(a, b: WorldEventClock): bool {.borrow.}
proc `<`*(a, b: WorldModifierClock): bool {.borrow.}
proc `<=`*(a, b: WorldEventClock): bool {.borrow.}
proc `<=`*(a, b: WorldModifierClock): bool {.borrow.}
proc `+=`*(a: var WorldEventClock, d: int) = a = (a.int + d).WorldEventClock

proc `$`*(e: Entity): string =
  return "@(" & $e.id & ")"
proc `$`*(e: DisplayEntity): string =
  return $e.id

proc isSentinel*(e: Entity): bool = e == SentinelEntity
proc isSentinel*(e: DisplayEntity): bool = e == SentinelDisplayEntity

proc currentTime*(view: WorldView): WorldEventClock =
  if view.baseView.isSome:
    view.baseView.get.currentTime
  else:
    (view.lastAppliedEvent.int+1).WorldEventClock


proc applyModificationToView(view: WorldView, modifier: EntityModification, modifierClock: WorldModifierClock)

proc addModification*(world: World, modification: EntityModification) {.gcsafe.}
proc addModification*(view: WorldView, modification: EntityModification) =
  if view.baseView.isNone:
    err &"Views cannot be modified directly unless they are layered on top of a base view"
  else:
    view.overlayActive = true
    applyModificationToView(view, modification, 0.WorldModifierClock)

proc createEntity*(world: World): Entity {.gcsafe.} =
  result = Entity(id: world.entityCounter)
  world.entityCounter.inc

  addModification(world, EntityModification(entity: result, dataTypeIndex: -1))

proc createEntity*(world: DisplayWorld): DisplayEntity =
  result = DisplayEntity(id: world.entityCounter)
  world.entities.add(result)
  world.entityCounter.inc

proc createEntity*(world: LiveWorld): Entity =
  result = Entity(id: world.entityCounter)
  world.entities.incl(result)
  world.entityCounter.inc

proc createWorld*(): World {.gcsafe.} =
  var ret = new World
  ret.view = new WorldView
  ret.view.entities = @[]
  ret.view.dataContainers = newSeq[AbstractDataContainer]()
  ret.view.lastAppliedIndex = (-1).WorldModifierClock
  ret.view.lastAppliedEvent = (-1).WorldEventClock
  ret.view.events = @[]

  ret.entityCounter = 1

  ret.modificationContainer = ModificationContainer(modifications: @[])

  for setup in worldCallsForAllTypes:
    setup(ret.view)

  # create world entity, 1
  discard ret.createEntity()

  return ret

proc createLiveWorld*(): LiveWorld {.gcsafe.} =
  result = new LiveWorld
  result.dataContainers = newSeq[AbstractDataContainer]()
  result.entityCounter = 1
  result.events = createEventBuffer(10000)

  for setup in liveWorldCallsForAllTypes:
    setup(result)

  # create world entity, 1
  discard result.createEntity()

proc createDisplayWorld*(): DisplayWorld {.gcsafe.} =
  var ret = new DisplayWorld
  ret.dataContainers = newSeq[AbstractDataContainer]()
  ret.events = createEventBuffer(1000)
  ret.entityCounter = 1

  for setup in displayWorldCallsForAllTypes:
    setup(ret)

  # create world entity, 1
  discard ret.createEntity()

  return ret

proc addEventToView(view: WorldView, evt: Event, eventTime: WorldEventClock) =
  view.events.add(evt)
  view.lastAppliedEvent = eventTime

proc addEvent*(world: World, evt: Event): WorldEventClock {.discardable.} =
  result = world.currentTime
  world.eventModificationTimes.add(world.modificationContainer.modificationClock)
  addEventToView(world.view, evt, world.currentTime)
  world.currentTime.inc
  for callback in world.eventCallbacks:
    callback(evt)

proc preEvent*(world: World, evt: GameEvent): WorldEventClock {.discardable.} =
  evt.state = GameEventState.PreEvent
  world.addEvent(evt)

proc postEvent*(world: World, evt: GameEvent): WorldEventClock {.discardable.} =
  evt.state = GameEventState.PostEvent
  world.addEvent(evt)

proc addFullEvent*(world: World, evt: GameEvent): WorldEventClock {.discardable.} =
  let copy = evt.deepCopy()
  preEvent(world, evt)
  postEvent(world, copy)

template eventStmts*(world: World, evt: GameEvent, stmts: untyped) =
  world.preEvent(evt.deepCopy())
  block:
    let injectedView {.inject used.} = world.view
    let injectedWorld {.inject used.} = world
    stmts
  world.postEvent(evt)


proc currentTime*(world: LiveWorld) : WorldEventClock = world.eventClock

proc addEvent*(world: LiveWorld, evt: Event): WorldEventClock {.discardable.} =
  result = world.eventClock
  world.events.addEvent(evt)
  world.eventClock.inc
  for callback in world.eventCallbacks:
    callback(evt)

proc preEvent*(world: LiveWorld, evt: GameEvent): WorldEventClock {.discardable.} =
  evt.state = GameEventState.PreEvent
  world.addEvent(evt)

proc postEvent*(world: LiveWorld, evt: GameEvent): WorldEventClock {.discardable.} =
  evt.state = GameEventState.PostEvent
  world.addEvent(evt)

proc addFullEvent*(world: LiveWorld, evt: GameEvent): WorldEventClock {.discardable.} =
  let copy = evt.deepCopy()
  preEvent(world, evt)
  postEvent(world, copy)

template eventStmts*(world: LiveWorld, evt: GameEvent, stmts: untyped) =
  world.preEvent(evt.deepCopy())
  block:
    let injectedWorld {.inject used.} = world
    stmts
  world.postEvent(evt)




proc addEvent*(world: DisplayWorld, evt: Event): WorldEventClock {.discardable.} =
  result = world.eventClock
  world.events.addEvent(evt)
  world.eventClock.inc

proc eventAtTime*(view: WorldView, time: WorldEventClock): Event =
  if view.baseView.isSome:
    view.baseView.get.eventAtTime(time)
  else:
    view.events[time.int]

proc mostRecentEvent*(view: WorldView): Event =
  if view.baseView.isSome:
    if view.events.len > 0:
      view.events[view.events.len - 1]
    else:
      view.baseView.get.mostRecentEvent
  else:
    view.events[view.events.len - 1]

proc setUpType*[C](view: WorldView, dataType: DataType[C]) =
  if view.dataContainers.len <= dataType.index:
    view.dataContainers.setLen(dataType.index + 1)
  let dataContainer = DataContainer[C](dataStore: Table[int, ref C](), defaultValue: new C, dataTypeIndex: dataType.index)
  view.dataContainers[dataType.index] = dataContainer

proc setUpType*[C](world: LiveWorld, dataType: DataType[C]) =
  if world.dataContainers.len <= dataType.index:
    world.dataContainers.setLen(dataType.index + 1)
  let dataContainer = DataContainer[C](dataStore: Table[int, ref C](), defaultValue: new C, dataTypeIndex: dataType.index)
  world.dataContainers[dataType.index] = dataContainer
  let copyFunc = proc (w: LiveWorld, a: Entity, b: Entity) =
    if w.hasData(a, dataType):
      let newv = new C
      newv[] = w.data(a, dataType)[]
      w.attachDataRef(b, newv)
  world.dataCopyFunctions.add(copyFunc)

proc setUpType*[C](world: DisplayWorld, dataType: DataType[C]) =
  if world.dataContainers.len <= dataType.index:
    world.dataContainers.setLen(dataType.index + 1)
  let dataContainer = DataContainer[C](dataStore: Table[int, ref C](), defaultValue: new C, dataTypeIndex: dataType.index)
  world.dataContainers[dataType.index] = dataContainer
  let copyFunc = proc (w: DisplayWorld, a: DisplayEntity, b: DisplayEntity) =
    if w.hasData(a, dataType):
      w.attachData(b, w.data(a, dataType)[])
  world.dataCopyFunctions.add(copyFunc)

method applyModification(container: AbstractDataContainer, entMod: EntityModification, createNew: bool): bool {.base.} =
  {.warning[LockLevel]: off.}
  warn "AbstractDataContainer.applyModification base case reached"
  discard

method removeEntity(container: AbstractDataContainer, entity: int) {.base.} =
  {.warning[LockLevel]: off.}
  discard

method clear(container: AbstractDataContainer) {.base.} =
  {.warning[LockLevel]: off.}
  discard

method getInitialCreationModificaton(container: AbstractDataContainer, entity: int): Option[EntityModification] {.base.} =
  {.warning[LockLevel]: off.}
  discard

method printEntityData*(container: AbstractDataContainer, entity: Entity) {.base.} =
  {.warning[LockLevel]: off.}
  discard


method applyModification[T](container: DataContainer[T], entMod: EntityModification, createNew: bool): bool {.base.} =
  var data = container.dataStore.getOrDefault(entMod.entity.id, nil)
  # todo: warn when we have no existing data and the modification is not an initial setting mod
  if data == nil:
    if createNew:
      data = new T
      container.dataStore[entMod.entity.id] = data
      entMod.modification.apply(data)
      true
    else:
      false
  else:
    entMod.modification.apply(data)
    true

method removeEntity[T](container: DataContainer[T], entity: int) {.base.} =
  container.dataStore.del(entity)

method getInitialCreationModificaton[T](container: DataContainer[T], entity: int): Option[EntityModification] {.base.} =
  var data = container.dataStore.getOrDefault(entity, nil)
  if data == nil:
    none(EntityModification)
  else:
    some(EntityModification(entity: Entity(id: entity), dataTypeIndex: container.dataTypeIndex, modification: InitialAssignmentModification[T](value: data[])))

method printEntityData*[T](container: DataContainer[T], entity: Entity) =
  var data = container.dataStore.getOrDefault(entity.id, nil)
  if data != nil:
    info $T & " {"
    indentLogs()
    for k,v in (data[]).fieldPairs:
      when compiles($v):
        info $k & " : " & $v
      else:
        info $k & " : " & repr(v)

    unindentLogs()
    info "}"


proc printEntityData*(world: LiveWorld, entity: Entity) =
  info &"Entity({entity.id}) " & "{"
  indentLogs()
  for dc in world.dataContainers:
    if dc != nil:
      dc.printEntityData(entity)
  unindentLogs()
  info "}"

proc printEntityData*(world: WorldView, entity: Entity) =
  info &"Entity({entity.id}) " & "{"
  indentLogs()
  for dc in world.dataContainers:
    if dc != nil:
      dc.printEntityData(entity)
  unindentLogs()
  info "}"

method clear[T](container: DataContainer[T]) =
  container.lastAppliedIndex = 0
  container.dataStore.clear()

proc destroyEntity*(world: DisplayWorld, entity: DisplayEntity) =
  for i in 0 ..< world.entities.len:
    if world.entities[i] == entity:
      world.entities.del(i)
      break
  for c in world.dataContainers:
    c.removeEntity(entity.id)

proc destroyEntity*(world: LiveWorld, entity: Entity) =
  world.entities.excl(entity)

  for c in world.dataContainers:
    c.removeEntity(entity.id)


proc createView*(world: World): WorldView =
  deepCopy(world.view)

proc createLayeredView*(view: WorldView): WorldView =
  result = WorldView(baseView: some(view))
  for setup in worldCallsForAllTypes:
    setup(result)

proc applyModificationToView(view: WorldView, modifier: EntityModification, modifierClock: WorldModifierClock) =
  if modifier.dataTypeIndex == -1:
    view.entities.add(modifier.entity)
  else:
    if not view.dataContainers[modifier.dataTypeIndex].applyModification(modifier, false):
      if view.baseView.isSome:
        let baseCreation = view.baseView.get().dataContainers[modifier.dataTypeIndex].getInitialCreationModificaton(modifier.entity.id)
        if baseCreation.isSome:
          discard view.dataContainers[modifier.dataTypeIndex].applyModification(baseCreation.get, true)
      discard view.dataContainers[modifier.dataTypeIndex].applyModification(modifier, true)


  view.lastAppliedIndex = modifierClock

proc clear*(view: WorldView) =
  if view.baseView.isNone:
    err &"Attempting to clear a world view that is not an overlay on another view does not make sense"
  else:
    view.entities.setLen(0)
    for container in view.dataContainers:
      if container != nil:
        container.clear()
    view.lastAppliedEvent = 0.WorldEventClock
    view.lastAppliedIndex = 0.WorldModifierClock
    view.events.setLen(0)
    view.overlayActive = false

proc hasActiveOverlay*(view: WorldView): bool =
  if view.baseView.isNone:
    warn &"Asking a non-layered view if it is an active overlay does not make sense"
    false
  else:
    view.overlayActive



proc advance*(view: WorldView, world: World, targetCurrentTime: WorldModifierClock) =
  if view.baseView.isSome:
    err &"Advancing a view that is layered on top of another view is not supported"

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
    let modifier: EntityModification = world.modificationContainer.modifications[i]
    applyModificationToView(view, modifier, WorldModifierClock(i))

proc advance*(view: WorldView, world: World, targetEventTime: WorldEventClock) =
  while targetEventTime.int > view.lastAppliedEvent.int+1:
    let nextEventIndex = view.lastAppliedEvent.int+1
    addEventToView(view, world.view.events[nextEventIndex], nextEventIndex.WorldEventClock)
    view.lastAppliedEvent = nextEventIndex.WorldEventClock

    let targetModifierClock = world.eventModificationTimes[nextEventIndex]
    for i in view.lastAppliedIndex.int+1 ..< targetModifierClock.int:
      let modifier: EntityModification = world.modificationContainer.modifications[i]
      applyModificationToView(view, modifier, WorldModifierClock(i))


  # if targetCurrentTime.int > view.currentTime.int:
  #   advance(view, world, world.eventModificationTimes[targetEventTime.int - 1])

proc advanceBaseView*(view: WorldView, world: World, targetCurrentTime: WorldModifierClock) =
  advance(view.baseView.get, world, targetCurrentTime)

proc advanceBaseView*(view: WorldView, world: World, targetCurrentTime: WorldEventClock) =
  advance(view.baseView.get, world, targetCurrentTime)
# proc attachData*[C] (world : var World, entity : Entity, dataType : DataType[C]) =
#   attachData(world, entity, dataType, C())

proc attachData*[C] (world: World, entity: Entity, dataValue: C = C()) =
  let entityMod = EntityModification(entity: entity, dataTypeIndex: C.getDataType().index, modification: InitialAssignmentModification[C](value: dataValue))
  world.addModification(entityMod)

proc attachData*[C] (view: WorldView, entity: Entity, dataValue: C) =
  let entityMod = EntityModification(entity: entity, dataTypeIndex: C.getDataType().index, modification: InitialAssignmentModification[C](value: dataValue))
  view.addModification(entityMod)

proc attachData*[C] (world: World, dataType: typedesc[C], dataValue: C = C()) =
  attachData[C](world, WorldEntity, dataType.getDataType(), dataValue)

proc attachData*[C] (world: World, dataValue: C) =
  attachData[C](world, WorldEntity, dataValue)


proc modify*[C, T] (world: World, entity: Entity, modification: FieldModification[C, T]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, T, U] (world: World, entity: Entity, modification: NestedFieldModification[C, T, U]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, K, V] (world: World, entity: Entity, modification: TableFieldModification[C, K, V]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[W : static[int], H : static[int], D : static[int], C, T] (world: World, entity: Entity, modification: GridFieldModification[W, H, D, C, T]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, K1, K2, V] (world: World, entity: Entity, modification: TableFieldTableModification[C, K1, K2, V]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, T, K, V] (world: World, entity: Entity, modification: NestedTableFieldModification[C, T, K, V]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))



proc modify*[C, T] (world: WorldView, entity: Entity, modification: FieldModification[C, T]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, T, U] (world: WorldView, entity: Entity, modification: NestedFieldModification[C, T, U]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, K, V] (world: WorldView, entity: Entity, modification: TableFieldModification[C, K, V]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[W : static[int], H : static[int], D : static[int], C, T] (world: WorldView, entity: Entity, modification: GridFieldModification[W, H, D, C, T]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, K1, K2, V] (world: WorldView, entity: Entity, modification: TableFieldTableModification[C, K1, K2, V]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))

proc modify*[C, T, K, V] (world: WorldView, entity: Entity, modification: NestedTableFieldModification[C, T, K, V]) =
  world.addModification(EntityModification(entity: entity, dataTypeIndex: modification.field.dataType.index, modification: modification))





iterator entitiesWithData*[C](view: WorldView, t: typedesc[C]): Entity =
  let dataType = t.getDataType()
  let dc = (DataContainer[C])view.dataContainers[dataType.index]
  if view.baseView.isNone:
    for ent in dc.dataStore.keys:
      yield Entity(id: ent)
  else:
    var yielded: HashSet[int]
    for ent in dc.dataStore.keys:
      yielded.incl(ent)
      yield Entity(id: ent)
    let baseDC = (DataContainer[C])view.baseView.get.dataContainers[dataType.index]
    for ent in baseDC.dataStore.keys:
      if not yielded.contains(ent):
        yield Entity(id: ent)

iterator entitiesWithData*[C](view: LiveWorld, t: typedesc[C]): Entity =
  let dataType = t.getDataType()
  let dc = (DataContainer[C])view.dataContainers[dataType.index]
  for ent in dc.dataStore.keys:
    yield Entity(id: ent)

iterator entitiesWithEitherData*[C1, C2](view: LiveWorld, t1: typedesc[C1], t2: typedesc[C2]): Entity =
  var seen: HashSet[Entity]
  for e in entitiesWithData(view, t1):
    seen.incl(e)
    yield e
  for e in entitiesWithData(view, t2):
    if not seen.contains(e):
      yield e


proc addModification*(world: World, modification: EntityModification) =
  world.modificationContainer.modifications.add(modification)
  applyModificationToView(world.view, modification, world.modificationContainer.modificationClock)
  world.modificationContainer.modificationClock.inc


proc data*[C] (view: WorldView, entity: Entity, dataType: DataType[C]): ref C =
  var dc = (DataContainer[C])view.dataContainers[dataType.index]
  result = dc.dataStore.getOrDefault(entity.id, nil)
  if result == nil:
    if view.baseView.isSome:
      result = view.baseView.get.data(entity, dataType)
    else:
      writeStackTrace()
      warn &"Warning: read data[{$C}] for entity {entity.id} that did not have access to data of that type"
      result = dc.defaultValue

proc data*[C] (view: WorldView, entity: Entity, dataType: typedesc[C]): ref C =
  data(view, entity, dataType.getDataType())

proc data*[C] (view: WorldView, dataType: typedesc[C]): ref C =
  data[C](view, WorldEntity, dataType.getDataType())

proc hasData*[C] (view: WorldView, entity: Entity, dataType: DataType[C]): bool =
  var dc = (DataContainer[C])view.dataContainers[dataType.index]
  result = dc.dataStore.hasKey(entity.id)
  if not result and view.baseView.isSome:
    result = view.baseView.get.hasData(entity, dataType)

proc hasData*[C] (view: WorldView, dataType: DataType[C]): bool =
  hasData(view, WorldEntity, dataType)

proc hasData*[C] (view: WorldView, dataType: typedesc[C]): bool =
  hasData(view, WorldEntity, dataType.getDataType())

proc data*[C] (world: DisplayWorld, entity: DisplayEntity, dataType: DataType[C]): ref C =
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  result = dc.dataStore.getOrDefault(entity.id, nil)
  # TODO: Consider auto-attaching data to display worlds
  if result == nil:
    writeStackTrace()
    warn &"Warning: read display data[{$C}] for entity {entity.id} that did not have access to data of that type"
    result = dc.defaultValue

proc data*[C] (world: DisplayWorld, entity: DisplayEntity, t: typedesc[C]): ref C =
  data(world, entity, t.getDataType)

proc hasData*[C] (world: DisplayWorld, entity: DisplayEntity, t: DataType[C]): bool =
  var dc = (DataContainer[C])world.dataContainers[t.index]
  result = dc.dataStore.hasKey(entity.id)

proc hasData*[C] (world: DisplayWorld, entity: DisplayEntity, t: typedesc[C]): bool =
  hasData(world, entity, t.getDataType())

proc hasData*[C] (world: DisplayWorld, t: typedesc[C]): bool =
  hasData(world, WorldDisplayEntity, t.getDataType())

proc data*[C] (world: DisplayWorld, t: typedesc[C]): ref C =
  data[C](world, WorldDisplayEntity, t)

proc attachData*[C] (world: DisplayWorld, entity: DisplayEntity, dataValue: C) =
  let dataType = C.getDataType()
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  let nv: ref C = new C
  nv[] = dataValue
  dc.dataStore[entity.id] = nv


proc attachDataInternal[C] (world: DisplayWorld, entity: DisplayEntity, dataType: DataType[C], dataValue: C = C()) =
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  let nv: ref C = new C
  nv[] = dataValue
  dc.dataStore[entity.id] = nv

proc attachData*[C] (world: DisplayWorld, t: typedesc[C]) =
  attachData(world, default(t))

proc attachData*[C] (world: DisplayWorld, dataValue: C) =
  attachData(world, WorldDisplayEntity, dataValue)

proc attachDataRef*[C] (world: DisplayWorld, entity: DisplayEntity, dataValue: ref C) =
  # echo C, ", dt: ", C.getDataType().index #, " size: ", world.dataContainers.len
  var dc = (DataContainer[C])world.dataContainers[C.getDataType().index]
  dc.dataStore[entity.id] = dataValue

proc attachDataRef*[C] (world: DisplayWorld, dataValue: ref C) =
  attachDataRef[C](world, WorldDisplayEntity, dataValue)

macro modify*(world: World, expression: untyped) =
  result = newStmtList()
  if expression.kind == nnkInfix:
    let inf = unpackInfix(expression)
    if inf.left.kind == nnkDotExpr:
      let fieldDef = inf.left[1]
      let assignmentDef = inf.right
      if inf.left[0].kind == nnkDotExpr:
        let entityDef = inf.left[0][0]
        let typeDef = inf.left[0][1]
        # echo "Parsed: entity(" & entityDef.strVal & ") type(" & typeDef.strVal & ") field(" & fieldDef.strVal & ")"
        let fieldName = newDotExpr(newIdentNode(typeDef.strVal & "Type"), newIdentNode(fieldDef.strVal))

        result = quote do:
          world.modify(`entityDef`, `fieldName`, `assignmentDef`)


proc data*[T](entity: Entity, view: WorldView, t: typedesc[T]): ref T =
  view.data(entity, t.getDataType())

macro hasData*(entity: Entity, view: WorldView, t: typedesc): untyped =
  let dataTypeIdent = newIdentNode($t & "Type")
  return quote do:
    `view`.hasData(`entity`, `dataTypeIdent`)

macro `[]`*(entity: Entity, t: typedesc): untyped =
  let dataTypeIdent = newIdentNode($t & "Type")
  result = quote do:
    when declared(injectedView):
      injectedView.data(`entity`, `dataTypeIdent`)
    elif declared(injectedWorld):
      injectedWorld.data(`entity`, `dataTypeIdent`)
    elif declared(world):
      world.data(`entity`, `dataTypeIdent`)
    elif declared(view):
      view.data(`entity`, `dataTypeIdent`)
    else:
      {.error: ("implicit access of data[] must be in a withView(...) or withWorld(...) block").}



macro dataOpt*(entity: Entity, t: typedesc): untyped =
  let dataTypeIdent = newIdentNode($t & "Type")
  result = quote do:
    when declared(injectedView):
      injectedView.dataOpt(`entity`, `dataTypeIdent`)
    elif declared(injectedWorld):
      injectedWorld.dataOpt(`entity`, `dataTypeIdent`)
    elif declared(world):
      when world is LiveWorld:
        world.dataOpt(`entity`, `dataTypeIdent`)
      else:
        {.error: ("implicit access of dataOpt must be in a withView(...) or withWorld(...) block").}
    else:
      {.error: ("implicit access of dataOpt must be in a withView(...) or withWorld(...) block").}
      # when compiles(view.data(`entity`, `dataTypeIdent`)):
      #   view.data(`entity`, `dataTypeIdent`)
      # else:
      #   world.data(`entity`, `dataTypeIdent`)

macro data*(entity: Entity, t: typedesc): untyped =
  let dataTypeIdent = newIdentNode($t & "Type")
  result = quote do:
    # when compiles(view.data(`entity`, `dataTypeIdent`)):
    #   view.data(`entity`, `dataTypeIdent`)
    # else:
    #   world.data(`entity`, `dataTypeIdent`)
    when declared(injectedView):
      injectedView.data(`entity`, `dataTypeIdent`)
    else:
      when injectedWorld is LiveWorld:
        injectedWorld.data(`entity`, `dataTypeIdent`)
      else:
        {.error: ("implicit access of data[] must have access to an injected view").}

macro attachData*(entity: Entity, t: typed): untyped =
  result = quote do:
    when declared(injectedWorld):
      injectedWorld.attachData(`entity`, `t`)
    elif declared(world):
      when world is LiveWorld:
        world.attachData(`entity`, `t`)
      else:
        {.error: ("implicit access of attachData must be in a withWorld(...) block").}
    else:
      {.error: ("implicit access of data[] must be in a withWorld(...) block").}

macro attachData*[T](entity: DisplayEntity, t: T): untyped =
  let dataTypeIdent = newIdentNode(t[0].strVal & "Type")
  result = quote do:
    attachDataInternal(injectedDisplayWorld, `entity`, `dataTypeIdent`, `t`)
    # attachData[`T`](injectedDisplayWorld, `entity`, typedesc[`T`], `t`)

macro hasData*(entity: Entity, t: typedesc): bool =
  result = quote do:
    when declared(injectedView):
      injectedView.hasData(`entity`, `t`.getDataType())
    elif declared(injectedWorld):
      injectedWorld.hasData(`entity`, `t`.getDataType())
    elif declared(world):
      when world is LiveWorld:
        world.hasData(`entity`, `t`.getDataType())
      else:
        {.error: ("implicit access of data[] must be in a withView(...) or withWorld(...) block").}
    else:
      {.error: ("implicit access of data[] must be in a withView(...) or withWorld(...) block").}
    # when compiles(view.hasData(`entity`, `dataTypeIdent`)):
    #   view.hasData(`entity`, `dataTypeIdent`)
    # else:
    #   world.hasData(`entity`, `dataTypeIdent`)

template withView*(view: WorldView, stmts: untyped): untyped =
  block:
    let injectedView {.inject used.} = view
    stmts

template withWorld*(world: World, stmts: untyped): untyped =
  block:
    let injectedView {.inject used.} = world.view
    let injectedWorld {.inject used.} = world
    stmts

template withWorld*(world: LiveWorld, stmts: untyped): untyped =
  block:
    let injectedWorld {.inject used.} = world
    stmts

template withDisplay*(display: DisplayWorld, stmts: untyped): untyped =
  block:
    let injectedDisplayWorld {.inject used.} = display
    stmts

template `[]`*[T] (displayEntity: DisplayEntity, t: typedesc[T]): ref T =
  injectedDisplayWorld.data(displayEntity, t)

proc `[]`*[T] (display: DisplayWorld, t: typedesc[T]): ref T =
  display.data(WorldDisplayEntity, t)

proc `[]`*[T] (view: WorldView, t: typedesc[T]): ref T =
  data(WorldEntity, view, t)

# template dataImpl*(entity : Entity, t : typedesc) =
#   data(injectedView, entity, t)


# template modify*[C,T](entity : Entity, t : FieldModification[C,T]) =
#   world.modify(entity, t)


proc appendToEarliestIdent(n: var NimNode, append: string): bool =
  # echo "ATEI: ", n.repr
  for i in 0 ..< n.len:
    # echo "SubPiece: ", n[i].repr
    if n[i].kind == nnkDotExpr:
      if n[i][0].kind == nnkIdent:
        n[i][0] = newIdentNode(n[i][0].strVal & append)
        # echo "Replaced subPiece: ", n[i][0]
      elif n[i][0][0].kind == nnkIdent:
        n[i][0][0] = newIdentNode(n[i][0][0].strVal & append)
        # echo "Replaced subPiece: ", n[i][0][0]
      else:
        echo "modify won't work"
      break
  return false

macro modify*(entity: Entity, expression: untyped): untyped =
  var argument = expression.copy
  discard appendToEarliestIdent(argument, "Type")
  result = quote do:
    injectedWorld.modify(`entity`, `argument`)
  # echo "Result: ", result.repr

macro modifyWorld*(world: World, expression: untyped): untyped =
  var argument = expression.copy
  discard appendToEarliestIdent(argument, "Type")
  result = quote do:
    `world`.modify(WorldEntity, `argument`)

proc copyEntity*(display: DisplayWorld, original: DisplayEntity): DisplayEntity =
  result = display.createEntity()
  for copyFunc in display.dataCopyFunctions:
    copyFunc(display, original, result)

proc copyEntity*(world: LiveWorld, original: Entity): Entity =
  result = world.createEntity()
  for copyFunc in world.dataCopyFunctions:
    copyFunc(world, original, result)



proc mdata*[C] (world: LiveWorld, entity: Entity, dataType: DataType[C]): ref C =
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  result = dc.dataStore.getOrDefault(entity.id, nil)
  if result == nil:
    result = new C
    dc.dataStore[entity.id] = result

proc data*[C] (world: LiveWorld, entity: Entity, dataType: DataType[C]): ref C =
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  result = dc.dataStore.getOrDefault(entity.id, nil)
  if result == nil:
    writeStackTrace()
    warn &"Warning: read data[{$C}] for entity {entity.id} that did not have access to data of that type"
    result = dc.defaultValue

proc data*[C] (world: LiveWorld, entity: Entity, dataType: typedesc[C]): ref C =
  data(world, entity, dataType.getDatatype())

proc dataOpt*[C] (world: LiveWorld, entity: Entity, dataType: DataType[C]): Option[ref C] =
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  let tmp = dc.dataStore.getOrDefault(entity.id, nil)
  if tmp == nil:
    none(ref C)
  else:
    some(tmp)

proc hasData*[C] (world: LiveWorld, entity: Entity, dataType: DataType[C]): bool =
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  dc.dataStore.contains(entity.id)

proc hasData*[C] (world: LiveWorld, entity: Entity, dataType: typedesc[C]): bool =
  var dc = (DataContainer[C])world.dataContainers[dataType.getDataType().index]
  dc.dataStore.contains(entity.id)


proc data*[C] (world: LiveWorld, dataType: DataType[C]): ref C =
  data(world, WorldEntity, dataType)

proc `[]`*[C] (world: LiveWorld, dataType: typedesc[C]): ref C =
  mdata(world, WorldEntity, dataType.getDataType())

proc hasData*[C] (world: LiveWorld, dataType: DataType[C]): bool =
  hasData(world, WorldEntity, dataType)

proc attachData*[C] (world: LiveWorld, entity: Entity, dataValue: C) =
  when sizeof(C) > 10000:
    # hack because I'm not allowed to use error(...) since it doesn't realize this is a compile time context
    "data value too large to be passed in by copy: " = C
  else:
    let dataType = C.getDataType()
    var dc = (DataContainer[C])world.dataContainers[dataType.index]
    let nv: ref C = new C
    nv[] = dataValue
    dc.dataStore[entity.id] = nv

proc attachDataRef*[C] (world: LiveWorld, entity: Entity, dataValue: ref C) =
  let dataType = C.getDataType()
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  dc.dataStore[entity.id] = dataValue

proc attachData*[C](world: LiveWorld, entity: Entity, t: typedesc[C]) : ref C {.discardable.} =
  let dataType = t.getDataType()
  var dc = (DataContainer[C])world.dataContainers[dataType.index]
  result = new C
  dc.dataStore[entity.id] = result

proc attachData*[C] (world: LiveWorld, dataValue: C) =
  attachData(world, WorldEntity, dataValue)



template ifHasData*[C] (world: LiveWorld, entity: Entity, t: typedesc[C], v : untyped, stmts: untyped) =
  var dc = (DataContainer[C])world.dataContainers[t.getDataType().index]
  let `v` {.inject.} = dc.dataStore.getOrDefault(entity.id, nil)
  if `v` != nil:
    `stmts`


template ifHasData*[C] (entity: Entity, t: typedesc[C], v : untyped, stmts: untyped) =
  when declared(injectedWorld):
    when injectedWorld is LiveWorld:
      var dc = (DataContainer[C])injectedWorld.dataContainers[t.getDataType().index]
    else:
      var dc = (DataContainer[C])injectedWorld.view.dataContainers[t.getDataType().index]
  else:
    when world is LiveWorld:
      var dc = (DataContainer[C])world.dataContainers[t.getDataType().index]
    else:
      var dc = (DataContainer[C])world.view.dataContainers[t.getDataType().index]

  let `v` {.inject.} = dc.dataStore.getOrDefault(entity.id, nil)
  if `v` != nil:
    `stmts`

proc isDestroyed*(world: LiveWorld, entity: Entity): bool =
  not world.entities.contains(entity)