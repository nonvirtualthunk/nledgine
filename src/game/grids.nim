import noto
import glm
import options

type
  FiniteGrid2D*[W: static[int], H: static[int], T] = object
    values: array[W*H, T]
    sentinel: T

  FiniteGrid3D*[W: static[int], H: static[int], D: static[int], T] = object
    values: array[W*H*D, T]
    sentinel: T

  SparseGridChunk[Po2: static[int], T] = ref object
    position*: Vec3i
    values: array[1 shl (Po2*3), T]

  # Po2 represents the power of two size of the individual chunks, so 6 would mean chunks 64 on a side
  SparseGrid3D*[Po2: static[int], T] = ref object
    chunks: seq[SparseGridChunk[Po2, T]]
    minPos: Vec3i
    maxPos: Vec3i
    dims: Vec3i
    chunkDims: Vec3i
    chunkDimsYZ: int

  VoxelValue*[T] = object
    x*,y*,z*: int
    value*: T

  VoxelTurtle*[Po2: static[int], T] = object
    grid: SparseGrid3D[Po2,T]
    chunk: Option[SparseGridChunk[Po2,T]]
    x,y,z*: int
    cx,cy,cz: int
    i: int
    value*: T


proc `[]`*[W: static[int], H: static[int], T](g: FiniteGrid2D[W, H, T], x: int, y: int): T =
  if x < 0 or y < 0 or x >= W or y >= H:
    g.sentinel
  else:
    g.values[x*H+y]

proc `[]`*[W: static[int], H: static[int], T](g: ref FiniteGrid2D[W, H, T], x: int, y: int): T =
  if x < 0 or y < 0 or x >= W or y >= H:
    g.sentinel
  else:
    g.values[x*H+y]

proc raw*[W: static[int], H: static[int], T](g: ref FiniteGrid2D[W, H, T], x: int, y: int): var T =
  if x < 0 or y < 0 or x >= W or y >= H: raise new AccessViolationError
  g.values[x*H+y]

proc getPtr*[W: static[int], H: static[int], T](g: ref FiniteGrid2D[W, H, T], x: int, y: int): ptr T =
  g.values[x*H+y].addr


proc `[]`*[W: static[int], H: static[int], T](g: var FiniteGrid2D[W, H, T], x: int, y: int): var T =
   g.values[x*H+y]


proc `[]=`*[W: static[int], H: static[int], T](g: var FiniteGrid2D[W, H, T], x: int, y: int, t: T) =
  if x < 0 or y < 0 or x >= W or y >= H:
    let w = W
    let h = H

    warn &"attempted to update finite grid out of bounds, ({x}, {y}) is not within [0,0] -> [{w - 1},{h - 1}]"
  else:
    g.values[x*H+y] = t

proc `[]=`*[W: static[int], H: static[int], T](g: ref FiniteGrid2D[W, H, T], x: int, y: int, t: T) =
  if x < 0 or y < 0 or x >= W or y >= H:
    let w = W
    let h = H

    warn &"attempted to update finite grid out of bounds, ({x}, {y}) is not within [0,0] -> [{w - 1},{h - 1}]"
  else:
    g.values[x*H+y] = t

proc `[]`*[W: static[int], H: static[int], D: static[int], I: int, T](g: FiniteGrid3D[W, H, D, T], x: I, y: I, z: I): T =
  if x < 0 or y < 0 or z < 0 or x >= W or y >= H or z >= D:
    g.sentinel
  else:
    g.values[x*H*D+y*D+z]

proc `[]`*[W: static[int], H: static[int], D: static[int], I: int, T](g: var FiniteGrid3D[W, H, D, T], x: I, y: I, z: I): var T =
   g.values[x*H*D+y*D+z]

proc `[]`*[W: static[int], H: static[int], D: static[int], I: int, T](g: ref FiniteGrid3D[W, H, D, T], x: I, y: I, z: I): var T =
   g.values[x*H*D+y*D+z]

proc getPtr*[W: static[int], H: static[int], D: static[int], I: int, T](g: var FiniteGrid3D[W, H, D, T], x: I, y: I, z: I): ptr T =
   g.values[x*H*D+y*D+z].addr

