import engines/event_types
import strformat
import glm
import worlds
import entities
import survival_core
import options
import tiles


type
  PlantCreatedEvent* = ref object of GameEvent
    entity*: Entity
    position*: Vec3i
    plantKind*: Taxon

  RegionInitializedEvent* = ref object of GameEvent
    region*: Entity

  TileChangedEvent* = ref object of GameEvent
    region*: Entity
    tilePosition*: Vec3i

  TileFlagsUpdatedEvent* = ref object of GameEvent

  CreatureMovedEvent* = ref object of GameEvent
    entity*: Entity
    region*: Entity
    fromPosition*: Vec3i
    toPosition*: Vec3i

  FacingChangedEvent* = ref object of GameEvent
    entity*: Entity
    facing*: Direction

  EntityDestroyedEvent* = ref object of GameEvent
    entity*: Entity

  TileLayerDestroyedEvent* = ref object of GameEvent
    region*: Entity
    tilePosition*: Vec3i
    layerKind*: TileLayerKind
    layerIndex*: int


  ItemCreatedEvent* = ref object of GameEvent
    entity*: Entity
    itemKind*: Taxon

  ItemMovedToInventoryEvent* = ref object of GameEvent
    entity*: Entity
    fromInventory*: Option[Entity]
    toInventory*: Entity

  ItemRemovedFromInventoryEvent* = ref object of GameEvent
    entity*: Entity
    fromInventory*: Entity

  GatheredEvent* = ref object of GameEvent
    entity*: Entity
    items*: seq[Entity]
    actions*: seq[ActionUse]
    fromEntity*: Option[Entity]
    gatherRemaining*: bool

  CouldNotGatherEvent* = ref object of GameEvent
    entity*: Entity
    fromEntity*: Option[Entity]

  ItemPlacedEvent* = ref object of GameEvent
    entity*: Option[Entity]
    placedEntity*: Entity
    position*: Vec3i
    capsuled*: bool

  CouldNotPlaceItemEvent* = ref object of GameEvent
    entity*: Entity
    placedEntity*: Entity
    position*: Vec3i

  FoodEatenEvent* = ref object of GameEvent
    entity*: Entity
    eaten*: Entity
    hungerRecovered*: int
    staminaRecovered*: int
    hydrationRecovered*: int
    sanityRecovered*: int
    healthRecovered*: int

  DurabilityReducedEvent* = ref object of GameEvent
    entity*: Entity
    reducedBy*: int
    newDurability*: int

  WorldAdvancedEvent* = ref object of GameEvent
    tick*: Ticks

  VisionChangedEvent* = ref object of GameEvent
    entity*: Entity


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
eventToStr(ItemRemovedFromInventoryEvent)
eventToStr(GatheredEvent)
eventToStr(CouldNotGatherEvent)
eventToStr(TileLayerDestroyedEvent)
eventToStr(FacingChangedEvent)
eventToStr(CouldNotPlaceItemEvent)
eventToStr(FoodEatenEvent)
eventToStr(VisionChangedEvent)
eventToStr(DurabilityReducedEvent)

method toString*(evt: WorldInitializedEvent): string =
   return &"WorldInitializedEvent{$evt[]}"