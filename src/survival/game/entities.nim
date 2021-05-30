import tiles
import survival_core
import game/randomness
import worlds
import game/library
import glm
import graphics/image_extras
import core
import tables
import config
import resources
import config/config_helpers
import sets

type
  Vital* = object
    # The maximum value and how much it has been reduced by currently
    value*: Reduceable[int]
    # The number of ticks between recovering a point of this stat
    recoveryTime*: Option[Ticks]
    # The number of ticks between losing a point of this stat
    lossTime*: Option[Ticks]
    # The last point at which this stat recovered/lost
    lastRecoveryOrLoss*: Ticks



  Physical* = object
    # position in three dimensional space within the region, x/y/layer
    position*: Vec3i
    # what region this entity is in
    region*: Entity
    # indicates an object that is lying on the ground in a non-constructed just-sort-of-sitting-around state
    # need to think of a better term
    capsuled*: bool
    # whether or not this entity fully occupies the tile it is on, preventing movement (assuming it is not capsuled)
    occupiesTile*: bool
    # whether or not this entity moves of its own accord
    dynamic*: bool
    # general size/weight, how much space it takes up in an inventory and how hard it is to move
    weight*: int32
    # images to display this entity on the map
    images*: seq[ImageLike]
    # abstraction over how close to destruction the entity is, may be replaced with higher fidelity later
    health*: Vital
    # when this entity was created in game ticks, used to calculate its age
    # note: represents creation in world-time, not game-engine-time, so something may be created as
    # many years old at world gen
    createdAt*: Ticks

  Creature* = object
    # how much energy the creature has for performing difficult actons
    stamina*: Vital
    # how much hydration/water the creature has
    hydration*: Vital
    # how much food the creature has remaining before it starts starving
    hunger*: Vital
    # how many ticks before losing a point of hunger
    hungerLossTime*: Option[Ticks]
    # whether or not the creature has died
    dead*: bool
    # raw physical strength, applies to physical attacks, carrying, pushing, etc
    strength*: int
    # dexterity, quickness, nimbleness, applies to dodging, fine motor skills, etc
    dexterity*: int
    # general hardiness and resistance to damage, illness, etc
    constitution*: int
    # baseline movement time required to traverse a single tile with no obstacles
    baseMoveTime*: Ticks
    # what kind of creature this is, its archetype/species/what have you
    creatureKind*: Taxon

  Player* = object

  Plant* = object
    # current stage of growth (budding, vegetative growth, flowering, etc)
    growthStage*: Taxon


  GatherableResource* = object
    # The actual resource that can be gathered
    resource*: Taxon
    # How much of the resource remains and its maximum possible
    quantity*: Reduceable[int]
    # From what the availability of this resource is derived (i.e. PlantKind, CreatureKind)
    source*: Taxon
    # How many ticks worth of progress have been made on gathering one unit of this resource
    progress*: Ticks

  Gatherable* = object
    # resources that can be gathered from this entity
    resources*: seq[GatherableResource]

  Food* = object
    hunger*: int32
    stamina*: int32
    hydration*: int32
    sanity*: int32
    health*: int32


  LightSource* = object
    # how many tiles out the light will travel if uninterrupted
    brightness*: int

  Combustable* = object
    # how many ticks of fuel this provides to a standard fire
    fuel*: Ticks

  CreatureKind* = object
    health*: DiceExpression
    healthRecoveryTime*: Option[Ticks]
    stamina*: DiceExpression
    staminaRecoveryTime*: Option[Ticks]
    hydration*: DiceExpression
    hydrationLossTime*: Option[Ticks]
    strength*: DiceExpression
    dexterity*: DiceExpression
    constitution*: DiceExpression
    baseMoveTime*: Ticks
    weight*: DiceExpression
    images*: seq[ImageLike]
    # resources that can be gathered from the creature while it is alive
    liveResources*: seq[ResourceYield]
    # resources that can only be gathered from the creature's corpse
    deadResources*: seq[ResourceYield]

  PlantGrowthStageInfo* = object
    # images for this stage of growth
    images*: seq[ImageLike]
    # the age in ticks at which the plant enters this stage
    startAge*: Ticks
    # the resources the plant yields at this stage
    resources*: seq[ResourceYield]
    # whether or not the plant at this stage fully occupies its tile
    occupiesTile*: bool

  PlantKind* = object
    health*: DiceExpression
    healthRecoveryTime*: Option[Ticks]
    # stages of growth this plant goes through
    growthStages*: Table[Taxon, PlantGrowthStageInfo]
    # total lifespan in ticks after which the plant will die of natural causes
    lifespan*: Ticks

  Item* = object
    # how much use this item has remaining before breaking
    durability*: Reduceable[int]
    # what this item breaks down into when it runs out of durability, if anything
    breaksInto*: Option[Taxon]

    # how long remains before this item decays
    decay*: Reduceable[Ticks]
    # what this item decays into, if anything
    decaysInto*: Option[Taxon]

    # what other entity is holding this one in its inventory, if any
    heldBy*: Option[Entity]


  Inventory* = object
    # the maximum amount of weight that can be stored in this inventory
    maximumWeight*: int32
    # the items currently stored in this entity
    items*: HashSet[Entity]

  FoodKind* = object
    hunger*: DiceExpression
    stamina*: DiceExpression
    hydration*: DiceExpression
    sanity*: DiceExpression
    health*: DiceExpression

  ItemKind* = object
    durability*: DiceExpression
    breaksInto*: Option[Taxon]
    decay*: Ticks
    decaysInto*: Option[Taxon]
    weight*: DiceExpression
    health*: DiceExpression
    images*: seq[ImageLike]
    occupiesTile*: bool
    flags*: Table[Taxon, int]
    fuel*: Ticks
    light*: Option[LightSource]
    food*: Option[FoodKind]




