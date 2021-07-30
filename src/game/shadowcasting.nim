import game/grids
import prelude
import glm
import deques
import math
import graphics/images
import graphics/color
import arxmath
import noto


{.experimental.}

type
  ShadowGrid*[D: static[int]] = object
    grid: array[(D*2+1) * (D*2+1), uint8]


proc `[]`*[D: static[int]](g : ShadowGrid[D], vx: int, vy: int) : uint8 =
  g.grid[(vy+D) * (D*2+1) + (vx+D)]

proc `[]`*[D: static[int]](g : ref ShadowGrid[D], vx: int, vy: int) : uint8 =
  g.grid[(vy+D) * (D*2+1) + (vx+D)]

proc `[]=`*[D: static[int]](g : var ShadowGrid[D], vx: int, vy: int, s : uint8) =
  g.grid[(vy+D) * (D*2+1) + (vx+D)] = s

proc `[]=`*[D: static[int]](g : ref ShadowGrid[D], vx: int, vy: int, s : uint8) =
  g.grid[(vy+D) * (D*2+1) + (vx+D)] = s

# w - world coordinate
# o - origin
# s - sub-position within overal coordinate
# resolution - resolution of the shadowgrid
proc atWorldCoord*[D: static[int]](g: ref ShadowGrid[D], wx: int, wy: int, ox: int, oy: int, sx: int, sy: int, resolution: int) : uint8 =
  let dx = wx - ox
  let dy = wy - oy
  g[dx * resolution + sx, dy * resolution + sy]

func atWorldCoord*[D: static[int]](g: ShadowGrid[D], wx: int, wy: int, ox: int, oy: int, sx: int, sy: int, resolution: int) : uint8 =
  let dx = wx - ox
  let dy = wy - oy
  g[dx * resolution + sx, dy * resolution + sy]

proc reset*[D: static[int]](g : var ShadowGrid[D]) =
  zeroMem(g.grid[0].addr, (D*2+1) * (D*2+1))
  # discard
  # for i in 0 ..< ((D*2+1)*(D*2+1)):
  #   g.grid[i] = 0.uint8

proc reset*[D: static[int]](g : ref ShadowGrid[D]) =
  if g != nil:
    zeroMem(g.grid[0].addr, (D*2+1) * (D*2+1))

func radius*[D: static[int]](g : var ShadowGrid[D]) : int = D

func shift*[D: static[int]](baseGrid: ShadowGrid[D], targetGrid: var ShadowGrid[D], dx: int, dy: int) =
  if dy > 0:
    for y in countdown(D,-D):
      for x in -D .. D:
        if y >= -D + dy:
          targetGrid[x,y] = baseGrid[x,y-dy]
        else:
          targetGrid[x,y] = 0
  elif dy < 0:
    for y in -D .. D:
      for x in -D .. D:
        if y <= D + dy:
          targetGrid[x,y] = baseGrid[x,y-dy]
        else:
          targetGrid[x,y] = 0
  if dx > 0:
    for y in -D .. D:
      moveMem(targetGrid.grid[(y+D) * (D*2+1) + dx].addr, baseGrid.grid[(y+D) * (D*2+1)].unsafeAddr, (D*2+1) - dx.abs)
  elif dx < 0:
    for y in -D .. D:
      moveMem(targetGrid.grid[(y+D) * (D*2+1)].addr, baseGrid.grid[(y+D) * (D*2+1) - dx].unsafeAddr, (D*2+1) - dx.abs)




iterator diamondIter*(radius : int32) : Vec2i =
  var v : Vec2i
  for r in 0 ..< radius:
    v.x = r
    v.y = 0
    yield v
    for i in 0 ..< r:
      v.x -= 1
      v.y += 1
      yield v
    for i in 0 ..< r:
      v.x -= 1
      v.y -= 1
      yield v
    for i in 0 ..< r:
      v.x += 1
      v.y -= 1
      yield v
    for i in 0 ..< r-1:
      v.x += 1
      v.y += 1
      yield v

