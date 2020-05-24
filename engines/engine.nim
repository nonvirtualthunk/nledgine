import ../prelude
import event
import event_types
import macros
include ../world_sugar
import ../noto

type 
    EventCallback = (world : World, evt : Event) -> void
    DisplayEventCallback = (world : World, display : DisplayWorld, evt : Event) -> void

    # EventBusAndCallbacks[CallbackType] = object
        # eventBus : EventBus
        # callbacks : seq[CallbackType]

    GameEngineComponent* = ref object of RootRef
        eventCallbacks : seq[EventCallback]
        lastUpdated : UnitOfTime

    GameEngine* = ref object
        components : seq[GameEngineComponent]
        eventBus : EventBus
        world : World

    GraphicsEngineComponent* = ref object of RootRef
        displayEventCallbacks : seq[DisplayEventCallback]
        lastUpdated : UnitOfTime

    GraphicsEngine* = ref object
        components : seq[GraphicsEngineComponent]
        gameEventBus : EventBus
        displayEventBus : EventBus
        world : World
        displayWorld : DisplayWorld



proc newGameEngine*(): GameEngine =
    result = GameEngine()
    result.components = @[]
    result.world = createWorld()
    result.eventBus = createEventBus(result.world)

proc newGraphicsEngine*(world : World): GraphicsEngine =
    result = GraphicsEngine()
    result.components = @[]
    result.world = world
    result.displayWorld = createDisplayWorld()
    result.gameEventBus = createEventBus(result.world)
    result.displayEventBus = createEventBus(result.displayWorld.events)

proc addComponent*(engine : GameEngine, comp : GameEngineComponent) =
    engine.components.add(comp)

proc addComponent*(engine : GraphicsEngine, comp : GraphicsEngineComponent) =
    engine.components.add(comp)


method initialize(g : GameEngineComponent, world : World) {.base.} =
    fine "No initialization impl for game engine component"
    discard

method update(g : GameEngineComponent, world : World, dt : UnitOfTime) {.base.} =
    fine "No update impl for game engine component"
    discard

method initialize(g : GraphicsEngineComponent, world : World, displayWorld : DisplayWorld) {.base.} =
    fine "No initialization impl for graphics engine component"
    discard

method update(g : GraphicsEngineComponent, world : World, displayWorld : DisplayWorld, dt : UnitOfTime) {.base.} =
    fine "No update impl for graphics engine component"
    discard

macro onEvent*(g : GameEngineComponent, t: typedesc, name : untyped, body : untyped) =
    result = quote do:
        `g`.eventCallbacks.add(proc (world : World, evt : Event) = 
            if evt of `t`:
                let `name` = (`t`) evt
                `body`
        )

macro onEvent*(g : GraphicsEngineComponent, t: typedesc, name : untyped, body : untyped) =
    result = quote do:
        `g`.eventCallbacks.add(proc (world : World, displayWorld : DisplayWorld, evt : Event) = 
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
        comp.update(ge.world, dt)

proc initialize*(ge : GameEngine) =
    for comp in ge.components:
        comp.initialize(ge.world)


proc update*(ge : GraphicsEngine) =
    for evt in ge.gameEventBus.newEvents:
        for comp in ge.components:
            for callback in comp.displayEventCallbacks:
                callback(ge.world, ge.displayWorld, evt)

    for evt in ge.displayEventBus.newEvents:
        for comp in ge.components:
            for callback in comp.displayEventCallbacks:
                callback(ge.world, ge.displayWorld, evt)

    for comp in ge.components:
        let t = relTime()
        let dt = t - comp.lastUpdated
        comp.update(ge.world, ge.displayWorld, dt)

proc initialize*(ge : GraphicsEngine) =
    for comp in ge.components:
        comp.initialize(ge.world, ge.displayWorld)





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
    type PrintComponent = ref object of GameEngineComponent
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