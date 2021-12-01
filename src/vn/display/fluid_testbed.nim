import engines
import graphics/canvas
import graphics/color
import options
import prelude
import reflect
import resources
import graphics/images
import graphics/core as graphics_core
import glm
import tables
import game/library
import worlds
import noto
import windowingsystem/windowingsystem
import graphics/camera_component
import graphics/cameras
import core
import worlds/identity
import arxmath
import math
import core/metrics
import nimgl/[glfw, opengl]
import graphics/isometric
import vn/game/entities
import vn/game/logic
import game/grids
import graphics/texture_block

const Width = 48
const HW = Width div 2
const Height = 48
const HH = Height div 2
const Depth = 8
const HD = Depth div 2

type FluidLevelType = int32
type PressureType = int32
type DivergenceType = int32
type VelocityType = Vec3[int16]

const MaxFluid = 100_000_000
const MaxFluidf = 100_000_000.0f32
const WallFluidValue = -10
const DiffusionDivisor = 15
const DiffusionShift = 4
const DiffusionIterations = 4

const VelocityScalei = 1000
const VelocityScale = 1000f32
const MaxVelocityi = VelocityScalei*10
const MinVelocityi = -VelocityScalei*10

type

  FluidComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    lastDrawn: UnitOfTime



    fluidQuantity*: TickTock[FiniteGrid3D[Width,Height,Depth, FluidLevelType]]
    pressure*: TickTock[FiniteGrid3D[Width,Height,Depth, PressureType]]
    divergence*: ref FiniteGrid3D[Width,Height,Depth, DivergenceType]
    velocity*: TickTock[FiniteGrid3D[Width,Height,Depth, VelocityType]]
    walls*: ref FiniteGrid3D[Width, Height, Depth, bool]

    drawTimer: Timer
    drawPrint: OneShot

    iterations : int