## Iterate from the center point outward on the given axis with each successive point being further or equal distance from the start point
iterator middleOutLineIter*(start: Vec2i, axis: Axis, length: int32): Vec2i =
  var v = start
  yield v
  case axis:
    of Axis.X:
      for d in 1 .. length:
        v.x = start.x + d
        yield v
        v.x = start.x - d
        yield v
    of Axis.Y:
      for d in 1 .. length:
        v.y = start.y + d
        yield v
        v.y = start.y - d
        yield v
    else:
      err &"Cannot middle out line iterate in z"


iterator shadowcastIter*(D: int, originShifted : Option[Vec2i], shadowResolution: int): Vec2i =
  if originShifted.isSome:
    let s = originShifted.get * shadowResolution
    if s.x > 0:
      for i in 1 .. s.x:
        for v in middleOutLineIter(vec2i(D-s.x+i,0), Axis.Y, D.int32): yield v
    elif s.x < 0:
      for i in countdown(-1, s.x):
        for v in middleOutLineIter(vec2i(-D-s.x+i,0), Axis.Y, D.int32): yield v
    elif s.y > 0:
      for i in 1 .. s.y:
        for v in middleOutLineIter(vec2i(0,D-s.y+i), Axis.X, D.int32): yield v
    elif s.y < 0:
      for i in countdown(-1, s.y):
        for v in middleOutLineIter(vec2i(0,-D-s.y+i), Axis.X, D.int32): yield v
  else:
    for v in diamondIter((D.float*2).int32):
      yield v


proc damp(f: float32) : float32 =
  if f < 0.5: f
  else: min(f + 0.002f32, 1.0f32)

proc shadowcast[D: static[int]](shadowGrid : var ShadowGrid[D], lightGrid: var ShadowGrid[D], origin: Vec2i, originShifted: Option[Vec2i], shadowResolution: int32, attenuationFunction: (float) -> float, obstructionFunction: (int,int) -> float32) =
  let lightStrengthf = 255.0f
  let shadowResolutionf = shadowResolution.float

  for n in shadowcastIter(D, originShifted, shadowResolution):
    let nxa = n.x.abs.int
    let nya = n.y.abs.int
    if nxa <= D and nya <= D:
      let dist = sqrt(max((nxa*nxa + nya*nya).float32, 0.000001f))
      let attenuation = attenuationFunction(dist / shadowResolutionf)
      if attenuation <= 0.0:
        continue

      let (srcShadow, obstruction) = if n.x == 0 and n.y == 0:
        (1.0f32, 0.0f32)
      else:
        let pcntX = nxa.float32 / (nxa + nya).float32
        let pcntY = nya.float32 / (nxa + nya).float32

        let sx = sgn(n.x)
        let sy = sgn(n.y)

        let pxp = damp(shadowGrid[n.x.int - sx, n.y.int].float / 255.0f32)
        let pdp = damp(shadowGrid[n.x.int - sx, n.y.int - sy].float / 255.0f32)
        let pyp = damp(shadowGrid[n.x.int, n.y.int - sy].float / 255.0f32)

        let maxp = max(pcntX, pcntY)
        let orthoProportion = clamp((maxp - 0.5) * 2.5, 0.0, 1.0)
        let srcShadow = (pxp * pcntX + pyp * pcntY) * orthoProportion + pdp * (1.0 - orthoProportion)

        let wx = if shadowResolution != 1:
          if n.x < 0: origin.x + (n.x - 1) div shadowResolution else: origin.x + n.x div shadowResolution
        else:
          origin.x + n.x

        let wy = if shadowResolution != 1:
          if n.y < 0: origin.y + (n.y - 1) div shadowResolution else: origin.y + n.y div shadowResolution
        else:
          origin.y + n.y

        let obstruction = obstructionFunction(wx, wy)
        (srcShadow.float32, obstruction)

      let newShadow = srcShadow * (1.0f - obstruction)
      shadowGrid[n.x,n.y] = (clamp(newShadow, 0.0, 1.0) * 255).uint8

      let attenuatedLight = lightStrengthf * attenuation
      let light = attenuatedLight * srcShadow # multiply by srcShadow so that the obstruction itself is illuminated
      lightGrid[n.x, n.y] = clamp(light, 0.0, 255.0).uint8




