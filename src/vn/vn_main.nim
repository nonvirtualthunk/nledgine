import main
import application
import display/vn_graphics
import glm
import engines/debug_components
import game/belt_component
import windowingsystem/windowingsystem_component
import graphics/color
import game/entities
import worlds
import vn/game/entities
import vn/game/logic
import vn/game/core_components
import vn/game/machine_component
import game/grids
import graphics/camera_component
import graphics/cameras
import options
import prelude
import engines


type
  InitComponent = ref object of LiveGameComponent

proc initComponent(): InitComponent =
  result = new InitComponent
  result.initializePriority = 100

method initialize(g: InitComponent, world: LiveWorld) =
  world.attachData(Regions())
  let regions = world[Regions]

  let regionEnt = createRegion(world)
  let reg = regionEnt[Region]

  regions.regions.add(regionEnt)


  for x in countup(-18,18, 3):
    for y in countup(-18,18, 3):
      setVoxel(world, regionEnt, reg,x,y,0, Voxel(kind: VoxelKind.Floor, gridScale: 3))

  setVoxel(world, regionEnt, reg,-3,0,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Right, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,0,0,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Right, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,3,0,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Up, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,3,3,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Up, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,3,6,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Left, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,0,6,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Left, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,-3,6,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Left, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,-6,6,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Down, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,-6,3,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Down, gridScale: 3, speed: 2))
  setVoxel(world, regionEnt, reg,-6,0,0, Voxel(kind: VoxelKind.Belt, beltDir: Cardinals2D.Right, gridScale: 3, speed: 2))

  let scoop = createMachine(world, † Machines.Aetherscoop)
  placeMachine(world, regionEnt, scoop, vec3i(6,0,0))

  setObject(world, regionEnt, reg, 0,0,0, † Objects.Aether)
  setObject(world, regionEnt, reg, 1,0,0, † Objects.Aether)
  setObject(world, regionEnt, reg, 1,1,0, † Objects.Aether)
  setObject(world, regionEnt, reg, 2,2,0, † Objects.Aether)
  setObject(world, regionEnt, reg, 3,2,0, † Objects.Aether)


main(GameSetup(
  windowSize: vec2i(1800, 1200),
  resizeable: false,
  windowTitle: "VN",
  clearColor: rgba(0.15,0.15,0.15,1.0),
  liveGameComponents: @[
    BasicLiveWorldDebugComponent(),
    beltComponent(),
    timeComponent(),
    initComponent(),
    machineComponent()
  ],
  graphicsComponents: @[
    createCameraComponent(createPixelCamera(6)),
    createWindowingSystemComponent("vn/widgets/"),
    VNGraphics()
  ],
  useLiveWorld: true,
))