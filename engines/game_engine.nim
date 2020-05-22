import ../prelude
import event
import event_types
import macros
import options
include ../world_sugar
import ../noto

type 
    EventCallback = (world : World, evt : Event) -> void

    GameEngineComponent* = ref object of RootRef
        eventBus : EventBus
        eventCallbacks : seq[EventCallback]
        lastUpdated : UnitOfTime

    GameEngine* = ref object
        components : seq[GameEngineComponent]
        world : World



proc newGameEngine(): GameEngine =
    result = GameEngine()
    result.components = @[]
    result.world = createWorld()

proc addComponent*(engine : GameEngine, comp : GameEngineComponent) =
    comp.eventBus = createEventBus(engine.world)
    engine.components.add(comp)


method initialize(g : GameEngineComponent, world : World) {.base.} =
    fine "No initialization impl"
    discard

method update(g : GameEngineComponent, world : World, dt : UnitOfTime) {.base.} =
    fine "No update impl"
    discard

macro onEvent(g : GameEngineComponent, t: typedesc, name : untyped, body : untyped) =
    result = quote do:
        `g`.eventCallbacks.add(proc (world : World, evt : Event) = 
            if evt of `t`:
                let `name` = (`t`) evt
                `body`
        )

proc update(ge : GameEngine) =
    for comp in ge.components:
        while true:
            let evt = comp.eventBus.pollEvent()
            if evt.isSome:
                for callback in comp.eventCallbacks:
                    callback(ge.world, evt.get)
            else:
                break

        let t = relTime()
        let dt = t - comp.lastUpdated
        comp.update(ge.world, dt)

proc initialize*(ge : GameEngine) =
    for comp in ge.components:
        comp.initialize(ge.world)


when isMainModule:
    import ../reflect 

    type 
        TestData = object
            x1 : int
    defineReflection(TestData)

    import glm
    type PrintComponent = ref object of GameEngineComponent
        value* : int

    method initialize(g : PrintComponent, world : World) =
        g.onEvent(MousePress, mpe):
            info "MPE received : " & mpe.toString()
            g.value = 3

        let ent = world.createEntity()
        ent.attachData(TestData(x1 : 3))

        let ent2 = world.createEntity()
            
    method update(g : PrintComponent, world : World, dt : UnitOfTime) =
        for ent in world.entitiesWithData(TestData):
            echo "Entity with TestData exists ", ent

    let engine = newGameEngine()
    engine.addComponent(PrintComponent())

    engine.initialize()

    engine.world.addEvent(MousePress(position : vec2i(1,1)))

    engine.update()