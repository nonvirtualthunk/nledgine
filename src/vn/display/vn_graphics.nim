import engines
import graphics/canvas
import graphics/color
import options
import prelude
import reflect
import resources
import graphics/images
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


type
  VNGraphics* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    mousePos: Vec2f





method initialize(g: VNGraphics, world: LiveWorld, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")
  # display[WindowingSystem].desktop.background.image = bindable(imageRef("ui/woodBorderTransparent.png"))
  display[WindowingSystem].desktop.background.draw = bindable(false)
  discard

method update(g: VNGraphics, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let itr = isometricTileRendering(16)
  var floorQB = itr.quadBuilder

  floorQB.origin = vec2f(0.5f, 0.0f)
  # floorQB.origin = vec2f(0.5f, 0.5f)
  floorQB.texture = imageLike(image("vn/rooms/floor_1x1.png"))
  floorQB.color = rgba(1.0,1.0,1.0,1.0)
  floorQB.dimensions = vec2f(48.0f,48.0f)
  floorQB.groundOffset = 15

  var beltQB = itr.quadBuilder
  beltQB.origin = vec2f(0.5f, 0.0f)
  # beltQB.origin = vec2f(0.5f, 0.5f)
  beltQB.color = rgba(1.0,1.0,1.0,1.0)
  beltQB.dimensions = vec2f(48.0f,48.0f)
  beltQB.groundOffset = 0

  var objQB = itr.quadBuilder
  objQB.origin = vec2f(0.5f, 0.0f)
  # objQB.origin = vec2f(0.5f, 0.5f)
  objQB.color = rgba(1.0,1.0,1.0,1.0)
  objQB.dimensions = vec2f(16.0f,16.0f)
  objQB.groundOffset = 0

  var machQB = itr.quadBuilder
  machQB.origin = vec2f(0.5f, 0.0f)
  # objQB.origin = vec2f(0.5f, 0.5f)
  machQB.color = rgba(1.0,1.0,1.0,1.0)
  machQB.groundOffset = 0


  let objLib = library(ObjectKind)

  let beltImages = [imageLike(image("vn/machines/belt_sw.png")), imageLike(image("vn/machines/belt_nw.png")),
                    imageLike(image("vn/machines/belt_ne.png")), imageLike(image("vn/machines/belt_se.png"))]



  let GCD = display[GraphicsContextData]
  let worldPos = display[CameraData].camera.pixelToWorld(GCD.framebufferSize, GCD.windowSize, g.mousePos)
  let mousedOver = fromPixelPos(itr, worldPos.xy)


  let reg = region(world)
  let grid = reg.grid
  for chunk in grid.chunkIterReversed:
    let pos = chunk.position

    for x in countdown(chunk.dim-1, 0):
      for y in countdown(chunk.dim-1, 0):
        for z in 0 ..< chunk.dim:
          let v = chunk[x,y,z]
          if v.kind != VoxelKind.Empty:
            let ax = pos.x + x
            let ay = pos.y + y
            let az = pos.z + z

            if isAlignedToGrid(ax,ay,az, 3):
              floorQB.isoTilePos = vec3f(ax, ay, az)
              floorQB.drawTo(g.canvas)

            if v.kind == VoxelKind.Entity:
              if v.origin:
                let machEnt = Entity(id: v.entityId.int)
                let mach = machEnt[Machine]
                let mk = machineKind(mach.kind)
                machQB.texture = mk.image
                # machQB.dimensions = vec2f(16.0f32 * mk.size.x.float32, 16.0f32 * mk.size.x.float32)
                machQB.dimensions = vec2f(mk.image.asImage.dimensions)
                machQB.isoTilePos = vec3f(ax, ay, az)
                machQB.drawTo(g.canvas)
            else:
              if isAlignedToGrid(ax,ay,az, v.gridScale):
                case v.kind:
                  of VoxelKind.Belt:
                    beltQB.texture = beltImages[v.beltDir.ord]
                    beltQB.isoTilePos = vec3f(ax, ay, az)
                    beltQB.drawTo(g.canvas)
                  else:
                    discard

  var frameQB = itr.quadBuilder
  frameQB.isoTilePos = vec3f(mousedOver.x.float, mousedOver.y.float, 0.0)
  frameQB.color = White
  frameQB.texture = imageLike(image("vn/ui/frame_1x1.png"))
  frameQB.dimensions = vec2f(16.0f,16.0f)
  frameQB.origin = vec2f(0.5f,0.0f)
  frameQB.drawTo(g.canvas)

  #
  # frameQB.texture = imageLike(image("survival/icons/center.png"))
  # frameQB.origin = vec2f(0.5f,0.5f)
  # frameQB.position = vec3f(worldPos.x.float, worldPos.y.float, 0.0)
  # frameQB.drawTo(g.canvas)

  # let bd = world[Regions].regions[0][BeltData]
  # let bdi = beltGroupIndexContaining(bd, vec3i(mousedOver,0))
  # if bdi != -1:
  #   for s in bd.beltGroups[bdi].segments:
  #     var qb = itr.quadBuilder
  #     qb.isoTilePos = vec3f(s.x,s.y,s.z)
  #     qb.color = rgba(1.0,0.5,0.5,1.0)
  #     qb.texture = imageLike(image("survival/icons/center.png"))
  #     qb.dimensions = vec2f(16.0f,16.0f)
  #     qb.origin = vec2f(0.5f,0.0f)
  #     qb.drawTo(g.canvas)

  for chunk in reg.objects.chunkIterReversed:
    let pos = chunk.position
    let vChunk = getOrCreateChunk(grid, pos.x, pos.y, pos.z)

    for x in countdown(chunk.dim-1, 0):
      for y in countdown(chunk.dim-1, 0):
        for z in 0 ..< chunk.dim:
          let objId = chunk[x,y,z]
          if objId != 0:
            let v = vChunk[x,y,z]

            let ax = (pos.x + x).float32
            let ay = (pos.y + y).float32
            let az = (pos.z + z).float32
            var av = vec3f(ax,ay,az)

            if v.kind == VoxelKind.Belt:
              let f = v.progress.float32 / 180.0f32
              av += cardinalVector3Df(v.beltDir) * f

            let objKind = objLib[objId]
            objQB.texture = imageLike(objKind.image)
            objQB.isoTilePos = av
            objQB.groundOffset = if v.kind == VoxelKind.Belt:
              -3
            else:
              0
            objQB.drawTo(g.canvas)







  g.canvas.swap()
  @[g.canvas.drawCommand(display)]




method onEvent*(g: VNGraphics, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(KeyRelease, key):
      case key:
        of KeyCode.Z:
          display[CameraData].camera.changeScale(+1)
          display.addEvent(CameraChangedEvent())
        of KeyCode.X:
          display[CameraData].camera.changeScale(-1)
          display.addEvent(CameraChangedEvent())
        else:
          discard
    extract(MouseMove, position):
      g.mousePos = position