proc getPtr*[W: static[int], H: static[int], D: static[int], I: int, T](g: ref FiniteGrid3D[W, H, D, T], x: I, y: I, z: I): ptr T =
   g.values[x*H*D+y*D+z].addr


proc `[]=`*[W: static[int], H: static[int], D: static[int], I: int, T](g: var FiniteGrid3D[W, H, D, T], x: I, y: I, z: I, t: T) =
  if x < 0 or y < 0 or x >= W or y >= H or z < 0 or z >= D:
    let w = W
    let h = H
    let d = D
    warn &"attempted to update finite grid out of bounds, ({x}, {y}, {z}) is not within [0,0] -> [{w - 1},{h - 1},{d - 1}]"
  else:
    g.values[x*H*D+y*D+z] = t

proc `[]=`*[W: static[int], H: static[int], D: static[int], I: int, T](g: ref FiniteGrid3D[W, H, D, T], x: I, y: I, z: I, t: T) =
  if x < 0 or y < 0 or x >= W or y >= H or z < 0 or z >= D:
    let w = W
    let h = H
    let d = D
    warn &"attempted to update finite grid out of bounds, ({x}, {y}, {z}) is not within [0,0] -> [{w - 1},{h - 1},{d - 1}]"
  else:
    g.values[x*H*D+y*D+z] = t

proc clear*[W: static[int], H: static[int], D: static[int], T](g: ref FiniteGrid3D[W,H,D,T]) =
  zeroMem(g.values[0].addr, W*H*D*sizeof(T))

proc clear*[W: static[int], H: static[int], T](g: ref FiniteGrid2D[W,H,T]) =
  zeroMem(g.values[0].addr, W*H*sizeof(T))

proc `[]`*[Po2: static[int], T](sg: SparseGridChunk[Po2,T], x,y,z: int) : T =
  let i = (x shl (Po2+Po2)) + (y shl Po2) + z
  sg.values[i]

proc `[]=`*[Po2: static[int], T](sg: SparseGridChunk[Po2,T], x,y,z: int, v: T) =
  # echo &"Chunk []= {x},{y},{z}"
  # flushFile(stdout)
  let i = (x shl (Po2+Po2)) + (y shl Po2) + z
  sg.values[i] = v



proc alignToChunk*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int): Vec3i =
  vec3i(((x shr Po2) shl Po2).int32, ((y shr Po2) shl Po2).int32, ((z shr Po2) shl Po2).int32)


proc createChunk*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int) : SparseGridChunk[Po2,T] {.discardable.} =
  # echo &"createChunk {x},{y},{z}"
  # # flushFile(stdout)

  let cx = (x - sg.minPos.x) shr Po2
  let cy = (y - sg.minPos.y) shr Po2
  let cz = (z - sg.minPos.z) shr Po2
  let chunk = SparseGridChunk[Po2,T](position : alignToChunk(sg, x,y,z))
  sg.chunks[cx * sg.chunkDimsYZ + cy * sg.chunkDims.z + cz] = chunk
  chunk

proc resizeToInclude*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int) =
  # echo &"resize to include {x},{y},{z}"
  # flushFile(stdout)

  let pos = alignToChunk(sg, x,y,z)
  var newChunks : seq[SparseGridChunk[Po2, T]]
  let startCenter = vec3i((sg.minPos.x + sg.maxPos.x) div 2, (sg.minPos.y + sg.maxPos.y) div 2, (sg.minPos.z + sg.maxPos.z) div 2)
  var newMin = sg.minPos
  var newMax = sg.maxPos
  if newMin == newMax:
    newMin = pos - vec3i(1 shl (Po2+1), 1 shl (Po2+1), 1 shl (Po2+1))
    newMax = pos + vec3i(1 shl (Po2+1), 1 shl (Po2+1), 1 shl (Po2+1))

  for axis in 0 ..< 3:
    while newMin[axis] >= pos[axis]:
      newMin[axis] -= max(sg.dims[axis] div 2, 1 shl (Po2+1))
    while newMax[axis] <= pos[axis]:
      newMax[axis] += max(sg.dims[axis] div 2, 1 shl (Po2+1))

  newMin = alignToChunk(sg, newMin.x, newMin.y, newMin.z)
  newMax = alignToChunk(sg, newMax.x, newMax.y, newMax.z)
  # echo &"Resized to: {newMin} -> {newMax}"
  let newDim = newMax - newMin
  let newChunkDim = vec3i(newDim.x shr Po2, newDim.y shr Po2, newDim.z shr Po2) + vec3i(1,1,1)
  newChunks.setLen(newChunkDim.x * newChunkDim.y * newChunkDim.z)

  for oldChunk in sg.chunks:
    if not oldChunk.isNil:
      let cx = (oldChunk.position.x - newMin.x) shr Po2
      let cy = (oldChunk.position.y - newMin.y) shr Po2
      let cz = (oldChunk.position.z - newMin.z) shr Po2

      let ci = cx * newChunkDim.y * newChunkDim.z + cy * newChunkDim.z + cz
      newChunks[ci] = oldChunk

  sg.chunks = newChunks
  sg.dims = newDim
  sg.minPos = newMin
  sg.maxPos = vec3i(newMax.x + (1 shl Po2) - 1, newMax.y + (1 shl Po2) - 1, newMax.z + (1 shl Po2) - 1)
  sg.chunkDims = newChunkDim
  sg.chunkDimsYZ = newChunkDim.y * newChunkDim.z
  createChunk(sg, x,y,z)


