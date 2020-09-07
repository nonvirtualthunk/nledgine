import worlds/worlds
import reflects/reflect_macros

type
   DebugData* = object
      name*: string


defineReflection(DebugData)
