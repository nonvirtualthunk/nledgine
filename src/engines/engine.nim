import ../prelude
import event
import event_types
import macros
include ../world_sugar
import ../noto
import ../graphics/core
import algorithm
import core/metrics
import engines/key_codes

type
  EventCallback = proc(world: World, evt: Event) {.gcsafe.}
  LiveWorldEventCallback = proc(world: LiveWorld, evt: Event) {.gcsafe.}
  DisplayEventCallback = proc(world: World, display: DisplayWorld, evt: Event) {.gcsafe.}

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
    timers*: ComponentTimer

  GameEngine* = ref object
    components: seq[GameComponent]
    eventBus: EventBus
    world*: World

  LiveGameComponent* = ref object of RootRef
    name*: string
    initializePriority*: int
    eventPriority*: int
    eventCallbacks: seq[LiveWorldEventCallback]
    lastUpdated: UnitOfTime
    timers*: ComponentTimer

  LiveGameEngine* = ref object
    components: seq[LiveGameComponent]
    eventBus: EventBus
    world*: LiveWorld

  GraphicsComponent* = ref object of RootRef
    name*: string
    initializePriority*: int
    updatePriority*: int
    eventPriority*: int
    displayEventCallbacks: seq[DisplayEventCallback]
    lastUpdated: UnitOfTime
    timers*: ComponentTimer

  GraphicsEngine* = ref object
    components: seq[GraphicsComponent]
    gameEventBus: EventBus
    displayEventBus: EventBus
    world: World
    liveWorld: LiveWorld
    # this is the simple view into `world` at a specific time
    rawCurrentView: WorldView
    # this is then a layered view on top of that that can be modified
    currentView: WorldView
    displayWorld*: DisplayWorld


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

proc newGraphicsEngine*(gameEngine: GameEngine): GraphicsEngine {.gcsafe.} =
  result = GraphicsEngine()
  result.components = @[]
  result.world = gameEngine.world
  result.rawCurrentView = result.world.createView()
  result.currentView = result.rawCurrentView.createLayeredView()
  result.displayWorld = createDisplayWorld()
  result.gameEventBus = createEventBus(result.rawCurrentView)
  result.displayEventBus = createEventBus(result.displayWorld.events)

proc newGraphicsEngine*(gameEngine: LiveGameEngine): GraphicsEngine {.gcsafe.} =
  result = GraphicsEngine()
  result.components = @[]
  result.liveWorld = gameEngine.world
  result.displayWorld = createDisplayWorld()
  result.gameEventBus = createEventBus(result.liveWorld.events)
  result.displayEventBus = createEventBus(result.displayWorld.events)

proc addComponent*(engine: GameEngine, comp: GameComponent) =
  engine.components.add(comp)

proc addComponent*(engine: LiveGameEngine, comp: LiveGameComponent) =
  engine.components.add(comp)

proc addComponent*(engine: GraphicsEngine, comp: GraphicsComponent) =
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
method initialize(g: GraphicsComponent, world: World, curView: WorldView, displayWorld: DisplayWorld) {.base, locks: "unknown".} =
  fine "No initialization impl for graphics engine component"
  discard

method update(g: GraphicsComponent, world: World, curView: WorldView, displayWorld: DisplayWorld, df: float): seq[DrawCommand] {.base, locks: "unknown".} =
  fine "No update impl for graphics engine component"
  discard

method onEvent(g: GraphicsComponent, world: World, curView: WorldView, displayWorld: DisplayWorld, event: Event) {.base, locks: "unknown".} =
  discard

# With LiveWorld
method initialize(g: GraphicsComponent, world: LiveWorld, displayWorld: DisplayWorld) {.base, locks: "unknown".} =
  fine "No initialization impl for graphics engine component"
  discard

method update(g: GraphicsComponent, world: LiveWorld, displayWorld: DisplayWorld, df: float): seq[DrawCommand] {.base, locks: "unknown".} =
  fine "No update impl for graphics engine component"
  discard

method onEvent(g: GraphicsComponent, world: LiveWorld, displayWorld: DisplayWorld, event: Event) {.base, locks: "unknown".} =
  discard

# Ignoring world entirely
method initialize(g: GraphicsComponent, displayWorld: DisplayWorld) {.base, locks: "unknown".} =
  fine "No initialization impl for graphics engine component"
  discard

method update(g: GraphicsComponent, displayWorld: DisplayWorld, df: float): seq[DrawCommand] {.base, locks: "unknown".} =
  fine "No update impl for graphics engine component"
  discard

method onEvent(g: GraphicsComponent, displayWorld: DisplayWorld, event: Event) {.base, locks: "unknown".} =
  discard




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


macro onEvent*(g: GraphicsComponent, t: typedesc, name: untyped, body: untyped) =
  result = quote do:
    `g`.displayEventCallbacks.add(proc (world: World, displayWorld: DisplayWorld, evt: Event) {.gcsafe.} =
      if evt of `t`:
        let `name` = (`t`)evt
        `body`
    )