proc `[]`*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int): T =
  let cx = (x - sg.minPos.x) shr Po2
  let cy = (y - sg.minPos.y) shr Po2
  let cz = (z - sg.minPos.z) shr Po2

  if cx >= 0 and cy >= 0 and cz >= 0 and cx < sg.chunkDims.x and cy < sg.chunkDims.y and cz < sg.chunkDims.z:
    let ci = cx * sg.chunkDimsYZ + cy * sg.chunkDims.z + cz
    let chunk = sg.chunks[ci]
    if chunk.isNil:
      default(T)
    else:
      chunk[x - chunk.position.x, y - chunk.position.y, z - chunk.position.z]
  else:
    default(T)

proc `[]`*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], v: Vec3i): T = sg[v.x, v.y, v.z]

proc `[]=`*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int, v : T) =
  # echo &"[]= {x},{y},{z}"
  # flushFile(stdout)

  if x < sg.minPos.x or y < sg.minPos.y or z < sg.minPos.z or x > sg.maxPos.x or y > sg.maxPos.y or z > sg.maxPos.z or sg.maxPos.x == sg.minPos.x:
    resizeToInclude(sg, x, y, z)

  let cx = (x - sg.minPos.x) shr Po2
  let cy = (y - sg.minPos.y) shr Po2
  let cz = (z - sg.minPos.z) shr Po2

  let ci = cx * sg.chunkDimsYZ + cy * sg.chunkDims.z + cz
  # echo &"ci: {ci}"
  if ci > sg.chunks.len:
    echo &"Out of bounds ci: {x},{y},{z}, {sg.chunkDims}, {sg.minPos}, {sg.maxPos}, {ci}, {sg.chunks.len}"
    return
  var chunk = sg.chunks[ci]
  if chunk.isNil:
    chunk = SparseGridChunk[Po2,T](position: alignToChunk(sg,x,y,z))
    # echo &"Creating chunk from setter {chunk.position}"
    sg.chunks[ci] = chunk
  chunk[x - chunk.position.x, y - chunk.position.y, z - chunk.position.z] = v


proc `[]=`*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], v: Vec3i, t: T) = sg[v.x, v.y, v.z] = t

proc chunk*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int): Option[SparseGridChunk[Po2,T]] =
  let cx = (x - sg.minPos.x) shr Po2
  let cy = (y - sg.minPos.y) shr Po2
  let cz = (z - sg.minPos.z) shr Po2

  if cx >= 0 and cy >= 0 and cz >= 0 and cx < sg.chunkDims.x and cy < sg.chunkDims.y and cz < sg.chunkDims.z:
    let ci = cx * sg.chunkDimsYZ + cy * sg.chunkDims.z + cz
    let chunk = sg.chunks[ci]
    if chunk.isNil:
      none(SparseGridChunk[Po2,T])
    else:
      some(chunk)
  else:
    none(SparseGridChunk[Po2,T])

proc getOrCreateChunk*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int): SparseGridChunk[Po2,T] =
  let co = chunk(sg, x,y,z)
  if co.isSome:
    co.get
  else:
    createChunk(sg, x,y,z)


