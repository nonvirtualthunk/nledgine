import game/grids
import prelude
import glm
import deques
import math
import graphics/images
import graphics/color


type
  ShadowGrid*[D: static[int]] = object
    grid: array[(D*2+1) * (D*2+1), uint8]




proc `[]`*[D: static[int]](g : ShadowGrid[D], vx: int, vy: int) : uint8 =
  g.grid[(vy+D) * (D*2+1) + (vx+D)]

proc `[]=`*[D: static[int]](g : var ShadowGrid[D], vx: int, vy: int, s : uint8) =
  g.grid[(vy+D) * (D*2+1) + (vx+D)] = s




proc shadowcast[D: static[int]](shadowGrid : var ShadowGrid[D], lightGrid: var ShadowGrid[D], origin: Vec2i, lightStrength: int, attenuationFunction: (float) -> float, obstructionFunction: (int,int) -> float32) =
  var q = initDeque[Vec2[int8]]()
  q.addLast(vec2i8(0, 0))

  let lightStrengthf = lightStrength.float32

  while q.len > 0:
    let n = q.popFirst
    let nxa = n.x.abs.int
    let nya = n.y.abs.int
    if nxa <= D and nya <= D:
      var addSuccessors = true

      let (shadow, dist) = if n.x == 0 and n.y == 0:
        (0.0f32, 0.0f32)
      else:
        let pcntX = nxa.float32 / (nxa + nya).float32
        let pcntY = nya.float32 / (nxa + nya).float32

        let sx = sgn(n.x).int
        let sy = sgn(n.y).int

        let pxp = shadowGrid[n.x.int - sx, n.y.int].float / 255.0f
        let pyp = shadowGrid[n.x.int, n.y.int - sy].float / 255.0f
        let pdp = shadowGrid[n.x.int - sx, n.y.int - sy].float / 255.0f

        # let nvec = vec2f(n.x, n.y).normalize
        # let xvec = vec2f(n.x - sx, n.y).normalize
        # let yvec = vec2f(n.x, n.y - sy).normalize
        # let dvec = vec2f(n.x - sx, n.y - sy).normalize
        #
        # let xdot = nvec.dot(xvec).abs
        # let ydot = nvec.dot(yvec).abs
        # let ddot = nvec.dot(dvec).abs

        # let srcShadow = if xdot > ydot and xdot > ddot:
        #   pxp
        # elif ydot > xdot and ydot > ddot:
        #   pyp
        # else:
        #   pdp

        # let sum = xdot+ydot+ddot
        # let srcShadow = pxp * (xdot / sum) + pyp * (ydot / sum) + pdp * (ddot / sum)

        # let srcShadow = if xdot > ydot:
        #   if ydot > ddot:
        #     pxp * (xdot / (xdot + ydot)) + pyp * (ydot / (xdot + ydot))
        #   else:
        #     pxp * (xdot / (xdot + ddot)) + pdp * (ydot / (xdot + ydot))
        # else:
        #   if xdot > ddot:
        #     pxp * (xdot / (xdot + ydot)) + pyp * (ydot / (xdot + ydot))
        #   else:
        #     pyp * (ydot / (ddot + ydot)) + pdp * (ddot / (ddot + ydot))

        # let srcShadow = if pcntX > pcntY:
        #   pxp * (pcntX*pcntX) + pdp * (1.0f - (pcntX*pcntX))
        # else:
        #   pyp * (pcntY*pcntY) + pdp * (1.0f - (pcntY*pcntY))


        let srcShadow = if nxa > (nxa + nya) div 4 and nya > (nxa + nya) div 4:
          let maxp = max(pcntX, pcntY)
          let pdp = shadowGrid[n.x.int - sx, n.y.int - sy].float / 255.0f
          (pxp * pcntX + pyp * pcntY) * (1.0 - maxP) + pdp * maxP
          # max((pxp * pcntX + pyp * pcntY),(pdp))
          # max(max(pxp, pyp), shadowGrid[n.x.int - sx, n.y.int - sy].float / 255.0f)
          # shadowGrid[n.x.int - sx, n.y.int - sy].float / 255.0f
          # (pxp * pcntX + pyp * pcntY)
        else:
          (pxp * pcntX + pyp * pcntY)
        # let srcShadow = pxp * pcntX + pyp * pcntY
        let obstruction = obstructionFunction(origin.x + n.x, origin.y + n.y)
        let shadow : float32 = 1.0f32 - (1.0f32 - srcShadow) * (1.0f32 - obstruction)

        (shadow, sqrt((nxa.int*nxa.int + nya.int*nya.int).float32))
      shadowGrid[n.x,n.y] = (clamp(shadow, 0.0, 1.0) * 255).uint8

      let attenuatedLight = lightStrengthf * attenuationFunction(dist)
      let light = attenuatedLight * (1.0f - shadow)
      lightGrid[n.x, n.y] = clamp(light, 0.0, 255.0).uint8

      if n.y == 0:
        if n.x == 0:
          q.addLast(vec2i8(n.x + 1, n.y))
          q.addLast(vec2i8(n.x - 1, n.y))
        else:
          q.addLast(vec2i8(n.x + sgn(n.x), n.y))
        q.addLast(vec2i8(n.x, n.y+1))
        q.addLast(vec2i8(n.x, n.y-1))
      else:
        q.addLast(vec2i8(n.x, n.y + sgn(n.y)))




when isMainModule:
  import os

  proc tmp() =
    const lightRes = 64
    var shadows : ShadowGrid[lightRes]
    var lights: ShadowGrid[lightRes]


    var obstructions : FiniteGrid2D[200,200, bool]
    obstructions[115, 110] = true
    obstructions[116, 109] = true
    obstructions[116, 111] = true
    obstructions[117, 110] = true
    obstructions[116, 110] = true


    obstructions[100, 119] = true
    obstructions[101, 119] = true
    obstructions[100, 120] = true
    obstructions[101, 120] = true

    obstructions[80, 90] = true

    for x in 90 ..< 95:
      for y in 70 ..< 73:
        obstructions[x,y] = true

    for x in 120 ..< 130:
      for y in 105 ..< 106:
        obstructions[x,y] = true

    for x in 130 ..< 140:
      for y in 80 ..< 82:
        obstructions[x,y] = true

    let start = relTime()
    shadowcast(shadows, lights, vec2i(100, 100), 255,  (d) => 1.0f - d / lightRes.float32 , func (x,y:int): float32 =
      if obstructions[x,y]: 1.0f else: 0.0f
    )
    echo "Duration: ", (relTime() - start).inSeconds


    let img = createImage(vec2i(512,512))
    for ix in 0 ..< 512:
      for iy in 0 ..< 512:
        let x = ix div (512 div 128)
        let y = iy div (512 div 128)
        let intensity = lights[x-lightRes,y-lightRes].float / 255.0f
        if obstructions[x-lightRes + 100,y - lightRes + 100]:
          img[ix,iy] = rgba(0.1,0.1,0.8,1.0)
        else:
          img[ix,iy] = rgba(intensity, intensity, intensity, 1.0f)

    writeToFile(img, "/tmp/lighting_new.png")
    discard execShellCmd("open /tmp/lighting_new.png")

  tmp()