method initialize(g: FluidComponent, world: LiveWorld, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")
  # display[WindowingSystem].desktop.background.draw = bindable(false)
  g.drawTimer = timer("Fluid Draw")

  g.fluidQuantity = tickTock[FiniteGrid3D[Width,Height,Depth,FluidLevelType]]()
  g.pressure = tickTock[FiniteGrid3D[Width,Height,Depth,PressureType]]()
  g.divergence = new FiniteGrid3D[Width,Height,Depth, DivergenceType]
  g.walls = new FiniteGrid3D[Width, Height, Depth, bool]
  g.velocity = tickTock[FiniteGrid3D[Width, Height, Depth, VelocityType]]()

  proc setWall(x,y,z: int) =
    g.walls[x,y,z] = true
    g.fluidQuantity.prev[x,y,z] = WallFluidValue
    g.fluidQuantity.next[x,y,z] = WallFluidValue

  for x in countdown(HW-3, -HW, 3):
    for y in countdown(HH-3, -HH, 3):
      for dx in countdown(2,0):
        for dy in countdown(2,0):
          let wx = x+HW+dx
          let wy = y+HH+dy
          setWall(wx,wy, 0)
          if ((x.abs == HW div 2 or y.abs == HH div 2) and (x != 0 and y != 0)) or (wx <= 1 or wx >= Width - 2 or wy <= 1 or wy >= Height - 2):
            setWall(wx, wy, 1)
            setWall(wx, wy, 2)
            if dx != 1:
              setWall(wx, wy, 3)
          else:
            if x.abs < HW div 3 and y.abs < HH div 3:
              let afx = (x+dx).float32 / HW.float32
              let afy = (y+dy).float32 / HH.float32
              let normDist = sqrt(afx*afx+afy*afy)/1.44f32
              # let h = pow(1.0f32 - normDist, 2.0f32) * 4.0f32
              let h = 0.0f32

              for i in 0 .. h.int:
                let r = h - i.float32
                g.fluidQuantity.prev[x+HW + dx, y + HH + dy, i+1] = (min(1.0f32, r) * MaxFluidf).int32


proc diffuse[W,H,D](values: TickTock[FiniteGrid3D[W,H,D,int32]], diffusionShift: int32) =
  let prevB = values.prev
  let nextB = values.next
  for x in 1 ..< W-1:
    for y in 1 ..< H-1:
      let lstack = prevB.getPtr(x-1,y,0)
      let rstack = prevB.getPtr(x+1,y,0)
      let fstack = prevB.getPtr(x,y+1,0)
      let bstack = prevB.getPtr(x,y-1,0)
      let cstack = prevB.getPtr(x,y,0)

      let writeStack = nextB.getPtr(x,y,0)

      for z in 1 ..< D-1:
        let center = cstack[z]
        if center >= 0:
          var delta = 0
          let da = cstack[z-1]
          let ua = cstack[z+1]
          let la = lstack[z]
          let ra = rstack[z]
          let ba = bstack[z]
          let fa = fstack[z]

          if da >= 0: delta += (da - center) shr diffusionShift
          if ua >= 0: delta += (ua - center) shr diffusionShift
          if la >= 0: delta += (la - center) shr diffusionShift
          if ra >= 0: delta += (ra - center) shr diffusionShift
          if ba >= 0: delta += (ba - center) shr diffusionShift
          if fa >= 0: delta += (fa - center) shr diffusionShift

          writeStack[z] = (center + delta).int32
  values.swap()


# template getStacks[T](grid: ref FiniteGrid3D[W,H,D,T], x,y,z: int) =
#   let lstack {.inject.} = grid.getPtr(x-1,y,0)
#   let rstack {.inject.} = grid.getPtr(x+1,y,0)
#   let fstack {.inject.} = grid.getPtr(x,y+1,0)
#   let bstack {.inject.} = grid.getPtr(x,y-1,0)
#   let cstack {.inject.} = grid.getPtr(x,y,0)

proc vmag(v: Vec3s) : float32 =
  let x = v.x.float32
  let y = v.y.float32
  let z = v.z.float32
  sqrt(x*x+y*y+z*z)

proc advect[W,H,D,T](velocity: ref FiniteGrid3D[W,H,D,VelocityType], walls: ref FiniteGrid3D[W,H,D,bool], bufferToAdvect: ref FiniteGrid3D[W,H,D,T], tmp: ref FiniteGrid3D[W,H,D,T], scaleFn: (T,float32) -> T, dt: float32) =
  tmp.clear()
  let zeroVec = vec3s(0,0,0)

  for x in 1 ..< W-1:
    let xf = x.float32
    for y in 1 ..< H-1:
      let yf = y.float32

      let wallStack = walls.getPtr(x,y,0)
      let vstack = velocity.getPtr(x,y,0)
      let astack = bufferToAdvect.getPtr(x,y,0)
      let writeStack = tmp.getPtr(x,y,0)

      for z in 1 ..< D - 1:
        if not wallStack[z]:
          let zf = z.float32
          let v = vstack[z]

          if v != zeroVec:
            # Note: we might want to have 3 advections here, one per axis, with each being proportional in quantity to the vel on that axis
            let toX = x + sgn(v.x)
            let toY = y + sgn(v.y)
            let toZ = z + sgn(v.z)
            let moveProportion = clamp((vmag(v) / VelocityScale) * dt, 0.0f32, 1.0f32)

            let quantityMoved = scaleFn(bufferToAdvect[x,y,z], moveProportion)
            writeStack[z] -= astack[z] + quantityMoved
            tmp[toX,toY,toZ] += quantityMoved

            # info &"({x},{y},{z}) <- ({fromX},{fromY},{fromZ}): v: {v}, q: {quantityMoved}, p: {moveProportion}"
          else:
            writeStack[z] += astack[z]


          # # let fromX = xf - (vstack[z].x.float32 / VelocityScale) * dt
          # # let fromY = yf - (vstack[z].y.float32 / VelocityScale) * dt
          # # let fromZ = zf - (vstack[z].z.float32 / VelocityScale) * dt
          #
          # if v != zeroVec:
          #   # Note: we might want to have 3 advections here, one per axis, with each being proportional in quantity to the vel on that axis
          #   let fromX = x - sgn(v.x)
          #   let fromY = y - sgn(v.y)
          #   let fromZ = z - sgn(v.z)
          #   let moveProportion = clamp((vmag(v) / VelocityScale) * dt, 0.0f32, 1.0f32)
          #
          #   let quantityMoved = scaleFn(bufferToAdvect[fromX,fromY,fromZ], moveProportion)
          #   writeStack[z] += astack[z] + quantityMoved
          #   tmp[fromX,fromY,fromZ] -= quantityMoved
          #
          #   # info &"({x},{y},{z}) <- ({fromX},{fromY},{fromZ}): v: {v}, q: {quantityMoved}, p: {moveProportion}"
          # else:
          #   writeStack[z] += astack[z]




proc project[W,H,D](pressure: TickTock[FiniteGrid3D[W,H,D,PressureType]], velocity: TickTock[FiniteGrid3D[W,H,D,VelocityType]], divergence: ref FiniteGrid3D[W,H,D,DivergenceType], walls: ref FiniteGrid3D[W,H,D,bool], shift: int32) =
  let velB = velocity.prev

  # Divergence, positive where more is flowing into a cell than out. Negative where more is flowing out than in
  for x in 1 ..< W-1:
    for y in 1 ..< H-1:
      let lstack = velB.getPtr(x-1,y,0)
      let rstack = velB.getPtr(x+1,y,0)
      let fstack = velB.getPtr(x,y+1,0)
      let bstack = velB.getPtr(x,y-1,0)
      let cstack = velB.getPtr(x,y,0)

      let writeStack = divergence.getPtr(x,y,0)

      for d in 1 ..< D-1:
        let dx = rstack[d].x - lstack[d].x
        let dy = fstack[d].y - bstack[d].y
        let dz = cstack[d+1].z - cstack[d-1].z
        writeStack[d] = (dx + dy + dz) div 2

  pressure.prev.clear()

  # Diffuse the pressure such that every cell is equal to the average of its neighbors accounting for divergence
  for i in 0 ..< DiffusionIterations:
    let prevB = pressure.prev
    let nextB = pressure.next
    for x in 1 ..< W-1:
      for y in 1 ..< H-1:
        let lstack = prevB.getPtr(x-1,y,0)
        let rstack = prevB.getPtr(x+1,y,0)
        let fstack = prevB.getPtr(x,y+1,0)
        let bstack = prevB.getPtr(x,y-1,0)
        let cstack = prevB.getPtr(x,y,0)

        let dstack = divergence.getPtr(x,y,0)

        let writeStack = nextB.getPtr(x,y,0)

        for z in 1 ..< D-1:
          let center = dstack[z]

          var delta = 0
          let da = cstack[z-1]
          let ua = cstack[z+1]
          let la = lstack[z]
          let ra = rstack[z]
          let ba = bstack[z]
          let fa = fstack[z]

          writeStack[z] = (da+ua+la+ra+ba+fa-center) div 6
    pressure.swap()

  # Apply the pressure gradient to the velocity to counteract the divergence
  let pressureB = pressure.prev
  for x in 1 ..< W-1:
    for y in 1 ..< H-1:
      let wallStack = walls.getPtr(x,y,0)

      let lstack = pressureB.getPtr(x-1,y,0)
      let rstack = pressureB.getPtr(x+1,y,0)
      let fstack = pressureB.getPtr(x,y+1,0)
      let bstack = pressureB.getPtr(x,y-1,0)
      let cstack = pressureB.getPtr(x,y,0)

      let writeStack = velB.getPtr(x,y,0)
      for z in 1 ..< D-1:
        if not wallStack[z]:
          let gradient = vec3s(rstack[z] - lstack[z], fstack[z] - bstack[z], cstack[z+1] - cstack[z-1])
          writeStack[z] = writeStack[z] - gradient


proc applyGravity[W,H,D](velocity: TickTock[FiniteGrid3D[W,H,D,VelocityType]], fluid: TickTock[FiniteGrid3D[W,H,D,FluidLevelType]], walls: ref FiniteGrid3D[W,H,D,bool]) =
  let velB = velocity.prev
  let fluidB = fluid.prev

  for x in 1 ..< W-1:
    for y in 1 ..< H-1:
      let wallStack = walls.getPtr(x,y,0)
      let fluidStack = fluidB.getPtr(x,y,0)

      let writeStack = velB.getPtr(x,y,0)
      for z in 1 ..< D-1:
        if fluidStack[z] > 0:
          writeStack[z].z = clamp(writeStack[z].z - (VelocityScalei div 60), MinVelocityi, MaxVelocityi)
        # let f = fluidStack[z+1]
        # if not wallStack[z] and not wallStack[z-1]:# and f > 0:
        #   writeStack[z].z = clamp(writeStack[z].z - (VelocityScalei div 60), MinVelocityi, MaxVelocityi)

  for x in 0 ..< W:
    for y in 0 ..< H:
      let writeStack = velB.getPtr(x,y,0)
      for z in 0 ..< D:
        writeStack[z].x = clamp(writeStack[z].x, MinVelocityi, MaxVelocityi)
        writeStack[z].y = clamp(writeStack[z].y, MinVelocityi, MaxVelocityi)
        writeStack[z].z = clamp(writeStack[z].z, MinVelocityi, MaxVelocityi)




proc simulateFull*(g: FluidComponent) =
  g.fluidQuantity.prev[HW,HH,Depth-2] = MaxFluid

  applyGravity(g.velocity, g.fluidQuantity, g.walls)

  project(g.pressure, g.velocity, g.divergence, g.walls, 1)

  advect(g.velocity.prev, g.walls, g.fluidQuantity.prev, g.fluidQuantity.next, (v,f) => (v.float32 * f).FluidLevelType, 0.01)
  g.fluidQuantity.swap()
  advect(g.velocity.prev, g.walls, g.velocity.prev, g.velocity.next, (v,f) => v * f, 0.01)
  g.velocity.swap()

proc simulateDiffuseOnly(g: FluidComponent) =
  let t = relTime()

  let viscosity = 0.5f32
  let timestep = 0.002f32

  let viscosityTime = viscosity * timestep
  let centerFactor = 1.0f32 / (viscosityTime)


  var anyFluid = new FiniteGrid2D[Width,Height,bool]
  let grid = g.fluidQuantity.prev
  for x in 0 ..< Width:
    for y in 0 ..< Height:
      for z in 0 ..< Depth:
        if grid[x,y,z] > 0:
          anyFluid[x,y] = true
          break

  g.timer("fluid (total)").time:
    for iter in 0 ..< 3:
      let prevB = g.fluidQuantity.prev
      let nextB = g.fluidQuantity.next

      prevB[HW,HH,Depth-2] = MaxFluid div 4
      anyFluid[HW,HH] = true

      g.timer("diffusion").time:
        for x in 1 ..< Width-1:
          for y in 1 ..< Height-1:
            if not anyFluid[x,y] and not anyFluid[x-1,y] and not anyFluid[x+1,y] and not anyFluid[x,y-1] and not anyFluid[x,y+1]: continue

            let lstack = prevB.getPtr(x-1,y,0)
            let rstack = prevB.getPtr(x+1,y,0)
            let fstack = prevB.getPtr(x,y+1,0)
            let bstack = prevB.getPtr(x,y-1,0)
            let cstack = prevB.getPtr(x,y,0)

            let writeStack = nextB.getPtr(x,y,0)

            var addedFluid = false
            for z in 1 ..< Depth-1:
              let center = cstack[z]
              if center >= 0:
                var delta = 0
                let da = cstack[z-1]
                let ua = cstack[z+1]
                let la = lstack[z]
                let ra = rstack[z]
                let ba = bstack[z]
                let fa = fstack[z]

                if da >= 0: delta += (da - center) shr DiffusionShift
                if ua >= 0: delta += (ua - center) shr DiffusionShift
                if la >= 0: delta += (la - center) shr DiffusionShift
                if ra >= 0: delta += (ra - center) shr DiffusionShift
                if ba >= 0: delta += (ba - center) shr DiffusionShift
                if fa >= 0: delta += (fa - center) shr DiffusionShift

                addedFluid = delta > 0

                writeStack[z] = (center + delta).int32

            if addedFluid:
              anyFluid[x,y] = true

      g.timer("gravity").time:
        for x in 1 ..< Width-1:
          for y in 1 ..< Height-1:
            if anyFluid[x,y]:
              let cstack = nextB.getPtr(x,y,0)
              for z in countdown(Depth-2,1):
                let center = cstack[z]
                if center < MaxFluid and center >= 0:
                  let above = cstack[z+1]
                  if above > 0:
                    let delta = min(above, min(MaxFluid div 4, MaxFluid - center))
                    cstack[z] = center + delta
                    cstack[z+1] = above - delta

      g.fluidQuantity.swap()



method update(g: FluidComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let t = relTime()

  g.iterations.inc
  if g.iterations mod 240 == 0:
    var sum = 0i64
    for x in 1 ..< Width-1:
      for y in 1 ..< Height-1:
        for z in 1 ..< Depth-1:
          let q = g.fluidQuantity.prev[x,y,z]
          if q > 0:
            sum += q
    info &"Total fluid: {sum}"
    for timer in g.timers.values:
      info $timer

  # let rDiagonal = (viscosityTime) / (1.0f32 + 4.0f32 * viscosityTime)

  # simulateDiffuseOnly(g)
  simulateFull(g)

  if t - g.lastDrawn > 0.032.seconds:
    g.lastDrawn = t

    g.drawTimer.time:
      let itr = isometricTileRendering(16)
      var floorQB = itr.quadBuilder

      let floorTexCoords = g.canvas.texture[image("vn/rooms/block_1x1x1.png")]
      floorQB.origin = vec2f(0.5f, 0.0f)
      # floorQB.origin = vec2f(0.5f, 0.5f)
      floorQB.texCoords = some(floorTexCoords)
      floorQB.color = rgba(1.0,1.0,1.0,1.0)
      floorQB.dimensions = vec2f(16.0f,16.0f)
      floorQB.groundOffset = 0

      var waterQB = itr.quadBuilder
      waterQB.origin = vec2f(0.5f,0.0f)
      waterQB.color = rgba(1.0,1.0,1.0,1.0)
      waterQB.dimensions = vec2f(16.0f,16.0f)

      var waterTexCoords : array[9, ref array[4,Vec2f]]
      for i in 0 ..< 9:
        waterTexCoords[i] = g.canvas.texture[image(&"vn/fluid/water/water_{i}.png")]



      for x in countdown(Width-1,0):
        for y in countdown(Height-1,0):
          let wallStack = g.walls.getPtr(x,y,0)
          let fluidStack = g.fluidQuantity.prev.getPtr(x,y,0)
          for d in 0 ..< Depth:
            if wallStack[d]:
              floorQB.isoTilePos = vec3f(x,y,d)
              floorQB.drawTo(g.canvas)
            else:
              let wq = fluidStack[d]
              if wq > 0:
                let higher = fluidStack[d+1]
                if higher > MaxFluid div 8 and wq > MaxFluid div 8:
                  waterQB.texCoords = some(waterTexCoords[^1])
                else:
                  let wqf = clamp(wq.float32 / MaxFluidf, 0.0f32, 1.0f32)
                  waterQB.texCoords = some(waterTexCoords[(wqf * 8.4f32).round.int])

                waterQB.isoTilePos = vec3f(x,y,d)
                waterQB.drawTo(g.canvas)


    if relTime() > 5.seconds:
      if g.drawPrint.fire:
        info $g.drawTimer
    g.canvas.swap()
    @[g.canvas.drawCommand(display)]
  else:
    @[]

when isMainModule:
  import main
  import application

  main(GameSetup(
     windowSize: vec2i(1600, 1080),
     resizeable: false,
     windowTitle: "Fluid Testing",
     gameComponents: @[],
     graphicsComponents: @[FluidComponent(), createCameraComponent(createPixelCamera(4, vec2f(0.0f32,-HH.float32 * 8.0f32)))],
     clearColor: rgba(0.5f,0.5f,0.5f,1.0f),
     useLiveWorld: true
  ))