iterator chunkIter*[Po2: static[int], T](sg: SparseGrid3D[Po2,T]): SparseGridChunk[Po2,T] =
  for chunk in sg.chunks:
    if not chunk.isNil:
      yield chunk

iterator chunkIterReversed*[Po2: static[int], T](sg: SparseGrid3D[Po2,T]): SparseGridChunk[Po2,T] =
  for chunkIndex in countdown(sg.chunks.len - 1,0):
    let chunk = sg.chunks[chunkIndex]
    if not chunk.isNil:
      yield chunk


iterator iter*[Po2: static[int], T](sg: SparseGrid3D[Po2,T]): VoxelValue[T] =
  const dim = 1 shl Po2
  for chunk in sg.chunks:
    if not chunk.isNil:
      var voxel = VoxelValue[T](x: chunk.position.x, y: chunk.position.y, z: chunk.position.z)
      let cpx = chunk.position.x
      let cpy = chunk.position.y
      let cpz = chunk.position.z
      var i = 0
      for x in 0 ..< dim:
        voxel.x = cpx + x
        for y in 0 ..< dim:
          voxel.y = cpy + y
          for z in 0 ..< dim:
            voxel.z = cpz + z
            voxel.value = chunk.values[i]
            yield voxel
            i.inc

proc dim*[Po2: static[int], T](sg: SparseGridChunk[Po2,T]): int = 1 shl Po2

iterator iter*[Po2: static[int], T](sg: SparseGridChunk[Po2,T]): VoxelValue[T] =
  const dim = 1 shl Po2
  var voxel = VoxelValue[T](x: chunk.position.x, y: chunk.position.y, z: chunk.position.z)
  let cpx = chunk.position.x
  let cpy = chunk.position.y
  let cpz = chunk.position.z
  var i = 0
  for x in 0 ..< dim:
    voxel.x = cpx + x
    for y in 0 ..< dim:
      voxel.y = cpy + y
      for z in 0 ..< dim:
        voxel.z = cpz + z
        voxel.value = chunk.values[i]
        yield voxel
        i.inc



proc turtle*[Po2: static[int], T](sg: SparseGrid3D[Po2,T], x,y,z: int): VoxelTurtle[Po2, T] =
  let c = chunk(sg,x,y,z)
  result = VoxelTurtle[Po2,T](x:x,y:y,z:z,
    grid:sg,
    chunk:c,
    cx: x shr Po2, cy: y shr Po2, cz: z shr Po2)
  if c.isSome:
    let rx = x - c.get.position.x
    let ry = y - c.get.position.y
    let rz = z - c.get.position.z
    result.i = (rx shl (Po2+Po2)) + (ry shl Po2) + rz
    result.value = c.get()[rx, ry, rz]

proc move*[Po2: static[int], T](vt: var VoxelTurtle[Po2,T], dx,dy,dz: int) =
  vt.x += dx
  vt.y += dy
  vt.z += dz
  let cxp = vt.x shr Po2
  let cyp = vt.y shr Po2
  let czp = vt.z shr Po2
  if cxp != vt.cx or cyp != vt.cy or czp != vt.cz:
    vt.chunk = chunk(vt.grid, vt.x, vt.y, vt.z)
    vt.cx = cxp
    vt.cy = cyp
    vt.cz = czp
    if vt.chunk.isSome:
      vt.i = ((vt.x - vt.chunk.get.position.x) shl (Po2+Po2)) + ((vt.y - vt.chunk.get.position.y) shl Po2) + (vt.z - vt.chunk.get.position.z)
    else:
      vt.i = 0
  else:
    vt.i += (dx shl (Po2+Po2)) + (dy shl Po2) + dz

  if vt.chunk.isSome:
    vt.value = vt.chunk.get().values[vt.i]
  else:
    vt.value = default(T)