# Cast shadows out from the origin, storing the results in the provided shadowGrid and lightGrid
# All coordinates in the shadowGrid and lightGrid are relative to the origin, i.e. [0,0] in light-space is equivalent to origin in world-space
# shadowResolution defines a conversion in scale between the shadow/light grids and the world coordinates. A value of 1 would
#     give equal resolution to both, 2 would have 2 units of light/shadow for every unit it world coords, etc
# On return the shadowGrid will have values representing the amount that rays were obstructed reaching a given point with 0 representing total obstruction and 255 no obstruction
# On return the lightGrid will have values representing the illumination level at each point, as modified by attenuation, with 0 representing no light and 255 full light
# The attenuation function takes in the current distance from the origin and returns how much the light level has reduced intensity at that distance
#    with a value of 0.0 indicating that no light reaches past this point irrespective of obstruction
# The obstruction function takes in the current [x,y] world coordinates (same coordinate space as origin) and returns the extent to which light is blocked
#    at this point with 0.0 indicating total transparency and 1.0 indicating total opacity
# Note: not all values are guaranteed to be overwritten in the shadow/light grids since the shadowcasting may short circuit once the limit of
#    attenuation is reached. If reusing grids with changing attenuation calculations make sure to reset() grids before re-use
proc shadowcast*[D: static[int]](shadowGrid : var ShadowGrid[D], lightGrid: var ShadowGrid[D], origin: Vec2i, shadowResolution: int32, attenuationFunction: (float) -> float, obstructionFunction: (int,int) -> float32) =
  shadowcast(shadowGrid, lightGrid, origin, none(Vec2i), shadowResolution, attenuationFunction, obstructionFunction)

proc shiftShadowcast*[D: static[int]](baseShadowGrid : ShadowGrid[D], targetShadowGrid: var ShadowGrid[D], baseLightGrid: ShadowGrid[D], targetLightGrid: var ShadowGrid[D], oldOrigin: Vec2i, newOrigin: Vec2i, shadowResolution: int32, attenuationFunction: (float) -> float, obstructionFunction: (int,int) -> float32) =
  let originDelta = newOrigin - oldOrigin
  # The origin shift is in world coordinates, so we have to multiply by the shadow resolution when doing the shift
  shift(baseShadowGrid, targetShadowGrid, -originDelta.x * shadowResolution, -originDelta.y * shadowResolution)
  shift(baseLightGrid, targetLightGrid, -originDelta.x * shadowResolution, -originDelta.y * shadowResolution)

  shadowcast(targetShadowGrid, targetLightGrid, newOrigin, some(originDelta), shadowResolution, attenuationFunction, obstructionFunction)




iterator suncastIter(patchFrom: Option[Vec2i], patchDistance: int32, radius: int32) : Vec2i =
  if patchFrom.isSome:
    let src = patchFrom.get
    let sx = sgn(src.x)
    let sy = sgn(src.y)
    let adaptedSrc = src - vec2i(sx,sy)

    var v : Vec2i
    for r in 0 ..< patchDistance+1:
      v.x = r
      v.y = 0
      yield v + adaptedSrc
      if sx >= 0 and sy >= 0:
        for i in 0 ..< r:
          v.x -= 1
          v.y += 1
          yield v + adaptedSrc
      else:
        v.x -= r
        v.y += r
        yield v + adaptedSrc

      if sx <= 0 and sy >= 0:
        for i in 0 ..< r:
          v.x -= 1
          v.y -= 1
          yield v + adaptedSrc
      else:
        v.x -= r
        v.y -= r
        yield v + adaptedSrc

      if sx <= 0 and sy <= 0:
        for i in 0 ..< r:
          v.x += 1
          v.y -= 1
          yield v + adaptedSrc
      else:
        v.x += r
        v.y -= r
        yield v + adaptedSrc

      if sx >= 0 and sy <= 0:
        for i in 0 ..< r-1:
          v.x += 1
          v.y += 1
          yield v + adaptedSrc
  else:
    for v in diamondIter(radius):
      yield v

