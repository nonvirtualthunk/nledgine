import engines/event_types
import strformat
import glm
import worlds
import entities
import survival_core
import options
import tiles
import arxmath


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

  OpacityUpdatedEvent* = ref object of GameEvent
    region*: Entity
    area*: Recti
    layer*: int
    oldOpacity*: uint8
    newOpacity*: uint8

  OpacityInitializedEvent* = ref object of GameEvent
    region*: Entity


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

  CreatureCreatedEvent* = ref object of GameEvent
    entity*: Entity
    creatureKind*: Taxon

  BuildingCreatedEvent* = ref object of GameEvent
    entity*: Entity
    buildingKind*: Taxon

  BurrowSpawnEvent* = ref object of GameEvent
    burrow*: Entity


  EntityMovedToInventoryEvent* = ref object of GameEvent
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

  EntityPlacedEvent* = ref object of GameEvent
    entity*: Entity
    position*: Vec3i


  AttackEvent* = ref object of GameEvent
    attacker*: Entity
    target*: Target
    attackKind*: Taxon

  AttackHitEvent* = ref object of GameEvent
    attacker*: Entity
    target*: Target
    attackKind*: Taxon
    damage*: int
    damageType*: Taxon
    armorReduction*: int

  AttackMissedEvent* = ref object of GameEvent
    attacker*: Entity
    target*: Target



  CouldNotPlaceItemEvent* = ref object of GameEvent
    entity*: Entity
    placedEntity*: Entity
    position*: Vec3i

  CouldNotPlaceEntityEvent* = ref object of GameEvent
    entity*: Entity
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

  DamageTakenEvent* = ref object of GameEvent
    entity*: Entity
    damageTaken*: int
    damageType*: Taxon
    source*: Entity
    reason*: string

  WorldAdvancedEvent* = ref object of GameEvent
    tick*: Ticks

  VisionChangedEvent* = ref object of GameEvent
    entity*: Entity

  IgnitedEvent* = ref object of GameEvent
    actor*: Entity
    target*: Target
    tool*: Entity

  ExtinguishedEvent* = ref object of GameEvent
    extinguishedEntity*: Entity

  FailedToIgniteEvent* = ref object of GameEvent
    actor*: Entity
    target*: Target
    tool*: Entity
    reason*: string

  LocalLightingChangedEvent* = ref object of GameEvent
    lightEntity*: Entity

  ItemEquippedEvent* = ref object of GameEvent
    equippedBy*: Entity
    item*: Entity
    slot*: Taxon

  ItemUnequippedEvent* = ref object of GameEvent
    unequippedBy*: Entity
    item*: Entity
    slot*: Taxon





eventToStr(PlantCreatedEvent)
eventToStr(LocalLightingChangedEvent)
eventToStr(RegionInitializedEvent)
eventToStr(OpacityUpdatedEvent)
eventToStr(OpacityInitializedEvent)
eventToStr(TileChangedEvent)
eventToStr(TileFlagsUpdatedEvent)
eventToStr(CreatureMovedEvent)
eventToStr(WorldAdvancedEvent)
eventToStr(EntityDestroyedEvent)
eventToStr(ItemCreatedEvent)
eventToStr(CreatureCreatedEvent)
eventToStr(BuildingCreatedEvent)
eventToStr(EntityMovedToInventoryEvent)
eventToStr(ItemRemovedFromInventoryEvent)
eventToStr(GatheredEvent)
eventToStr(CouldNotGatherEvent)
eventToStr(TileLayerDestroyedEvent)
eventToStr(FacingChangedEvent)
eventToStr(CouldNotPlaceItemEvent)
eventToStr(FoodEatenEvent)
eventToStr(VisionChangedEvent)
eventToStr(DurabilityReducedEvent)
eventToStr(IgnitedEvent)
eventToStr(FailedToIgniteEvent)
eventToStr(ExtinguishedEvent)
eventToStr(ItemEquippedEvent)
eventToStr(ItemUnequippedEvent)
eventToStr(DamageTakenEvent)
eventToStr(EntityPlacedEvent)
eventToStr(CouldNotPlaceEntityEvent)
eventToStr(BurrowSpawnEvent)
eventToStr(AttackEvent)
eventToStr(AttackHitEvent)
eventToStr(AttackMissedEvent)


proc currentTime*(w: WorldAdvancedEvent): Ticks = w.tick

method toString*(evt: WorldInitializedEvent): string =
   return &"WorldInitializedEvent{$evt[]}"