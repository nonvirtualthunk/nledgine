import prelude
import event
import core_event_types
import macros
include world_sugar
import noto
import algorithm
import core/metrics


type
  EventCallback = proc(world: World, evt: Event) {.gcsafe.}
  LiveWorldEventCallback = proc(world: LiveWorld, evt: Event) {.gcsafe.}


  # EventBusAndCallbacks[CallbackType] = object
    # eventBus : EventBus
    # callbacks : seq[CallbackType]

  ComponentTimer* = object
    updateTimer*: Timer
    eventTimer*: Timer

  GameComponent* = ref object of RootRef
    name*: string
    initializePriority*: int
    eventPriority*: int
    eventCallbacks: seq[EventCallback]
    lastUpdated: UnitOfTime
    componentTimers*: ComponentTimer
    timers*: Table[string, Timer]

  GameEngine* = ref object
    components: seq[GameComponent]
    eventBus: EventBus
    world*: World
    initialized: bool

  LiveGameComponent* = ref object of RootRef
    name*: string
    initializePriority*: int
    eventPriority*: int
    eventCallbacks: seq[LiveWorldEventCallback]
    lastUpdated: UnitOfTime
    componentTimers*: ComponentTimer
    timers*: Table[string, Timer]

  LiveGameEngine* = ref object
    components: seq[LiveGameComponent]
    eventBus: EventBus
    world*: LiveWorld
    initialized: bool



proc processEvents(ge: GameEngine) {.gcsafe.}
proc processEvents(ge: LiveGameEngine) {.gcsafe.}

proc newGameEngine*(): GameEngine =
  let ge = GameEngine()
  result = ge
  result.components = @[]
  result.world = createWorld()
  result.eventBus = createEventBus(result.world)
  result.world.eventCallbacks.add((e: Event) => processEvents(ge))

proc newLiveGameEngine*(): LiveGameEngine =
  let ge = LiveGameEngine()
  result = ge
  result.components = @[]
  result.world = createLiveWorld()
  result.eventBus = createEventBus(result.world.events)
  result.world.eventCallbacks.add((e: Event) => processEvents(ge))





proc addComponent*(engine: GameEngine, comp: GameComponent) =
  engine.components.add(comp)

proc addComponent*(engine: LiveGameEngine, comp: LiveGameComponent) =
  engine.components.add(comp)




method initialize(g: GameComponent, world: World) {.base, locks: "unknown".} =
  fine "No initialization impl for game engine component"
  discard

method update(g: GameComponent, world: World) {.base, locks: "unknown".} =
  fine "No update impl for game engine component"
  discard

method onEvent(g: GameComponent, world: World, event: Event) {.base, locks: "unknown".} =
  discard


method initialize(g: LiveGameComponent, world: LiveWorld) {.base, locks: "unknown".} =
  fine "No initialization impl for game engine component"
  discard

method update(g: LiveGameComponent, world: LiveWorld) {.base, locks: "unknown".} =
  fine "No update impl for game engine component"
  discard

method onEvent(g: LiveGameComponent, world: LiveWorld, event: Event) {.base, locks: "unknown".} =
  discard






# With standard journaled World


macro onEvent*(g: GameComponent, t: typedesc, name: untyped, body: untyped) =
  result = quote do:
    `g`.eventCallbacks.add(proc (world: World, evt: Event) {.gcsafe.} =
      if evt of `t`:
        let `name` = (`t`)evt
        `body`
    )

macro onEvent*(g: LiveGameComponent, t: typedesc, name: untyped, body: untyped) =
  result = quote do:
    `g`.eventCallbacks.add(proc (world: World, evt: Event) {.gcsafe.} =
      if evt of `t`:
        let `name` = (`t`)evt
        `body`
    )





proc init*(t: var ComponentTimer, componentName: string) =
  t.updateTimer = Timer(name: componentName & ".update")
  t.eventTimer = Timer(name: componentName & ".handleEvent")

iterator timers*(t: ComponentTimer) : Timer =
  yield t.updateTimer
  yield t.eventTimer


