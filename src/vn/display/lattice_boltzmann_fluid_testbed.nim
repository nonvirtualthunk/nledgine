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

const Width = 128
const HW = Width div 2
const Height = 128
const HH = Height div 2
const Depth = 8
const HD = Depth div 2


const MaxDensity = 1.0f32
const MaxDensityf = MaxDensity.float32

const Directions = 9
# const DirectionWeights = [16, 4, 4, 4, 4, 1, 1, 1, 1]
const DirectionWeights = [16.0f32/36.0f32, 4.0f32/36.0f32, 4.0f32/36.0f32, 4.0f32/36.0f32, 4.0f32/36.0f32, 1.0f32/36.0f32, 1.0f32/36.0f32, 1.0f32/36.0f32, 1.0f32/36.0f32]

#                             0           1           2             3           4           5               6           7           8
const DirectionVectors = [vec2f(0,0), vec2f(-1,0), vec2f(1,0), vec2f(0,-1), vec2f(0,1), vec2f(-1,-1), vec2f(1,-1), vec2f(1,1), vec2f(-1,1)]
const DirectionVectorsi = [vec2i(0,0), vec2i(-1,0), vec2i(1,0), vec2i(0,-1), vec2i(0,1), vec2i(-1,-1), vec2i(1,-1), vec2i(1,1), vec2i(-1,1)]
const DirectionOpposites = [0, 2, 1, 4, 3, 7, 8, 5, 6]


type
  Cell* = object
    densities*: array[9, float32]

  FluidComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    lastDrawn: UnitOfTime

    lattice: TickTock[FiniteGrid2D[Width, Height, Cell]]
    walls: FiniteGrid2D[Width, Height, bool]

    iterations : int


proc density*(c: Cell) : float32 =
  result = 0
  for i in 0 ..< 9:
    result += c.densities[i]



method initialize(g: FluidComponent, world: LiveWorld, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")
  # display[WindowingSystem].desktop.background.draw = bindable(false)

  g.lattice = tickTock[FiniteGrid2D[Width,Height,Cell]]()

  proc setWall(x,y,z: int) =
    g.walls[x,y] = true

  for x in 0 ..< Width - 1:
    for y in 0 ..< Height - 1:
      for q in 0 ..< Directions:
        g.lattice.prev.raw(x,y).densities[q] = DirectionWeights[q]

  # for x in 0 ..< 3:
  #   for y in 0 ..< 3:
  #     g.lattice.prev.raw(HW + x,HH + y).densities[0] = MaxDensity




proc simulate(g: FluidComponent) =
  let accelTau = 0.00f32
  # for x in 0 ..< 3:
  #   for y in 0 ..< 3:
  #     for q in 0 ..< 9:
  #       g.lattice.prev.raw(HW+x,HH+y).densities[q] = if q == 0 : MaxDensityf else : 0.0f32

  # equilibrium
  for x in 0 ..< Width - 1:
    let cellColl = g.lattice.prev.getPtr(x,0)
    for y in 0 ..< Height - 1:
      let cell = cellColl + y

      var totalDensity = 0f32
      var vx = 0f32
      var vy = 0f32

      for q in 0 ..< Directions:
        let d = cell.densities[q]
        totalDensity += d
        vx += DirectionVectors[q].x * d
        vy += DirectionVectors[q].y * d
      vy -= accelTau

      if totalDensity > 0.0f32:
        vx /= totalDensity
        vy /= totalDensity

      let vx2 = vx * vx
      let vy2 = vy * vy
      let v2 = vx2 + vy2

      const coeff1 = 3.0f32
      const coeff2Num = 9.0f32
      const coeff2Den = 2.0f32
      const coeff2 = coeff2Num / coeff2Den
      const coeff3Num = -3.0f32
      const coeff3Den = 2.0f32
      const coeff3 = coeff3Num / coeff3Den

      for q in 0 ..< Directions:
        let term = DirectionVectors[q].x * vx + DirectionVectors[q].y * vy
        let eq = DirectionWeights[q] * totalDensity * (1.0f32 + coeff1 * term + coeff2 * term * term + coeff3 * v2)
        cell.densities[q] -= (cell.densities[q] - eq) # div tau ?

      for q in 0 ..< Directions:
        let adjX = (x + DirectionVectorsi[q].x + Width) mod Width
        let adjY = (y + DirectionVectorsi[q].y + Height) mod Height

        let newDir = if adjX == 0 or adjX == Width - 1 or adjY == 0 or adjY == Height - 1:
          DirectionOpposites[q]
        else:
          q

        # if adjX >= 0 and adjX < Width and adjY >= 0 and adjY < Height:
        #   g.lattice.next.getPtr(adjX, adjY).densities[newDir] = cell.densities[q]
        # else:
        g.lattice.next.getPtr(adjX,adjY).densities[q] = cell.densities[q]


  g.lattice.swap()
  # g.lattice.next.clear()



method update(g: FluidComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let t = relTime()

  if t - g.lastDrawn > 0.01.seconds:
    g.lastDrawn = t


    simulate(g)
    var qb = QuadBuilder()
    qb.texture = image("vn/fluid/water/flat_water_8.png")
    qb.color = White
    qb.dimensions = vec2f(16.0f,16.0f)

    # var waterTexCoords : array[9, ref array[4,Vec2f]]
    # for i in 0 ..< 9:
    #   waterTexCoords[i] = g.canvas.texture[image(&"vn/fluid/water/water_{i}.png")]

    for x in countdown(Width-1,0):
      for y in countdown(Height-1,0):
        let density = g.lattice.prev[x,y].density()
        if density > 0.0f32:
          qb.color.a = clamp(density.float32 / MaxDensityf, 0.0f32, 1.0f32)
          qb.position = vec3f(x.float32*16.0f32, y.float32 * 16.0f32, 0.0f32)
          qb.drawTo(g.canvas)

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
     graphicsComponents: @[FluidComponent(), createCameraComponent(createPixelCamera(1, vec2f(-HW.float32 * 16.0f32,-HH.float32 * 16.0f32)))],
     clearColor: rgba(0.5f,0.5f,0.5f,1.0f),
     useLiveWorld: true
  ))