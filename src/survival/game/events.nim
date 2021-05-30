import engines/event_types
import strformat
import glm
import worlds
import entities
import survival_core


type
  PlantCreatedEvent* = ref object of GameEvent
    entity*: Entity
    position*: Vec3i
    plantKind*: Taxon

  RegionInitializedEvent* = ref object of GameEvent
    region*: Entity

  TileChangedEvent* = ref object of GameEvent
    region*: Entity
    tileCoord*: Vec3i

  TileFlagsUpdatedEvent* = ref object of GameEvent

  CreatureMovedEvent* = ref object of GameEvent
    entity*: Entity
    region*: Entity
    fromPosition*: Vec3i
    toPosition*: Vec3i

  EntityDestroyedEvent* = ref object of GameEvent
    entity*: Entity

  ItemCreatedEvent* = ref object of GameEvent
    entity*: Entity
    itemKind*: Taxon

  ItemPlacedEvent* = ref object of GameEvent
    entity*: Entity
    position*: Vec3i
    capsuled*: bool

  ItemMovedToInventoryEvent* = ref object of GameEvent
      entity*: Entity
      fromInventory*: Option[Entity]
      toInventory*: Entity

  WorldAdvancedEvent* = ref object of GameEvent
    tick*: Ticks


template eventToStr(eventName: untyped) =
  method toString*(evt: `eventName`): string =
    result = eventName.astToStr
    result.add("(")
    result.add($(evt[]))
    result.add(")")


eventToStr(PlantCreatedEvent)
eventToStr(RegionInitializedEvent)
eventToStr(TileChangedEvent)
eventToStr(TileFlagsUpdatedEvent)
eventToStr(CreatureMovedEvent)
eventToStr(WorldAdvancedEvent)
eventToStr(EntityDestroyedEvent)
eventToStr(ItemCreatedEvent)
eventToStr(ItemPlacedEvent)
eventToStr(ItemMovedToInventoryEvent)

method toString*(evt: WorldInitializedEvent): string =
   return &"WorldInitializedEvent{$evt[]}"