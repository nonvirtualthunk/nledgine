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
import sets
import tables

type
  CreatureComponent* = ref object of LiveGameComponent
    # last updated
    lastUpdatedTick*: Ticks

  FireComponent* = ref object of LiveGameComponent
    # last updated
    lastUpdatedTick*: Ticks


  UpdateTrackingData* = object
    lastUpdatedTick*: Table[string, Ticks]

defineReflection(UpdateTrackingData)



proc lastUpdatedTick*(world: LiveWorld, key: string): Ticks =
  world[UpdateTrackingData].lastUpdatedTick.getOrDefault(key, world[TimeData].initializedTime)

proc setLastUpdatedTick*(world: LiveWorld, key: string, tick: Ticks) =
  world[UpdateTrackingData].lastUpdatedTick[key] = tick

# /+============================================+\
# ||               Fire Component               ||
# \+============================================+/

method initialize(g: FireComponent, world: LiveWorld) =
  g.name = "FireComponent"
  world.attachData(UpdateTrackingData())

method onEvent(g: FireComponent, world: LiveWorld, event: Event) =
  postMatcher(event):
    extract(WorldAdvancedEvent, tick):
      let startTime = lastUpdatedTick(world, "fire")
      let dt = (tick - startTime).int
      echo &"Tick: {tick}, startTime: {startTime}, dt: {dt}, init time: {world[TimeData].initializedTime}"
      for ent in world.entitiesWithData(Fire):
        if not isSurvivalEntityDestroyed(world, ent):
          let fire = ent[Fire]
          if fire.active:
            if not ent.hasData(Flags):
              ent.attachData(Flags())
            ent[Flags].flags[† Flags.Fire] = 1
          else:
            if ent.hasData(Flags):
              ent[Flags].flags[† Flags.Fire] = 0

          if fire.active:
            let region = ent[Physical].region

            if fire.durabilityLossTime.isSome:
              reduceDurability(world, ent, intervalsIn(startTime, tick, fire.durabilityLossTime.get))
            if fire.healthLossTime.isSome:
              discard damageEntity(world, ent, intervalsIn(startTime, tick, fire.healthLossTime.get), † DamageTypes.Fire, "fire")

            let fuelConsumed = dt.float * fire.fuelConsumptionRate.get(1.0)
            fire.fuelRemaining = (fire.fuelRemaining.float - fuelConsumed).int.Ticks
            ifHasData(ent, Fuel, fuel):
              fuel.fuel = (fuel.fuel.int - fuelConsumed.int).Ticks

            if fire.fuelRemaining <= 0.Ticks and not isSurvivalEntityDestroyed(world, ent):
              world.eventStmts(ExtinguishedEvent(extinguishedEntity: ent)):
                fire.fuelRemaining = 0.Ticks
                fire.active = false
                ent[Flags].flags[† Flags.Fire] = 0
                if fire.consumedWhenFuelExhausted:
                  destroySurvivalEntity(world, ent)
        setLastUpdatedTick(world, "fire", tick)



# /+============================================+\
# ||               Creature Component           ||
# \+============================================+/

const HungerDamageInterval = Ticks(200)
const ThirstDamageInterval = Ticks(100)

method initialize(g: CreatureComponent, world: LiveWorld) =
  g.name = "CreatureComponent"

method update(g: CreatureComponent, world: LiveWorld) =
  discard

