import entities
import game/grids
import game/library
import glm
import worlds
import sets
import algorithm
import prelude
import noto
import core

import events

proc isAlignedToGrid*(i: int, scale: int): bool =
  i mod scale == 0

proc isAlignedToGrid*(x,y,z: int, scale: int): bool =
  (x mod scale == 0) and
  (y mod scale == 0) and
  (z mod scale == 0)

proc isAlignedToGrid*(i: int, scale: uint8): bool =
  i mod scale.int == 0

proc isAlignedToGrid*(x,y,z: int, scale: uint8): bool =
  let iscale = scale.int
  (x mod iscale == 0) and
  (y mod iscale == 0) and
  (z mod iscale == 0)

proc alignToGrid*(i: int, scale: int) : int =
  ((i - (i < 0).ord * (scale-1)) div scale) * scale

proc alignToGrid*(i: int, scale: uint8) : int =
  let iscale = scale.int
  ((i - (i < 0).ord * (iscale-1)) div iscale) * iscale

proc alignToGrid*(i: int32, scale: int) : int32 =
  (((i - (i < 0).ord * (scale-1)) div scale) * scale).int32

proc alignToGrid*(v: Vec3i, scale: int): Vec3i =
  vec3i( alignToGrid(v.x, scale), alignToGrid(v.y, scale), alignToGrid(v.z, scale) )


proc subSetVoxel*(world: LiveWorld, region: Entity, reg: ref Region, x,y,z: int, v: Voxel) =
  let oldV = reg.grid[x,y,z]
  if oldV != v:
    reg.grid[x,y,z] = v
    world.addEvent(VoxelChangedEvent(region: region, position: vec3i(x,y,z), oldValue: oldV, newValue: v))

proc setVoxel*(world: LiveWorld, region: Entity, reg: ref Region, x,y,z: int, v: Voxel) =
  if v.gridScale < 1:
    var effV = v
    effV.gridScale = 1
    subSetVoxel(world, region, reg, x,y,z, effV)
  elif v.gridScale == 1:
    subSetVoxel(world, region, reg, x,y,z, v)
  else:
    let iscale = v.gridScale.int
    let vx = alignToGrid(x, iscale)
    let vy = alignToGrid(y, iscale)
    let vz = alignToGrid(z, iscale)
    for dx in 0 ..< iscale:
      for dy in 0 ..< iscale:
        for dz in 0 ..< 1:
          reg.grid[vx + dx, vy + dy, vz + dz] = v
          subSetVoxel(world, region, reg, vx + dx,vy + dy,vz + dz, v)

proc setObject*(world: LiveWorld, region: Entity, reg: ref Region, x,y,z: int, obj: Taxon) =
  let objLib = library(ObjectKind)
  let libId = objLib.id(obj)
  let libId16 = libId.uint32.uint16
  reg.objects[x,y,z] = Object(kind: libId16)

proc `[]`*(lib: Library[ObjectKind], o: uint16) : ref ObjectKind =
  lib[o.uint32.LibraryID]

proc beltGroupIndexContaining*(bd: ref BeltData, v: Vec3i) : int =
  for i in 0 ..< bd.beltGroups.len:
    if bd.beltGroups[i].segments.contains(v):
      return i
  -1

proc matches*(om: ObjectMatcher, o: Object) : bool =
  om.kind == o.kind and om.pressure.contains(o.pressure.int) and om.temperature.contains(o.temperature.int)

proc currentIngredientCount*(machine: ref Machine, inputIndex: int) : int =
  machine.ingredients[inputIndex].len

proc hasAllIngredients*(machine: ref Machine, recipe: ref Recipe) : bool =
  for inputIndex in 0 ..< recipe.inputs.len:
    let input = recipe.inputs[inputIndex]
    if currentIngredientCount(machine,inputIndex) < input.quantity:
      return false
  # for input in recipe.inputs:
  #   var matchingCount = 0
  #   for ingredient in machine.ingredients:
  #     if input.objectKind.matches(ingredient.objectKind) and ingredient.label == input.label:
  #       matchingCount += 1
  #   if matchingCount < input.quantity:
  #     return false
  true



proc hasSpaceForIngredient*(machine: ref Machine, iface: MachineInterface, obj: Object): bool =
  if machine.activeRecipe.isSome:
    let inputs = library(Recipe)[machine.activeRecipe.get].inputs
    for inputIndex in 0 ..< inputs.len:
      let recipeInput = inputs[inputIndex]
      if recipeInput.label == iface.label and recipeInput.objectKind.matches(obj):
        if currentIngredientCount(machine, inputIndex) < recipeInput.quantity * 2:
          return true


  false

# proc topographicSort*(bg: var BeltGroup) =
#   var sorted: seq[Vec3i]
#
#   var unprocessed: HashSet[Vec3i]
#   for s in bg.segments:
#     unprocessed.add(s)
#
#   var processed: HashSet[Vec3i]
#
#   for v in bg.segments:
#     if unprocessed.contains(v)


proc mergeBeltGroups*(bd: ref BeltData, groups: seq[int]) =
  var newBeltGroup: BeltGroup
  for gi in groups:
    newBeltGroup.segments.add( bd.beltGroups[gi].segments )

  bd.beltGroups.add(newBeltGroup)
  # reverse sort so we delete the later ones last
  let sortedGroups = groups.sortedByIt(it * -1)
  for i in 0 ..< sortedGroups.len:
    let gi = sortedGroups[i]
    bd.beltGroups.del(gi)


proc targetPositions*(mach: ref Machine, mi: MachineInterface) : seq[Vec3i] =
  let mk = machineKind(mach.kind)
  let dir = rotateCW(mi.direction, mach.rotation)
  let basePoint = mach.position + max(vector(dir),0) * mk.size + vector(dir)
  let ortho = case dir:
    of IsoDirection.Forward, IsoDirection.Back:
      vec3i(0,1,0)
    of IsoDirection.Left, IsoDirection.Right:
      vec3i(1,0,0)
    else:
      err &"up/down machine interfaces not yet implemented {dir}"
      vec3i(1,0,0)

  let up = vec3i(0,0,1)

  for dortho in 0 ..< mi.size.x:
    for dup in 0 ..< mi.size.y:
      result.add(basePoint + ortho * dortho + up * dup)

proc createMachine*(world: LiveWorld, machineKind: Taxon): Entity =
  let machLib = library(MachineKind)
  let recipeLib = library(Recipe)
  let mk = machLib[machineKind]
  result = world.createEntity()
  result.attachData(Machine(kind: machLib.libTaxon(machineKind)))
  if mk.fixedRecipe.isSome:
    result[Machine].activeRecipe = some(recipeLib.libTaxon(mk.fixedRecipe.get))


proc placeMachine*(world: LiveWorld, region: Entity, machine: Entity, position: Vec3i) =
  let reg = region[Region]
  let mach = machine[Machine]
  mach.region = region
  mach.position = position
  let mk = machineKind(mach.kind)

  let entId = machine.id.uint32.uint16
  for dx in 0 ..< mk.size.x:
    for dy in 0 ..< mk.size.y:
      for dz in 0 ..< mk.size.z:
        subSetVoxel(world, region, reg, position.x + dx, position.y + dy, position.z + dz,
                      Voxel(kind: VoxelKind.Entity, entityId: entId, origin: vec3i8(-dx,-dy,-dz)))