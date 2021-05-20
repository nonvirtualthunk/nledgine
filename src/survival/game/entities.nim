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

type
  Physical* = object
    # position in three dimensional space within the region, x/y/layer
    position*: Vec3i
    # whether the entity is constructed/standing/built and therefore occupying the space
    # as opposed to simply being present on the ground in item form
    built*: bool
    # images to display this entity on the map
    images*: seq[ImageLike]
    # general size/weight, how much space it takes up in an inventory and how hard it is to move
    weight*: int
    # abstraction over how close to destruction the entity is, may be replaced with higher fidelity later
    health*: Reduceable[int]
    # how many ticks before recovering a point of health
    healthRecoveryTime*: Option[Ticks]
    # when this entity was created in game ticks, used to calculate its age
    createdAt*: Ticks

  Creature* = object
    # how much energy the creature has for performing difficult actons
    stamina*: Reduceable[int]
    # how many ticks before recovering a point of stamina
    staminaRecoveryTime*: Option[Ticks]
    # how much hydration/water the creature has
    hydration*: Reduceable[int]
    # how many ticks before losing a point of hydration
    hydrationLossTime*: Option[Ticks]
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


  ResourceSource* = object
    # resources that can be gathered from this entity
    resources*: seq[ResourceYield]


  LightSource* = object
    # how many tiles out the light will travel if uninterrupted
    brightness*: int


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

  PlantKind* = object
    health*: DiceExpression
    healthRecoveryTime*: Option[Ticks]
    # images for each of the different stages of growth
    imagesByGrowthStage*: Table[Taxon, seq[ImageLike]]
    # stages of growth this plant goes through and at what ages. Expressed in terms of total age in
    # ticks to reach each, not in terms of the delta between them
    growthStages*: Table[Taxon, Ticks]
    # resource yields with each subsequent stage of growth
    resourcesByGrowthStage*: Table[Taxon, seq[ResourceYield]]

defineSimpleReadFromConfig(PlantKind)

defineSimpleLibrary[PlantKind]("survival/game/plant_kinds.sml", "PlantKinds")


defineReflection(Player)
defineReflection(Creature)
defineReflection(LightSource)
defineReflection(ResourceSource)
defineReflection(Plant)
defineReflection(Physical)

when isMainModule:
  let lib = library(PlantKind)
  let oak = lib[taxon("PlantKinds", "OakTree")]

  echo oak