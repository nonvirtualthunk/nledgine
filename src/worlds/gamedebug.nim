import worlds/worlds
import reflects/reflect_macros
import noto

type
   DebugData* = object
      name*: string


defineReflection(DebugData)




when isMainModule:
  let world = createLiveWorld()
  let ent = world.createEntity()
  withWorld(world):
    ent.attachData(DebugData(name: "Hello"))
    printEntityData(world, ent)