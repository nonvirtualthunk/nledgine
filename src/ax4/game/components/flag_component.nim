import ax4/game/flags
import worlds
import engines
import ax4/game/ax_events
import tables



type
   FlagComponent = ref object of GameComponent
        

method initialize(g : FlagComponent, world : World) =
   discard

method update(g : FlagComponent, world : World) =
   discard

method onEvent(g : FlagComponent, world : World, event : Event) =
   ifOfType(event, AxEvent):
      let flagLib = library(FlagBehaviors)
      for flag, info in flagLib.values:
         for behavior in info.behaviors:
            for entity in matches(world, behavior.trigger, event):
               if not behavior.onlyIfPresent or entity.data(world, Flags).flags.contains(flag):
                  modifyFlag(world, entity, flag, behavior.modifier)



when isMainModule:
   import ax4/game/modifiers
   import prelude
   import ax4/game/ax_events

   let world = createWorld()

   let flagComponent = new FlagComponent

   let flag = taxon("Flags", "Dazzled")
   
   let entityA = world.createEntity()
   world.attachData(entityA, Flags())
   modifyFlag(world, entityA, flag, setTo(1))

   echoAssert flagValue(world, entityA, flag) == 1

   # flagComponent.onEvent(world, AxEvent(kind : CharacterTurnEndEvent, entity : entityA))
   flagComponent.onEvent(world, CharacterTurnEndEvent(entity : entityA))

   echoAssert flagValue(world, entityA, flag) == 0
   