proc toWorld(n : Vec2i, origin: Vec2i, shadowResolution: int32) : (int32,int32) =
  let wx = if shadowResolution != 1:
    if n.x < 0: origin.x + (n.x - 1) div shadowResolution else: origin.x + n.x div shadowResolution
  else:
    origin.x + n.x

  let wy = if shadowResolution != 1:
    if n.y < 0: origin.y + (n.y - 1) div shadowResolution else: origin.y + n.y div shadowResolution
  else:
    origin.y + n.y
  (wx, wy)


## Computes an indirect measure of shadow at every point in the grid, considered relative to the origin
## after completion the shadowGrid at each point will have a value between 0 (adjacent obstruction) to 1 (no obstruction within max shadow range)
## this can then be used to compute the sunshadow at a given time of day as the rays become increasingly horizontal
## The coordinate system of the shadowGrid is centered at the light source, shifted into the world's position by origin
proc suncast*[D: static[int]](shadowGrid : var ShadowGrid[D], origin: Vec2i, patch: Option[Vec2i], shadowResolution: int32, maxShadowLength: int32, obstructionFunction: (int,int) -> float32) =
  let shadowIncrement = 1.0f / (maxShadowLength * shadowResolution).float

  let transformedPatch = patch.map((x) => (x - origin) * shadowResolution)

  for n in suncastIter(transformedPatch, maxShadowLength * shadowResolution, (D*2).int32):
    let nxa = n.x.abs.int
    let nya = n.y.abs.int
    if nxa <= D and nya <= D:
      let srcShadow = if n.x == 0 and n.y == 0:
        1.0f32
      else:
        let pcntX = nxa.float32 / (nxa + nya).float32
        let pcntY = nya.float32 / (nxa + nya).float32

        let sx = sgn(n.x)
        let sy = sgn(n.y)

        let (wx,wy) = toWorld(n, origin, shadowResolution)
        let (wxdx,wydy) = toWorld(n - vec2i(sx, sy), origin, shadowResolution)

        let xobs = obstructionFunction(wxdx, wy)
        let yobs = obstructionFunction(wx, wydy)
        let dobs = obstructionFunction(wxdx, wydy)

        let pxp = min(shadowGrid[n.x.int - sx, n.y.int].float32 / 255.0f32, 1.0f - xobs)
        let pdp = min(shadowGrid[n.x.int - sx, n.y.int - sy].float32 / 255.0f32, 1.0f - dobs)
        let pyp = min(shadowGrid[n.x.int, n.y.int - sy].float32 / 255.0f32, 1.0f - yobs)

        let maxp = max(pcntX, pcntY)
        let orthoProportion = clamp((maxp - 0.5) * 2.5, 0.0, 1.0)
        let srcShadow = (pxp * pcntX + pyp * pcntY) * orthoProportion + pdp * (1.0 - orthoProportion)

        srcShadow.float32

      let newShadow = min(srcShadow + shadowIncrement,1.0f)
      shadowGrid[n.x,n.y] = (clamp(newShadow, 0.0, 1.0) * 255).uint8

