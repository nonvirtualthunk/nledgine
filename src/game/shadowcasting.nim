import game/grids
import prelude
import glm
import deques
import math
import graphics/images
import graphics/color


type
  ShadowGrid*[D: static[int]] = object
    buffer: bool
    grid: array[(D*2+1) * (D*2+1), uint8]

proc `[]`*[D: static[int]](g : ShadowGrid[D], vx: int, vy: int) : uint8 =
  g.grid[(vy+D) * (D*2+1) + (vx+D)]

proc `[]`*[D: static[int]](g : ref ShadowGrid[D], vx: int, vy: int) : uint8 =
  g.grid[(vy+D) * (D*2+1) + (vx+D)]

proc `[]=`*[D: static[int]](g : var ShadowGrid[D], vx: int, vy: int, s : uint8) =
  g.grid[(vy+D) * (D*2+1) + (vx+D)] = s

# w - world coordinate
# o - origin
# s - sub-position within overal coordinate
# resolution - resolution of
proc atWorldCoord*[D: static[int]](g: ref ShadowGrid[D], wx: int, wy: int, ox: int, oy: int, sx: int, sy: int, resolution: int) : uint8 =
  let dx = wx - ox
  let dy = wy - oy
  g[dx * resolution + sx, dy * resolution + sy]

proc reset*[D: static[int]](g : var ShadowGrid[D]) =
  zeroMem(g.grid[0].addr, (D*2+1) * (D*2+1))
  # discard
  # for i in 0 ..< ((D*2+1)*(D*2+1)):
  #   g.grid[i] = 0.uint8

proc reset*[D: static[int]](g : ref ShadowGrid[D]) =
  zeroMem(g.grid[0].addr, (D*2+1) * (D*2+1))

proc radius*[D: static[int]](g : var ShadowGrid[D]) : int = D


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
  var q = initDeque[Vec2[int16]]()
  q.addLast(vec2s(0, 0))

  let lightStrengthf = 255.0f
  let shadowResolutionf = shadowResolution.float

  while q.len > 0:
    let n = q.popFirst
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

        let pxp = shadowGrid[n.x.int - sx, n.y.int].float / 255.0f
        let pyp = shadowGrid[n.x.int, n.y.int - sy].float / 255.0f
        let pdp = shadowGrid[n.x.int - sx, n.y.int - sy].float / 255.0f

        let maxp = max(pcntX, pcntY)
        let orthoProportion = clamp((maxp - 0.5) * 2.5, 0.0, 1.0)
        let srcShadow = (pxp * pcntX + pyp * pcntY) * orthoProportion + pdp * (1.0 - orthoProportion)

        let wx = if n.x < 0: origin.x + (n.x - 1) div shadowResolution else: origin.x + n.x div shadowResolution
        let wy = if n.y < 0: origin.y + (n.y - 1) div shadowResolution else: origin.y + n.y div shadowResolution
        let obstruction = obstructionFunction(wx, wy)
        (srcShadow.float32, obstruction)

      let newShadow = srcShadow * (1.0f - obstruction)
      shadowGrid[n.x,n.y] = (clamp(newShadow, 0.0, 1.0) * 255).uint8

      let attenuatedLight = lightStrengthf * attenuation
      let light = attenuatedLight * srcShadow # multiply by srcShadow so that the obstruction itself is illuminated
      lightGrid[n.x, n.y] = clamp(light, 0.0, 255.0).uint8

      if n.y == 0:
        if n.x == 0:
          q.addLast(vec2s(n.x + 1, n.y))
          q.addLast(vec2s(n.x - 1, n.y))
        else:
          q.addLast(vec2s(n.x + sgn(n.x), n.y))
        q.addLast(vec2s(n.x, n.y+1))
        q.addLast(vec2s(n.x, n.y-1))
      else:
        q.addLast(vec2s(n.x, n.y + sgn(n.y)))




when isMainModule:
  import os

  proc tmp() =
    const lightRes = 64
    var shadows : ShadowGrid[lightRes]
    var lights: ShadowGrid[lightRes]


    var obstructions : FiniteGrid2D[400,400, bool]
    obstructions[150 + 15, 150 + 10] = true
    obstructions[150 + 16, 150 + 09] = true
    obstructions[150 + 16, 150 + 11] = true
    obstructions[150 + 17, 150 + 10] = true
    obstructions[150 + 16, 150 + 10] = true


    obstructions[150 + 00, 150 + 19] = true
    obstructions[150 + 01, 150 + 19] = true
    obstructions[150 + 00, 150 + 20] = true
    obstructions[150 + 01, 150 + 20] = true

    obstructions[50 + 80, 50 + 90] = true

    for x in 90 ..< 95:
      for y in 70 ..< 73:
        obstructions[x+50,y+50] = true

    for x in 120 ..< 130:
      for y in 105 ..< 106:
        obstructions[x+50,y+50] = true

    for x in 130 ..< 140:
      for y in 80 ..< 82:
        obstructions[x+50,y+50] = true

    let start = relTime()
    for i in 0 ..< 100:
      shadowcast(shadows, lights, vec2i(150, 150), 1, (d) => 1.0f - d / lightRes.float32 , func (x,y:int): float32 =
        if obstructions[x,y]: 1.0f else: 0.0f
      )
    echo "Duration: ", ((relTime() - start).inSeconds / 100.0f)


    let img = createImage(vec2i(512,512))
    for ix in 0 ..< 512:
      for iy in 0 ..< 512:
        let x = ix div (512 div (lightRes * 2))
        let y = iy div (512 div (lightRes * 2))
        let intensity = lights[x-lightRes,y-lightRes].float / 255.0f
        if obstructions[x-lightRes + 150,y - lightRes + 150]:
          img[ix,iy] = rgba(0.1,0.1,0.8,1.0)
        elif intensity >= 0.98:
          img[ix,iy] = rgba(0.9,0.2,0.1,1.0)
        else:
          img[ix,iy] = rgba(intensity, intensity, intensity, 1.0f)

    writeToFile(img, "/tmp/lighting_new.png")
    discard execShellCmd("open /tmp/lighting_new.png")

  try:
    tmp()
  except: echo getCurrentException().getStackTrace()