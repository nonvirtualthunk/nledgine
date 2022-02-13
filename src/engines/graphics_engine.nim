import graphics/core
import prelude
import event
import event_types
import macros
import noto
import algorithm
import core/metrics
import engines/key_codes
import engine

type
  DisplayEventCallback = proc(world: World, display: DisplayWorld, evt: Event) {.gcsafe.}

  GraphicsComponent* = ref object of RootRef
    name*: string
    initializePriority*: int
    updatePriority*: int
    eventPriority*: int
    displayEventCallbacks: seq[DisplayEventCallback]
    lastUpdated: UnitOfTime
    componentTimers*: ComponentTimer
    timers*: Table[string, Timer]


  GraphicsEngine* = ref object
    components*: seq[GraphicsComponent]
    gameEventBus: EventBus
    displayEventBus: EventBus
    world: World
    liveWorld: LiveWorld
    # this is the simple view into `world` at a specific time
    rawCurrentView: WorldView
    # this is then a layered view on top of that that can be modified
    currentView: WorldView
    displayWorld*: DisplayWorld


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

proc addComponent*(engine: GraphicsEngine, comp: GraphicsComponent) =
  engine.components.add(comp)

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

proc initialize*(ge: GraphicsEngine) =
  ge.components = ge.components.sortedByIt(it.initializePriority * -1)
  for comp in ge.components:
    comp.initialize(ge.displayWorld)
    if ge.world != nil:
      comp.initialize(ge.world, ge.currentView, ge.displayWorld)
    else:
      comp.initialize(ge.liveWorld, ge.displayWorld)

    comp.componentTimers.init(comp.name)
  ge.components = ge.components.sortedByIt(it.eventPriority * -1)


macro onEvent*(g: GraphicsComponent, t: typedesc, name: untyped, body: untyped) =
  result = quote do:
    `g`.displayEventCallbacks.add(proc (world: World, displayWorld: DisplayWorld, evt: Event) {.gcsafe.} =
      if evt of `t`:
        let `name` = (`t`)evt
        `body`
    )


proc timer*(t: GraphicsComponent, name: string) : Timer =
  if not t.timers.hasKey(name):
    t.timers[name] = timer(name)
  t.timers[name]


proc update*(ge: GraphicsEngine, channel: var Channel[DrawCommand], df: float) {.gcsafe.} =
  for evt in ge.gameEventBus.newEvents:
    for comp in ge.components:
      comp.componentTimers.eventTimer.time(0.01, evt.toString):
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
      comp.componentTimers.eventTimer.time(0.01, evt.toString):
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
    comp.componentTimers.updateTimer.time(0.05):
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