when isMainModule:
  import os

  const TestShadowcast = true
  const TestSuncast = false

  proc tmp() =
    const lightRes = 128
    const shadowScale = 2
    var shadows = new ShadowGrid[lightRes]
    var lights = new ShadowGrid[lightRes]


    var obstructions : FiniteGrid2D[lightRes*2+8,lightRes*2+8, bool]
    proc setObstruction(dx: int, dy: int, truth : bool) =
      obstructions[lightRes + dx, lightRes + dy] = truth
    proc getObstruction(dx: int, dy: int) : bool =
      obstructions[lightRes + dx, lightRes + dy]

    setObstruction(15, 10, true)
    setObstruction(16, 09, true)
    setObstruction(16, 11, true)
    setObstruction(17, 10, true)
    setObstruction(16, 10, true)


    setObstruction(00, 19, true)
    setObstruction(01, 19, true)
    setObstruction(00, 20, true)
    setObstruction(01, 20, true)

    setObstruction(-20, -10, true)

    for x in -10 ..< -5:
      for y in -30 ..< -27:
        setObstruction(x,y, true)

    for x in 20 ..< 30:
      for y in 5 ..< 6:
        setObstruction(x,y, true)

    for x in 30 ..< 40:
      for y in -20 ..< -18:
        setObstruction(x,y, true)

    var origin = vec2i(lightRes, lightRes)

    func obstructionFunc(x,y:int): float32 =
      if obstructions[x,y]: 1.0f else: 0.0f

    func attenuation(d: float): float =
      # 1.0f32 - d / (lightRes / shadowScale).float32
      1.0f32

    let start = relTime()
    for i in 0 ..< 5:
      if TestShadowcast:
        shadowcast(shadows[], lights[], origin, shadowScale, attenuation , obstructionFunc)
      elif TestSuncast:
        suncast(shadows, origin, none(Vec2i), shadowScale, 12 , obstructionFunc)
    echo "Duration: ", ((relTime() - start) / 5.0f)

    if TestSuncast:
      var patchStart = relTime()
      setObstruction(-50,30, true)
      suncast(shadows, origin, some(vec2i(lightRes,lightRes) + vec2i(-50,30)), shadowScale, 12 , obstructionFunc)
      echo "Patch duration: ", (relTime() - patchStart)

      setObstruction(-20, -10, false)
      patchStart = relTime()
      suncast(shadows, origin, some(vec2i(lightRes,lightRes) + vec2i(-20,-10)), shadowScale, 12 , obstructionFunc)
      echo "Patch duration: ", (relTime() - patchStart)
    # elif TestShadowcast:
    #   var patchStart = relTime()
    #   let newOrigin = origin - vec2i(1,0)
    #   shiftShadowcast(shadows[], shadows[], lights[], lights[], origin, newOrigin, shadowScale, attenuation, obstructionFunc)
    #   origin = newOrigin
    #   echo "Patch duration: ", (relTime() - patchStart)


    let imgSize = 1024
    let img = createImage(vec2i(imgSize,imgSize))
    for ix in 0 ..< imgSize:
      for iy in 0 ..< imgSize:
        let x = ix div (imgSize div (lightRes * 2))
        let y = iy div (imgSize div (lightRes * 2))

        let intensity = if TestShadowcast:
          lights[x-lightRes,y-lightRes].float / 255.0f
        else:
          let rawIntensity = (shadows[x-lightRes,y-lightRes].float / 255.0f)
          clamp(rawIntensity * 1.0f, 0.0, 1.0)

        let (wx,wy) = toWorld(vec2i(x-lightRes, y - lightRes), origin, shadowScale)
        if obstructions[wx,wy]:
          img[ix,iy] = rgba(0.1,0.1,0.8,1.0)
        # elif intensity >= 0.98:
        #   img[ix,iy] = rgba(0.9,0.2,0.1,1.0)
        else:
          img[ix,iy] = rgba(intensity, intensity, intensity, 1.0f)

    writeToFile(img, "/tmp/lighting_new.png")
    discard execShellCmd("open /tmp/lighting_new.png")

  try:
    tmp()
  except: echo getCurrentException().getStackTrace()