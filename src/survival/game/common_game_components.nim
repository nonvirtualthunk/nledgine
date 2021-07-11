import entities
import core
import engines
import reflect
import prelude
import events
import worlds
import options
import survival_core
import logic
import game/flags


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

  FireComponent* = ref object of LiveGameComponent
    # how frequently this component has to update
    requiredInterval*: Ticks
    # last updated
    lastUpdatedTick*: Ticks



method initialize(g: FireComponent, world: LiveWorld) =
  g.name = "FireComponent"
  g.requiredInterval = 20.Ticks

method onEvent(g: FireComponent, world: LiveWorld, event: Event) =
  matcher(event):
    extract(WorldAdvancedEvent, tick):
      if tick > g.lastUpdatedTick + g.requiredInterval:
        let dt = (tick - g.lastUpdatedTick).int
        for ent in world.entitiesWithData(Fire):
          let fire = ent[Fire]
          if fire.active:
            if not ent.hasData(Flags):
              ent.attachData(Flags())
            ent[Flags].flags[† Flags.Fire] = 1
          else:
            if ent.hasData(Flags):
              ent[Flags].flags[† Flags.Fire] = 0

          if fire.active:
            if fire.durabilityLossTime.isSome or fire.healthLossTime.isSome:
              for i in g.lastUpdatedTick.int ..< tick.int:
                if fire.durabilityLossTime.isSome and i mod fire.durabilityLossTime.get.int == 0:
                  reduceDurability(world, ent, 1)
                if fire.healthLossTime.isSome and i mod fire.healthLossTime.get.int == 0:
                  discard damageEntity(world, ent, 1, "fire")
            fire.fuelRemaining = (fire.fuelRemaining.float - dt.float * fire.fuelConsumptionRate.get(1.0)).int.Ticks
            if fire.fuelRemaining <= 0.Ticks:
              world.eventStmts(ExtinguishedEvent(extinguishedEntity: ent)):
                fire.fuelRemaining = 0.Ticks
                fire.active = false
                ent[Flags].flags[† Flags.Fire] = 0
        g.lastUpdatedTick = tick

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