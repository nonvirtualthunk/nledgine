import game/event_types
import glm


type
  RegionInitializedEvent* = ref object of GameEvent
    region*: Entity

  TileChangedEvent* = ref object of GameEvent
    region*: Entity
    tileCoord*: Vec3i

  TileFlagsUpdatedEvent* = ref object of GameEvent




method toString*(evt: RegionInitializedEvent): string =
   return &"RegionInitializedEvent{$evt[]}"

method toString*(evt: TileChangedEvent): string =
   return &"TileChangedEvent{$evt[]}"