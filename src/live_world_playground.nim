import worlds
import reflect
import prelude

when isMainModule:
  type Foo = object
    i : int

  defineReflection(Foo)

  var world = createLiveWorld()
  let ent = world.createEntity()

  withWorld(world):
    ent.attachData(Foo(i: 3))

    echoAssert ent.data(Foo).i == 3
    

