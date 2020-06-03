import reflect

{.experimental.}

# dumpAstGen:
#     type
#         FooTypeDef = object of DataType[Foo]
#             value : Field[Foo,int]

#     let FooFieldValue = new(Field[Foo,typeof(Foo.value)])
#     FooFieldValue.name = "value"
#     FooFieldValue.setter = proc(obj : ref Foo, value : typeof(Foo.value)) =
#             (obj.value = value)
#     FooFieldValue.getter = proc(obj : Foo) : typeof(Foo.value) =
#                 obj.value
#     FooFieldValue.index = 0

#     let FooType = FooTypeDef(
#         name : "Foo",
#         index : dataTypeIndexCounter,
#         value : FooFieldValue[],
#         fields : @[cast[ref AbstractField[Foo]](FooFieldValue)]
#     )
#     dataTypeIndexCounter.inc


when isMainModule:
    import macros
    import engines/event_types
        
    include world_sugar
    
    proc shineLight(brightness : int) = 
        discard
    proc applyPhysics(entity : Entity, weight : int) = 
        discard

    # Define some types of data that our entities might have
    type
        LightSource* =object
            brightness : int
            color : seq[int]

        Item* =object
            weight : int

    type
        UpdateEvent = ref object of Event


    
    # type
    #     ItemTypeDef_5025665 = ref object of DataType[Item]
    #         weight*: Field[Item, int]

    # let ItemFieldweight_5025668 = new(Field[Item, int])
    # ItemFieldweight_5025668.name = "weight"
    # ItemFieldweight_5025668.index = 0
    # ItemFieldweight_5025668.setter = proc (obj: ref Item; valuegensym5025669: int) = obj.weight = valuegensym5025669
    # ItemFieldweight_5025668.getter = proc (obj: Item): int = result = obj.weight
    # ItemFieldweight_5025668.varGetter = proc (obj: ref Item): var int = result = obj.weight
    # let ItemType = new(ItemTypeDef_5025665)
    # ItemType.name = "Item"
    # ItemType.index = 1
    # ItemFieldweight_5025668.dataType = ItemType
    # ItemType.weight = ItemFieldweight_5025668
    # proc getDataType(tgensym5025670: typedesc[Item]): DataType[Item] {.inline.} =
    #     return ItemType

    # Call macros that introspect on the type given to them at compile time and define types and methods for
    # performing reflection on them, with no[1] runtime overhead.
    #   [1] terms and conditions apply
    defineReflection(LightSource)
    defineReflection(Item)

    # Create a new world to hold our entities
    let world = createWorld()
    # Create a second view of that same world that can be moved through time independently, currently it
    # is pointing at the world at the beginning of time, where it is right now
    let historicalView = world.createView()

    withWorld world:
        # Create a lamp and attach data to it, both as a light source and an item
        let lamp = world.createEntity()
        lamp.attachData(LightSource(brightness : 4))
        lamp.attachData(Item(weight : 5))

        # Create a sun and attach just light source information to it
        let sun = world.createEntity()
        sun.attachData(LightSource(brightness : 20))

        
        # retrieve the light source information for our lamp, it should be the same as when we set it
        let lampLS = lamp.data(LightSource)
        echoAssert lampLS.brightness == 4

        # increase the brightness by 3, that should take effect immediately within our view of the current world
        lamp.modify(LightSource.brightness += 3)
        echoAssert lampLS.brightness == 7

        # here we can apply different effects to entities based on what data they have, so the sun and lamp will 
        # both shine light, but only the lamp will be affected by physics. That way you can composite together
        # different subsets of functionality on entities without dealing with weird inheritance hierarchies
        for entity in world.view.entities:
            if entity.hasData(LightSource):
                # for convenience we have the even more minimal syntax `entity[TypeName]` to reference data
                shineLight(entity[LightSource].brightness)
            if entity.hasData(Item):
                applyPhysics(entity, entity[Item].weight)

        # the historical view doesn't have anything in it yet, it's still pointing to the beginning of time
        # if we look at our entities, they won't have any data
        echoAssert lamp.hasData(historicalView, LightSource) == false

        # advance time to the point where the entities have been created and had their initial data attached
        historicalView.advance(world, 6.WorldModifierClock) 
        # now the lamp has the brightness it had when we first created it
        echoAssert historicalView.data(lamp, LightSourceType).brightness == 4

        # now advance further and we'll get the change we made to brightness
        historicalView.advance(world, 7.WorldModifierClock)
        echoAssert lamp.data(historicalView, LightSource).brightness == 7

        # This is super useful for maintaining a separation between the world as you are simulating it and the
        # world as you are displaying it. Simple animation can be implemented by simply advancing the modifier
        # clock forward every N seconds (but you can do rather better than that if you look at what the actual
        # modifications are and add extra logic around it).


        lamp.modify(LightSource.brightness += 1)

        let evt = UpdateEvent()
        world.addEvent(evt)

        echoAssert lamp.data(historicalView, LightSource).brightness == 7
        echoAssert lamp.data(world.view, LightSource).brightness == 8

        historicalView.advance(world, world.currentTime)

        echoAssert lamp.data(historicalView, LightSource).brightness == 8
        echoAssert historicalView.events[0] of UpdateEvent

        withView historicalView:
            echoAssert lamp.data(LightSource).brightness == 8




    let display = createDisplayWorld()

    let displayEnt = display.createEntity()

    withDisplay display:
        displayEnt.attachData(Item(weight : 1))

        echoAssert displayEnt[Item].weight == 1

        displayEnt[Item].weight = 3

        echoAssert displayEnt[Item].weight == 3



    proc runSeparateThread(initializers : ReflectInitializers) {.thread.} = 
        for op in initializers:
            op()
        
        var world = createWorld()
        withWorld world:
            # Create a lamp and attach data to it, both as a light source and an item
            let lamp = world.createEntity()
            lamp.attachData(LightSource(brightness : 4))
            lamp.attachData(Item(weight : 5))

            # Create a sun and attach just light source information to it
            let sun = world.createEntity()
            sun.attachData(LightSource(brightness : 20))

            
            # retrieve the light source information for our lamp, it should be the same as when we set it
            let lampLS = lamp.data(LightSource)
            echoAssert lampLS.brightness == 4
            
                

    var separateThread : Thread[ReflectInitializers]
    createThread(separateThread, runSeparateThread, reflectInitializers)
    separateThread.joinThread()