proc timer*(t: GameComponent, name: string) : Timer =
  if not t.timers.hasKey(name):
    t.timers[name] = timer(name)
  t.timers[name]

proc timer*(t: LiveGameComponent, name: string) : Timer =
  if not t.timers.hasKey(name):
    t.timers[name] = timer(name)
  t.timers[name]


proc update*(ge: GameEngine) =
  # for evt in ge.eventBus.newEvents:
  #   for comp in ge.components:
  #     comp.onEvent(ge.world, evt)
  #     for callback in comp.eventCallbacks:
  #       callback(ge.world, evt)

  for comp in ge.components:
    comp.componentTimers.updateTimer.time(0.05):
      let t = relTime()
      let dt = t - comp.lastUpdated
      comp.update(ge.world)

proc update*(ge: LiveGameEngine) =
  for comp in ge.components:
    comp.componentTimers.updateTimer.time(0.05):
      let t = relTime()
      let dt = t - comp.lastUpdated
      comp.update(ge.world)

proc processEvents(ge: GameEngine) =
  for evt in ge.eventBus.newEvents:
    for comp in ge.components:
      comp.componentTimers.eventTimer.time(0.01, evt.toString):
        comp.onEvent(ge.world, evt)
        for callback in comp.eventCallbacks:
          callback(ge.world, evt)

proc processEvents(ge: LiveGameEngine) =
  if ge.initialized:
    for evt in ge.eventBus.newEvents:
      for comp in ge.components:
        comp.componentTimers.eventTimer.time(0.01, evt.toString):
          comp.onEvent(ge.world, evt)
          for callback in comp.eventCallbacks:
            callback(ge.world, evt)

proc initialize*(ge: GameEngine) =
  if ge.initialized:
    ge.components = ge.components.sortedByIt(it.initializePriority * -1)
    for comp in ge.components:
      comp.initialize(ge.world)
      comp.componentTimers.init(comp.name)
    ge.components = ge.components.sortedByIt(it.eventPriority * -1)
    ge.initialized = true
    ge.processEvents()

proc initialize*(ge: LiveGameEngine) =
  ge.components = ge.components.sortedByIt(it.initializePriority * -1)
  for comp in ge.components:
    comp.initialize(ge.world)
    comp.componentTimers.init(comp.name)
  ge.components = ge.components.sortedByIt(it.eventPriority * -1)
  ge.initialized = true
  ge.processEvents()







proc componentTimingsReport*[T](g: T) : string =
  result = ""
  for comp in g.components:
    for timer in comp.componentTimers.timers:
      result.add($timer)
    for timer in comp.timers.values:
      result.add($timer)



# proc addCallback[CallbackType](ebc : var EventBusAndCallbacks[CallbackType], callback : CallbackType) =
#   ebc.callbacks.add(callback)

# iterator callbackTriggers[CallbackType] (ebc : var EventBusAndCallbacks[CallbackType]) : tuple[a : CallbackType, b : Event] =
#   while true:
#     let evt = ebc.eventBus.pollEvent()
#     if evt.isSome:
#       for callback in ebc.callbacks:
#         yield (callback, evt.get)
#     else:
#       break







when isMainModule:
  import ../reflect

  type
    TestData = object
      x1: int
  defineReflection(TestData)

  import glm
  type PrintComponent = ref object of GameComponent
    value*: int

  method initialize(g: PrintComponent, someOtherWorlds: World) =
    g.onEventOfType(MousePress, mpe):
      info &"MPE received : {mpe.toString()}"
      g.value = 3

    let ent = someOtherWorlds.createEntity()
    someOtherWorlds.attachData(ent, TestData(x1: 3))

    discard someOtherWorlds.createEntity()

  method update(g: PrintComponent, world: World, dt: UnitOfTime) =
    for ent in world.entitiesWithData(TestData):
      echo "Entity with TestData exists ", ent

  let engine = newGameEngine()
  engine.addComponent(PrintComponent())

  engine.initialize()

  engine.world.addEvent(MousePress(position: vec2f(1, 1)))

  engine.update()
