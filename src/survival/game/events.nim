import engines/event_types
import strformat
import glm
import worlds
import entities


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
    fromPosition*: Vec3i
    toPosition*: Vec3i


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

method toString*(evt: WorldInitializedEvent): string =
   return &"WorldInitializedEvent{$evt[]}"