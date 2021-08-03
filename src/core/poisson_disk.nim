import random
import prelude
import glm
import times
import math
import arxmath


type
  PoissonDiskSampling* = object
    dimensions*: Vec2i
    grid* : seq[uint16]
    points*: seq[Vec2f]

proc pointAt*(p: PoissonDiskSampling, x: int, y: int): Option[Vec2f] =
  if x >= 0 and y >= 0 and x < p.dimensions.x and y < p.dimensions.y:
    let i = p.grid[x * p.dimensions.y + y]
    if i > 0:
      some(p.points[i-1])
    else:
      none(Vec2f)
  else:
    none(Vec2f)

proc pointIndexAt*(p: PoissonDiskSampling, x: int, y: int): Option[int] =
  if x >= 0 and y >= 0 and x < p.dimensions.x and y < p.dimensions.y:
    let i = p.grid[x * p.dimensions.y + y]
    if i > 0:
      some(i-1)
    else:
      none(int)
  else:
    none(int)

iterator pointsInArea*(p: PoissonDiskSampling, r : Recti): Vec2f =
  for x in r.x ..< r.x + r.width:
    for y in r.y ..< r.y + r.height:
      let op = pointAt(p, x, y)
      if op.isSome:
        yield op.get

proc generatePoissonDiskSample*(w: int, h: int) : PoissonDiskSampling =
  result.dimensions = vec2i(w,h)
  var r = initRand(programStartTime.toTime.toUnix)
  const k = 5
  const radius = sqrt(2.0f32)
  const radius2 = 2.0f32

  result.grid.setLen(w*h)
  result.points.add(vec2f(r.rand(w.float32), r.rand(w.float32)))


  result.grid[result.points[^1].x.int * h + result.points[^1].y.int] = 1.uint16
  var activePoints = @[0]


  while activePoints.nonEmpty:
    let activePointListIndex = r.rand(activePoints.len-1)
    let pi = activePoints[activePointListIndex]
    let p = result.points[pi]
    var sampleAdded = false
    for ik in 0 ..< k:
      let angle = r.rand(TAU)
      let dist = r.rand(radius) + radius
      let nx = clamp(p.x + cos(angle) * dist, 0.0f32, (w-1).float32)
      let ny = clamp(p.y + sin(angle) * dist, 0.0f32, (h-1).float32)

      let nxi = nx.int
      let nyi = ny.int
      if nxi >= 0 and nyi >= 0 and nxi < w and nyi < h:
        var tooClose = false
        for dx in -1 .. 1:
          if not tooClose:
            for dy in -1 .. 1:
              if nxi + dx >= 0 and nyi + dy >= 0 and nxi + dx < w and nyi + dy < h:
                let api = result.grid[(nxi + dx) * h + (nyi + dy)]
                if api > 0:
                  let ap = result.points[api - 1]
                  if (ap.x-nx)*(ap.x-nx)+(ap.y-ny)*(ap.y-ny) < radius2:
                    tooClose = true
                    break
        if not tooClose:
          result.grid[nxi * h + nyi] = result.points.len.uint16 + 1 # +1 here so that we can have 0 represent no-point in the grid
          activePoints.add(result.points.len) # no +1 here so it's the actual index
          result.points.add(vec2f(nx,ny))
          sampleAdded = true
          break
    if not sampleAdded:
      activePoints.del(activePointListIndex)





when isMainModule:
  import graphics/images
  import graphics/color
  import os

  let poisson = generatePoissonDiskSampling(50,50)

  let img = createImage(vec2i(1024,1024))
  for x in 0 ..< 1024:
    for y in 0 ..< 1024:
      img[x,y] = rgba(255,255,255,255)

  for p in poisson.points:
    let px = (p.x/poisson.dimensions.x.float32 * 1023.0f32).int
    let py = (p.y/poisson.dimensions.y.float32 * 1023.0f32).int
    for dx in -1 .. 1:
      for dy in -1 .. 1:
        if px + dx >= 0 and px + dx < 1024 and py + dy >= 0 and py + dy < 1024:
          img[px+dx, py+dy] = rgba(0,0,0,255)

  img.writeToFile("/tmp/poisson.png")
  discard execShellCmd("open /tmp/poisson.png")
