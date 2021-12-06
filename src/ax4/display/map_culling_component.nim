import engines
import graphics
import prelude
import tables
import ax4/game/map
import hex
import graphics/cameras
import graphics/camera_component
import resources
import graphics/image_extras
import data/cullingData
import game/library
import options
import noto
import worlds
import ax4/display/data/mapGraphicsData
import arxmath
import graphics/core
import sets
import algorithm

const margin = -800

type
   MapCullingComponent* = ref object of GraphicsComponent
      lastCameraPos: AxialVec
      cameraPosWatcher: Watcher[AxialVec]
      windowWatcher: Watcher[Vec2i]
      hexSize: int

method initialize(g: MapCullingComponent, world: World, curView: WorldView, display: DisplayWorld) =
   display.attachData(CullingData())
   g.name = "MapCullingComponent"
   g.hexSize = mapGraphicsSettings().hexSize
   g.cameraPosWatcher = watcher(() => toAxialVec(display[CameraData].camera.eye, g.hexSize.float))
   g.windowWatcher = watcher(() => display[GraphicsContextData].framebufferSize)

method update(g: MapCullingComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   let cam = display[CameraData].camera
   var CD = display[CullingData]
   let GCD = display[GraphicsContextData]

   if g.cameraPosWatcher.hasChanged or g.windowWatcher.hasChanged:
      let eye = g.cameraPosWatcher.currentValue()
      fine &"Eye value: {cam.eye}"

      CD.hexesInView.clear()
      CD.hexesByCartesianCoord.clear()

      for r in 0 ..< 20:
         for hex in hexRing(eye, r):
            let screenSpace = cam.worldToScreenSpace(GCD.framebufferSize, hex.asCartVec.Vec3f * g.hexSize.float)
            if screenSpace.x >= -1.3 and screenSpace.x <= 1.3 and screenSpace.y >= -1.3 and screenSpace.y <= 1.3:
               CD.hexesInView.incl(hex)
               CD.hexesByCartesianCoord.add(hex)

      CD.hexesByCartesianCoord = CD.hexesByCartesianCoord.sortedByIt(-it.asCartesian.y)
      CD.revision.inc
      fine &"updated culling data to revision {CD.revision}"