proc init(t: var ComponentTimer, componentName: string) =
  t.updateTimer = Timer(name: componentName & ".update")
  t.eventTimer = Timer(name: componentName & ".handleEvent")

iterator timers*(t: ComponentTimer) : Timer =
  yield t.updateTimer
  yield t.eventTimer




proc update*(ge: GameEngine) =
  # for evt in ge.eventBus.newEvents:
  #   for comp in ge.components:
  #     comp.onEvent(ge.world, evt)
  #     for callback in comp.eventCallbacks:
  #       callback(ge.world, evt)

  for comp in ge.components:
    comp.timers.updateTimer.time(0.05):
      let t = relTime()
      let dt = t - comp.lastUpdated
      comp.update(ge.world)

proc update*(ge: LiveGameEngine) =
  for comp in ge.components:
    comp.timers.updateTimer.time(0.05):
      let t = relTime()
      let dt = t - comp.lastUpdated
      comp.update(ge.world)

proc processEvents(ge: GameEngine) =
  for evt in ge.eventBus.newEvents:
    for comp in ge.components:
      comp.timers.eventTimer.time(0.01, evt.toString):
        comp.onEvent(ge.world, evt)
        for callback in comp.eventCallbacks:
          callback(ge.world, evt)

proc processEvents(ge: LiveGameEngine) =
  for evt in ge.eventBus.newEvents:
    for comp in ge.components:
      comp.timers.eventTimer.time(0.01, evt.toString):
        comp.onEvent(ge.world, evt)
        for callback in comp.eventCallbacks:
          callback(ge.world, evt)

proc initialize*(ge: GameEngine) =
  ge.components = ge.components.sortedByIt(it.initializePriority * -1)
  for comp in ge.components:
    comp.initialize(ge.world)
    comp.timers.init(comp.name)
  ge.components = ge.components.sortedByIt(it.eventPriority * -1)

proc initialize*(ge: LiveGameEngine) =
  ge.components = ge.components.sortedByIt(it.initializePriority * -1)
  for comp in ge.components:
    comp.initialize(ge.world)
    comp.timers.init(comp.name)
  ge.components = ge.components.sortedByIt(it.eventPriority * -1)

proc update*(ge: GraphicsEngine, channel: var Channel[DrawCommand], df: float) {.gcsafe.} =
  for evt in ge.gameEventBus.newEvents:
    for comp in ge.components:
      comp.timers.eventTimer.time(0.01, evt.toString):
        # worldless
        comp.onEvent(ge.displayWorld, evt)
        if ge.world != nil:
          # journaled world
          comp.onEvent(ge.world, ge.currentView, ge.displayWorld, evt)
          for callback in comp.displayEventCallbacks:
            callback(ge.world, ge.displayWorld, evt)
        else:
          # live world
          comp.onEvent(ge.liveWorld, ge.displayWorld, evt)

  for evt in ge.displayEventBus.newEvents:
    for comp in ge.components:
      comp.timers.eventTimer.time(0.01, evt.toString):
        if not evt.isConsumed:
          # worldless
          comp.onEvent(ge.displayWorld, evt)
          # journaled world
          if ge.world != nil:
            comp.onEvent(ge.world, ge.currentView, ge.displayWorld, evt)
            for callback in comp.displayEventCallbacks:
              if not evt.isConsumed:
                callback(ge.world, ge.displayWorld, evt)
          else:
            # live world
            comp.onEvent(ge.liveWorld, ge.displayWorld, evt)

  ge.components = ge.components.sortedByIt(it.updatePriority * -1)
  for comp in ge.components:
    comp.timers.updateTimer.time(0.05):
      # try updating without any world supplied, if supported
      let worldlessCommands = comp.update(ge.displayWorld, df)
      let commands = if worldlessCommands.len > 0:
        worldlessCommands
      elif ge.world != nil: # otherwise do the journaled world if present
        comp.update(ge.world, ge.currentView, ge.displayWorld, df)
      else: # otherwise use the live world
        comp.update(ge.liveWorld, ge.displayWorld, df)

      for command in commands:
        discard channel.trySend(command)
  discard channel.trySend(DrawCommand(kind: DrawCommandKind.Finish))

proc initialize*(ge: GraphicsEngine) =
  ge.components = ge.components.sortedByIt(it.initializePriority * -1)
  for comp in ge.components:
    comp.initialize(ge.displayWorld)
    if ge.world != nil:
      comp.initialize(ge.world, ge.currentView, ge.displayWorld)
    else:
      comp.initialize(ge.liveWorld, ge.displayWorld)

    comp.timers.init(comp.name)
  ge.components = ge.components.sortedByIt(it.eventPriority * -1)



proc componentTimingsReport*[T](g: T) : string =
  result = ""
  for comp in g.components:
    for timer in comp.timers.timers:
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
    g.onEvent(MousePress, mpe):
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