when isMainModule:
  proc modifyInPlace(v : var int) =
    v = 9

  var grid = FiniteGrid2D[10, 10, array[4, int]]()
  assert grid[0, 0][2] == 0

  var grid3d = FiniteGrid3D[10, 10, 10, int]()
  assert grid3d[0, 0, 0] == 0
  grid3d[0, 0, 0] = 10
  assert grid3d[0, 0, 0] == 10

  modifyInPlace(grid3d[3,3,3])
  assert grid3d[3,3,3] == 9

  const po2 = 5
  let sg = SparseGrid3D[po2, int]()

  assert sg[0,0,0] == 0
  assert sg[1,0,0] == 0
  assert sg[1000,1000,1000] == 0

  sg[0,0,0] = 1
  sg[1,0,0] = 2
  sg[0,0,1] = 3
  assert sg[0,0,0] == 1
  assert sg[1,0,0] == 2
  assert sg[0,0,1] == 3

  const range = 75
  const rangez = 8

  import times,os

  let start = cpuTime()

  for x in -range ..< range:
    for y in -range ..< range:
      for z in -rangez ..< rangez:
        # echo &"{x},{y},{z}\n"
        # flushFile(stdout)
        sg[x,y,z] = x * 400 * 400 + y * 400 + z

        # for chunk in sg.chunks:
        #   if chunk != nil:
        #     echo &"\tChunk : {chunk.position}"

  let writeEnd = cpuTime()
  var assertCount = 0
  echo "Write time: ", (writeEnd - start)

  for x in -range ..< range:
    for y in -range ..< range:
      for z in -rangez ..< rangez:
        assert sg[x,y,z] == x * 400 * 400 + y * 400 + z
        assertCount.inc

  echo "Read time: ", (cpuTime() - writeEnd), " asserts: ", assertCount
  assertCount = 0
  let readEnd = cpuTime()


  let startP = alignToChunk(sg, -range, -range, -rangez)
  let endP = alignToChunk(sg, range, range, rangez)

  for x in countup(startP.x, endP.x, 1 shl po2):
    for y in countup(startP.y, endP.y, 1 shl po2):
      for z in countup(startP.z, endP.z, 1 shl po2):
        let co = chunk(sg, x,y,z)
        assert co.isSome
        let c = co.get
        for dx in 0 ..< (1 shl po2):
          for dy in 0 ..< (1 shl po2):
            for dz in 0 ..< (1 shl po2):
              let ax = x + dx
              let ay = y + dy
              let az = z + dz
              if ax >= -range and ay >= -range and az >= -rangez and ax < range and ay < range and az < rangez:
                assert c[dx,dy,dz] == ax * 400 * 400 + ay * 400 + az
                assertCount.inc

  echo "Read time by chunk: ", (cpuTime() - readEnd), " asserts: ", assertCount
  let readEnd2 = cpuTime()
  assertCount = 0


  for c in sg.chunkIter:
    let cx = c.position.x
    let cy = c.position.y
    let cz = c.position.z
    for dx in 0 ..< (1 shl po2):
      for dy in 0 ..< (1 shl po2):
        for dz in 0 ..< (1 shl po2):
          let ax = cx + dx
          let ay = cy + dy
          let az = cz + dz
          if ax >= -range and ay >= -range and az >= -rangez and ax < range and ay < range and az < rangez:
            assert c[dx,dy,dz] == ax * 400 * 400 + ay * 400 + az
            assertCount.inc

  echo "Read time by naive chunk iteration: ", (cpuTime() - readEnd2), " asserts: ", assertCount

  let readEnd3 = cpuTime()
  assertCount = 0

  for c in sg.iter:
    let ax = c.x
    let ay = c.y
    let az = c.z
    if ax >= -range and ay >= -range and az >= -rangez and ax < range and ay < range and az < rangez:
      assert c.value == ax * 400 * 400 + ay * 400 + az
      assertCount.inc

  echo "Read time by direct voxel iteration: ", (cpuTime() - readEnd3), " asserts: ", assertCount

  let readEnd4 = cpuTime()
  assertCount = 0

  var vt = sg.turtle(-range, -range, -rangez)
  for x in -range ..< range:
    for y in -range ..< range:
      for z in -rangez ..< rangez:
        let expected = x * 400 * 400 + y * 400 + z
        assert vt.value == x * 400 * 400 + y * 400 + z
        assertCount.inc
        vt.move(0,0,1)
      vt.move(0,1,-rangez - vt.z)
    vt.move(1,-range - vt.y, 0)

  echo "Read time by turtle iteration: ", (cpuTime() - readEnd4), " asserts: ", assertCount

