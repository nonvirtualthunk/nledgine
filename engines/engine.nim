import ../prelude
import event
import event_types
import macros
include ../world_sugar
import ../noto
import ../graphics/core

type 
    EventCallback = proc(world : World, evt : Event) {.gcsafe.}
    DisplayEventCallback = proc(world : World, display : DisplayWorld, evt : Event) {.gcsafe.}

    # EventBusAndCallbacks[CallbackType] = object
        # eventBus : EventBus
        # callbacks : seq[CallbackType]

    GameComponent* = ref object of RootRef
        eventCallbacks : seq[EventCallback]
        lastUpdated : UnitOfTime

    GameEngine* = ref object
        components : seq[GameComponent]
        eventBus : EventBus
        world : World

    GraphicsComponent* = ref object of RootRef
        displayEventCallbacks : seq[DisplayEventCallback]
        lastUpdated : UnitOfTime

    GraphicsEngine* = ref object
        components : seq[GraphicsComponent]
        gameEventBus : EventBus
        displayEventBus : EventBus
        world : World
        currentView : WorldView
        displayWorld* : DisplayWorld



proc newGameEngine*(): GameEngine =
    result = GameEngine()
    result.components = @[]
    result.world = createWorld()
    result.eventBus = createEventBus(result.world)

proc newGraphicsEngine*(gameEngine : GameEngine): GraphicsEngine {.gcsafe.} =
    result = GraphicsEngine()
    result.components = @[]
    result.world = gameEngine.world
    result.currentView = result.world.createView()
    result.displayWorld = createDisplayWorld()
    result.gameEventBus = createEventBus(result.world)
    result.displayEventBus = createEventBus(result.displayWorld.events)

proc addComponent*(engine : GameEngine, comp : GameComponent) =
    engine.components.add(comp)

proc addComponent*(engine : GraphicsEngine, comp : GraphicsComponent) =
    engine.components.add(comp)


method initialize(g : GameComponent, world : World) {.base.} =
    fine "No initialization impl for game engine component"
    discard

method update(g : GameComponent, world : World) {.base.} =
    fine "No update impl for game engine component"
    discard

method initialize(g : GraphicsComponent, world : World, curView : WorldView, displayWorld : DisplayWorld) {.base.} =
    fine "No initialization impl for graphics engine component"
    discard

method update(g : GraphicsComponent, world : World, curView : WorldView, displayWorld : DisplayWorld, df : float) : seq[DrawCommand] {.base.} =
    fine "No update impl for graphics engine component"
    discard

macro onEvent*(g : GameComponent, t: typedesc, name : untyped, body : untyped) =
    result = quote do:
        `g`.eventCallbacks.add(proc (world : World, evt : Event) {.gcsafe.} = 
            if evt of `t`:
                let `name` = (`t`) evt
                `body`
        )

macro onEvent*(g : GraphicsComponent, t: typedesc, name : untyped, body : untyped) =
    result = quote do:
        `g`.eventCallbacks.add(proc (world : World, displayWorld : DisplayWorld, evt : Event) {.gcsafe.} = 
            if evt of `t`:
                let `name` = (`t`) evt
                `body`
        )


proc update*(ge : GameEngine) =
    for evt in ge.eventBus.newEvents:
        for comp in ge.components:
            for callback in comp.eventCallbacks:
                callback(ge.world, evt)

    for comp in ge.components:
        let t = relTime()
        let dt = t - comp.lastUpdated
        comp.update(ge.world)

proc initialize*(ge : GameEngine) =
    for comp in ge.components:
        comp.initialize(ge.world)


proc update*(ge : GraphicsEngine, channel : var Channel[DrawCommand], df : float) {.gcsafe.} =
    for evt in ge.gameEventBus.newEvents:
        for comp in ge.components:
            for callback in comp.displayEventCallbacks:
                callback(ge.world, ge.displayWorld, evt)

    for evt in ge.displayEventBus.newEvents:
        for comp in ge.components:
            for callback in comp.displayEventCallbacks:
                callback(ge.world, ge.displayWorld, evt)

    for comp in ge.components:
        let commands = comp.update(ge.world, ge.currentView, ge.displayWorld, df)
        for command in commands:
            channel.send(command)

proc initialize*(ge : GraphicsEngine) =
    for comp in ge.components:
        comp.initialize(ge.world, ge.currentView, ge.displayWorld)





# proc addCallback[CallbackType](ebc : var EventBusAndCallbacks[CallbackType], callback : CallbackType) =
#     ebc.callbacks.add(callback)

# iterator callbackTriggers[CallbackType] (ebc : var EventBusAndCallbacks[CallbackType]) : tuple[a : CallbackType, b : Event] =
#     while true:
#         let evt = ebc.eventBus.pollEvent()
#         if evt.isSome:
#             for callback in ebc.callbacks:
#                 yield (callback, evt.get)
#         else:
#             break







when isMainModule:
    import ../reflect 

    type 
        TestData = object
            x1 : int
    defineReflection(TestData)

    import glm
    type PrintComponent = ref object of GameComponent
        value* : int

    method initialize(g : PrintComponent, someOtherWorlds : World) =
        g.onEvent(MousePress, mpe):
            info "MPE received : " & mpe.toString()
            g.value = 3

        let ent = someOtherWorlds.createEntity()
        someOtherWorlds.attachData(ent, TestDataType, TestData(x1 : 3))

        discard someOtherWorlds.createEntity()
            
    method update(g : PrintComponent, world : World, dt : UnitOfTime) =
        for ent in world.entitiesWithData(TestData):
            echo "Entity with TestData exists ", ent

    let engine = newGameEngine()
    engine.addComponent(PrintComponent())

    engine.initialize()

    engine.world.addEvent(MousePress(position : vec2i(1,1)))

    engine.update()