defineSimpleReadFromConfig(PlantGrowthStageInfo)
defineSimpleReadFromConfig(PlantKind)
defineSimpleReadFromConfig(FoodKind)

defineReflection(Player)
defineReflection(Creature)
defineReflection(LightSource)
defineReflection(Gatherable)
defineReflection(Plant)
defineReflection(Physical)
defineReflection(Item)
defineReflection(Inventory)
defineReflection(Food)
defineReflection(Combustable)


proc readFromConfig*(cv: ConfigValue, ik: var ItemKind) =
  cv["durability"].readInto(ik.durability)
  cv["decay"].readInto(ik.decay)
  cv["weight"].readInto(ik.weight)
  cv["health"].readInto(ik.health)
  cv["image"].readInto(ik.images)
  cv["images"].readInto(ik.images)
  cv["occupiesTile"].readInto(ik.occupiesTile)
  cv["fuel"].readInto(ik.fuel)
  cv["food"].readInto(ik.food)
  let flags = cv["flags"]
  if flags.isObj:
    for k,v in flags.fields:
      ik.flags[taxon("Flags", k)] = v.asInt

defineSimpleLibrary[PlantKind]("survival/game/plant_kinds.sml", "Plants")
defineSimpleLibrary[ItemKind]("survival/game/items.sml", "Items")


proc vital*(maxV: int): Vital = Vital(value: reduceable(maxV))
proc withRecoveryTime*(v: Vital, t : Ticks): Vital =
  result = v
  result.recoveryTime = some(t)
proc withRecoveryTime*(v: Vital, t : Option[Ticks]): Vital =
  result = v
  result.recoveryTime = t
proc withLossTime*(v: Vital, t : Ticks): Vital =
  result = v
  result.lossTime = some(t)
proc withLossTime*(v: Vital, t : Option[Ticks]): Vital =
  result = v
  result.lossTime = t

proc currentValue*(v: Vital): int = v.value.currentValue
proc maxValue*(v: Vital): int = v.value.maxValue
proc recoverBy*(v: var Vital, i : int) = v.value.recoverBy(i)
proc reduceBy*(v: var Vital, i : int) = v.value.reduceBy(i)
# Updates the vital stat based on the recovery/loss frequency and returns the minimum resolution required to update accurately
proc updateRecoveryAndLoss*(v: var Vital, tick: Ticks) : Ticks =
  var delta = 0
  var interval = 0
  if v.lossTime.isSome and v.recoveryTime.isSome:
    let lt = v.lossTime.get
    let rt = v.recoveryTime.get
    if lt > rt:
      delta = 1
      interval = (rt.float * (1.0 + (rt.float / (lt.float - rt.float)))).int
    elif rt > lt:
      delta = -1
      interval = (lt.float * (1.0 + (lt.float / (rt.float - lt.float)))).int
  elif v.lossTime.isSome:
    delta = -1
    interval = v.lossTime.get.int
  elif v.recoveryTime.isSome:
    delta = 1
    interval = v.recoveryTime.get.int

  if delta != 0 and interval != 0:
    if tick >= v.lastRecoveryOrLoss + interval:
      v.lastRecoveryOrLoss = tick
      if delta > 0:
        v.value.recoverBy(delta)
      else:
        v.value.reduceBy(-delta)

  Ticks(interval)




when isMainModule:
  let lib = library(PlantKind)
  let oak = lib[taxon("PlantKinds", "OakTree")]