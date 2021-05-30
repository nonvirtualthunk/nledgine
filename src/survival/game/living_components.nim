import entities
import core
import engines
import reflect
import prelude
import events
import worlds
import options
import survival_core


type
  CreatureComponent* = ref object of LiveGameComponent
    # how frequently this component has to update to get the necessary vital statistic updates
    requiredInterval*: Ticks
    # last updated
    lastUpdatedTick*: Ticks

  PhysicalComponent* = ref object of LiveGameComponent
    # how frequently this component has to update to get the necessary vital statistic updates
    requiredInterval*: Ticks
    # last updated
    lastUpdatedTick*: Ticks



method initialize(g: CreatureComponent, world: LiveWorld) =
  g.name = "CreatureComponent"

method update(g: CreatureComponent, world: LiveWorld) =
  discard

method onEvent(g: CreatureComponent, world: LiveWorld, event: Event) =
  withWorld(world):
    matcher(event):
      extract(WorldAdvancedEvent, tick):
        if tick > g.lastUpdatedTick + g.requiredInterval:
          g.lastUpdatedTick = tick
          g.requiredInterval = Ticks(1000)
          for ent in world.entitiesWithData(Creature):
            let creature = ent[Creature]
            g.requiredInterval = min(updateRecoveryAndLoss(creature.hunger, tick), g.requiredInterval)
            g.requiredInterval = min(updateRecoveryAndLoss(creature.hydration, tick), g.requiredInterval)
            g.requiredInterval = min(updateRecoveryAndLoss(creature.stamina, tick), g.requiredInterval)





method initialize(g: PhysicalComponent, world: LiveWorld) =
  g.name = "PhysicalComponent"

method update(g: PhysicalComponent, world: LiveWorld) =
  discard

method onEvent(g: PhysicalComponent, world: LiveWorld, event: Event) =
  withWorld(world):
    postMatcher(event):
      extract(WorldAdvancedEvent, tick):
        if tick > g.lastUpdatedTick + g.requiredInterval:
          g.lastUpdatedTick = tick
          g.requiredInterval = Ticks(1000)
          for ent in world.entitiesWithData(Physical):
            let phys = ent[Physical]
            g.requiredInterval = min(updateRecoveryAndLoss(phys.health, tick), g.requiredInterval)