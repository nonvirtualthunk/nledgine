import ax4/game/flags
import worlds
import engines
import ax4/game/ax_events
import tables
import noto
import prelude
import ax4/game/characters
import core
import hex



type
   ConditionsComponent* = ref object of GameComponent


method initialize*(g: ConditionsComponent, world: World) =
   g.name = "ConditionsComponent"
   discard

method onEvent*(g: ConditionsComponent, world: World, event: Event) =
   withView(world):
      ifOfType(AxEvent, event):
         if event.state == PostEvent:
            matcher(event):
               extract(DamageEvent, entity):
                  if entity[Character].health.currentValue <= 0:
                     killCharacter(world, entity)