method onEvent(g: CreatureComponent, world: LiveWorld, event: Event) =
  withWorld(world):
    matcher(event):
      extract(WorldAdvancedEvent, currentTime):
        let startTime = g.lastUpdatedTick

        for ent in world.entitiesWithData(Creature):
          if not isSurvivalEntityDestroyed(world, ent):
            let creature = ent[Creature]
            updateRecoveryAndLoss(creature.hunger, g.lastUpdatedTick, currentTime)
            updateRecoveryAndLoss(creature.hydration, g.lastUpdatedTick, currentTime)
            updateRecoveryAndLoss(creature.stamina, g.lastUpdatedTick, currentTime)

            if creature.hunger.currentValue == 0:
              damageEntity(world, ent, intervalsIn(startTime, currentTime, HungerDamageInterval), † DamageTypes.Hunger, "hunger")
            if creature.hydration.currentValue == 0:
              damageEntity(world, ent, intervalsIn(startTime, currentTime, ThirstDamageInterval), † DamageTypes.Thirst, "thirst")

            if ent[Physical].health.currentValue == 0:
              destroySurvivalEntity(world, ent)

        g.lastUpdatedTick = currentTime




# /+============================================+\
# ||               Physical Component           ||
# \+============================================+/
type
  PhysicalComponent* = ref object of LiveGameComponent
    # last updated
    lastUpdatedTick*: Ticks
    # entities that may need to be updated
    toUpdate*: HashSet[Entity]
    updateAll*: bool


method initialize(g: PhysicalComponent, world: LiveWorld) =
  g.name = "PhysicalComponent"
  g.updateAll = true

method update(g: PhysicalComponent, world: LiveWorld) =
  discard


proc updateEntity(g: PhysicalComponent, world: LiveWorld, entity: Entity, currentTime: Ticks) : bool =
  let phys = entity[Physical]
  updateRecoveryAndLoss(phys.health, g.lastUpdatedTick, currentTime)

  # continue updating this entity as long as its health might recover or be counted down
  (phys.health.lossTime.isSome and phys.health.value.currentValue > 0) or
      (phys.health.recoveryTime.isSome and phys.health.value.currentlyReducedBy > 0)


method onEvent(g: PhysicalComponent, world: LiveWorld, event: Event) =
  withWorld(world):
    postMatcher(event):
      extract(WorldAdvancedEvent, tick):
        if g.updateAll:
          g.updateAll = false
          for ent in world.entitiesWithData(Physical):
            if updateEntity(g, world, ent, tick):
              g.toUpdate.incl(ent)
        else:
          var toRemoveFromUpdate: HashSet[Entity]
          for ent in g.toUpdate:
            if not updateEntity(g, world, ent, tick):
              toRemoveFromUpdate.incl(ent)
          for ent in toRemoveFromUpdate:
            g.toUpdate.excl(ent)

        g.lastUpdatedTick = tick
      extract(DamageTakenEvent, entity):
        g.toUpdate.incl(entity)




# /+============================================+\
# ||                 Burrow Component           ||
# \+============================================+/
type
  BurrowComponent* = ref object of LiveGameComponent
    # last updated
    lastUpdatedTick*: Ticks


method initialize(g: BurrowComponent, world: LiveWorld) =
  g.name = "BurrowComponent"

method update(g: BurrowComponent, world: LiveWorld) =
  discard

proc updateEntity(g: BurrowComponent, world: LiveWorld, burrow: Entity, currentTime: Ticks) =
  if isSurvivalEntityDestroyed(world, burrow): return

  let burrowData = burrow[Burrow]
  # If we haven't reached max population for this burrow yet, check to see if more creatures spawn
  if burrowData.creatures.len < burrowData.maxPopulation:
    burrowData.spawnProgress += currentTime - g.lastUpdatedTick
    let nutrientBonus = (burrowData.nutrientsGathered * TicksPerLongAction).Ticks
    if burrowData.spawnProgress + nutrientBonus > burrowData.spawnInterval:
      spawnCreatureFromBurrow(world, burrow)


method onEvent(g: BurrowComponent, world: LiveWorld, event: Event) =
  withWorld(world):
    postMatcher(event):
      extract(WorldAdvancedEvent, tick):
        if tick - g.lastUpdatedTick > TicksPerLongAction.Ticks:
          for ent in world.entitiesWithData(Burrow):
            updateEntity(g, world, ent, tick)
          g.lastUpdatedTick = tick