import game/randomness
import worlds
import game/library
import glm
import graphics/images
import core
import tables
import config
import resources
import sets
import sequtils
import patty
import arxregex
import prelude
import strutils
import graphics/color
import game/flags
import game/grids

type
  VoxelKind* {.size: sizeof(uint8).} = enum
    Empty
    Floor
    Belt
    Pipe
    Entity



  Voxel* = object
    gridScale*: uint8
    case kind*: VoxelKind
    of VoxelKind.Belt:
      beltDir*:   Cardinals2D
      speed*:     uint8
      progress*:  uint8
    of VoxelKind.Pipe:
      pipeDir*:   Cardinals2D
      fluid*:     uint8
      level*:     uint8
    of VoxelKind.Entity:
      entityId*:  uint16
      origin*: bool
    of VoxelKind.Empty, VoxelKind.Floor:
      discard



  ObjectHolder* = object
    kindIndex*: uint16

  Region* = object
    grid*: SparseGrid3D[4, Voxel]
    objects*: SparseGrid3D[4, uint16]

  Regions* = object
    regions*: seq[Entity]

  ObjectKind* = object
    image*: ImageRef

  TimeData* = object
    ticks*: int

  BeltGroup* = object
    segments* : seq[Vec3i]

  BeltData* = object
    beltGroups*: seq[BeltGroup]

  MachineIngredient* = object
    label*: Option[Taxon]
    objectKind*: uint16

  Machine* = object
    region*: Entity
    position*: Vec3i
    kind*: LibraryTaxon
    progress*: int
    activeRecipe*: Option[LibraryTaxon]
    rotation*: int
    ingredients*: seq[MachineIngredient]
    pendingOutputs*: seq[MachineIngredient]
    outputIncrementor*: int

  PlacementRestriction* = enum
    FacingOutside
    FacingForward

  IsoDirection* {.pure.} = enum
    Forward
    Right
    Back
    Left
    Up
    Down

  MachineInterface* = object
    input*: bool
    direction*: IsoDirection
    relativePosition*: Vec3i
    size*: Vec2i
    label*: Option[Taxon]

  MachineKind* = object
    placementRestrictions*: seq[PlacementRestriction]
    fixedRecipe*: Option[Taxon]
    image*: ImageLike
    size*: Vec3i
    speed*: int
    inputs*: seq[MachineInterface]
    outputs*: seq[MachineInterface]
    flags*: ref Flags

  RecipeOutput* = object
    label*: Option[Taxon]
    objectKind*: uint16
    quantity*: int
    chance*: Option[float]

  RecipeInput* = object
    label*: Option[Taxon]
    objectKind*: uint16
    quantity*: int

  Recipe* = object
    inputs*: seq[RecipeInput]
    outputs*: seq[RecipeOutput]
    duration*: int
    madeIn*: Taxon




defineReflection(TimeData)
defineReflection(Region)
defineReflection(Regions)
defineReflection(BeltData)
defineReflection(Machine)


proc readFromConfig*(cv: ConfigValue, v: var PlacementRestriction) =
  v = parseEnum[PlacementRestriction](cv.asStr)

proc readFromConfig*(cv: ConfigValue, v: var IsoDirection) =
  v = parseEnum[IsoDirection](cv.asStr)

defineSimpleReadFromConfig(MachineInterface)
defineSimpleReadFromConfig(ObjectKind)

defineSimpleLibrary[ObjectKind]("vn/objects/object_kinds.sml", "Objects")

proc readFromConfig*(cv: ConfigValue, v: var RecipeInput) =
  v.objectKind = library(ObjectKind).id(cv["objectKind"].readInto(Taxon)).uint32.uint16
  cv["quantity"].readIntoOrElse(v.quantity, 1)
  cv["label"].readInto(v.label)

proc readFromConfig*(cv: ConfigValue, v: var RecipeOutput) =
  v.objectKind = library(ObjectKind).id(cv["objectKind"].readInto(Taxon)).uint32.uint16
  cv["quantity"].readIntoOrElse(v.quantity, 1)
  cv["chance"].readInto(v.chance)
  cv["label"].readInto(v.label)

defineSimpleReadFromConfig(Recipe)

proc readFromConfig*(cv: ConfigValue, v: var MachineKind) =
  cv["placementRestrictions"].readInto(v.placementRestrictions)
  cv["fixedRecipe"].readInto(v.fixedRecipe)
  cv["image"].readInto(v.image)
  cv["size"].readInto(v.size)
  cv["speed"].readIntoOrElse(v.speed, 1)
  cv["inputs"].readInto(v.inputs)
  cv["outputs"].readInto(v.outputs)
  v.flags = new Flags
  cv["flags"].readInto(v.flags[])

defineSimpleLibrary[MachineKind]("vn/machines/machine_kinds.sml", "Machines")
defineSimpleLibrary[Recipe]("vn/recipes.sml", "Recipes")

proc machineKind*(t: Taxon) : ref MachineKind = library(MachineKind)[t]
proc machineKind*(t: LibraryTaxon) : ref MachineKind = library(MachineKind)[t]
proc objectKind*(t: Taxon) : ref ObjectKind = library(ObjectKind)[t]
proc recipeKind*(t: Taxon) : ref Recipe = library(Recipe)[t]

const IsoDirVectors = [vec3i(1,0,0), vec3i(0,-1,0), vec3i(-1,0,0), vec3i(0,1,0), vec3i(0,0,1), vec3i(0,0,-1)]
proc vector*(iso: IsoDirection) : Vec3i = IsoDirVectors[iso.ord]

proc `==`*(a,b: Voxel) : bool =
  if a.kind != b.kind:
    false
  else:
    case a.kind:
    of VoxelKind.Belt:
      a.beltDir == b.beltDir and a.speed == b.speed and a.progress == b.progress
    of VoxelKind.Pipe:
      a.pipeDir == b.pipeDir and a.fluid == b.fluid and a.level == b.level
    of VoxelKind.Entity:
      a.entityId == b.entityId
    of VoxelKind.Empty, VoxelKind.Floor:
      true

proc initRegion(region : ref Region) =
  region.grid = new SparseGrid3D[4, Voxel]
  region.objects = new SparseGrid3D[4, uint16]

proc createRegion*(world: LiveWorld): Entity =
  result = world.createEntity()
  result.attachData(Region)
  initRegion(result[Region])
  result.attachData(BeltData)

proc region*(world: LiveWorld): ref Region =
  let regionEnt = world[Regions].regions[0]
  regionEnt[Region]


proc createBeltGroup*(bd: ref BeltData): int =
  bd.beltGroups.add(BeltGroup())
  bd.beltGroups.len - 1

proc rotateCW*(iso: IsoDirection, by: int) : IsoDirection =
  IsoDirection((iso.ord + by) mod 4)

proc rotateCCW*(iso: IsoDirection, by: int) : IsoDirection =
  IsoDirection((iso.ord + 4 - (by mod 4)) mod 4)
