import engines
import worlds
import arxmath
import entities
import events
import game/library
import prelude
import events
import core/metrics
import noto
import glm
import game/grids
import vn/game/logic


type
  BeltComponent* = ref object of LiveGameComponent


proc beltComponent*() : BeltComponent =
  result = new BeltComponent

method update(g: BeltComponent, world: LiveWorld) =
  discard

proc advanceBelts(g: BeltComponent, world: LiveWorld) =
  for region in world[Regions].regions:
    let reg = region[Region]
    let bd = region[BeltData]

    for bg in bd.beltGroups:
      for segment in bg.segments:
        var v = reg.grid[segment]
        assert(v.kind == VoxelKind.Belt)
        let curObj = reg.objects[segment]
        if curObj != 0:
          let startProgress = v.progress
          v.progress = min(v.progress + v.speed, 180)
          let toPos = segment + cardinalVector3D(v.beltDir)
          var toV = reg.grid[toPos]
          let toObj = reg.objects[toPos]

          # if toObj != 0 and toV.kind == VoxelKind.Belt and toV.beltDir != v.beltDir:
          #   v.progress = startProgress

          if v.progress >= 180:
            case toV.kind:
              of VoxelKind.Belt:
                if toObj == 0:
                  reg.objects[toPos] = curObj
                  reg.objects[segment] = 0
                  v.progress = 0
                  toV.progress = 0
                  reg.grid[toPos] = toV
              else:
                discard

          reg.grid[segment] = v





proc beltAdded(g: BeltComponent, world: LiveWorld, region: Entity, position: Vec3i, v: Voxel) =
  assert(v.kind == VoxelKind.Belt)

  let reg = region[Region]
  let bd = region[BeltData]
  let destPos = position + cardinalVector3D(v.beltDir)
  let destV = reg.grid[destPos]

  var destinationBeltIndex = -1
  if destV.kind == VoxelKind.Belt:
    destinationBeltIndex = beltGroupIndexContaining(bd, destPos)

  var sourceBeltGroups: seq[int]
  for dir in Cardinals2D:
    if dir != v.beltDir:
      let srcPos = position + vec3i(cardinalVector(dir), 0)
      let srcV = reg.grid[srcPos]
      if srcV.kind == VoxelKind.Belt and srcV.beltDir == dir.opposite:
        let beltGroup = beltGroupIndexContaining(bd, srcPos)
        if beltGroup != -1 and beltGroup != destinationBeltIndex and not sourceBeltGroups.contains(beltGroup):
          sourceBeltGroups.add(beltGroup)

  # info &"Joining destination belt group {destinationBeltIndex}, src belt groups {sourceBeltGroups}"

  if destinationBeltIndex == -1:
    if sourceBeltGroups.len == 0:
      destinationBeltIndex = createBeltGroup(bd)
      bd.beltGroups[destinationBeltIndex].segments.add(position)
    else:
      bd.beltGroups[sourceBeltGroups[0]].segments.add(position)
      if sourceBeltGroups.len > 1:
        mergeBeltGroups(bd, sourceBeltGroups)
  else:
    bd.beltGroups[destinationBeltIndex].segments.add(position)
    if sourceBeltGroups.len > 0:
      var allGroups = sourceBeltGroups
      allGroups.add(destinationBeltIndex)
      mergeBeltGroups(bd, allGroups)

  # info &"BD: {bd[]}"

proc beltRemoved(g: BeltComponent, world: LiveWorld, region: Entity, position: Vec3i, v: Voxel) =
  let reg = region[Region]
  let bd = region[BeltData]

  let bgi = beltGroupIndexContaining(bd, position)
  bd.beltGroups[bgi].segments.deleteValue(position)
  if bd.beltGroups[bgi].segments.isEmpty:
    bd.beltGroups.del(bgi)


method initialize(g: BeltComponent, world: LiveWorld) =
  g.name = "BeltComponent"

  for region in world[Regions].regions:
    let reg = region[Region]
    for v in reg.grid.iter:
      if v.value.kind == VoxelKind.Belt:
        beltAdded(g, world, region, vec3i(v.x,v.y,v.z), v.value)

method onEvent(g: BeltComponent, world: LiveWorld, event: Event) =
  matcher(event):
    extract(GameTickEvent, tick):
      advanceBelts(g, world)
    extract(VoxelChangedEvent, position, oldValue, newValue, region):
      if oldValue.kind == VoxelKind.Belt and newValue.kind != VoxelKind.Belt:
        beltRemoved(g, world, region, position, newValue)
      elif oldValue.kind != VoxelKind.Belt and newValue.kind == VoxelKind.Belt:
        beltAdded(g, world, region, position, newValue)