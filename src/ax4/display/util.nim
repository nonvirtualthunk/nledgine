import worlds
import graphics/camera_component
import graphics/core
import hex
import graphics
import ax4/display/data/mapGraphicsData


proc pixelToHex*(display : DisplayWorld, pixel : Vec2f) : AxialVec =
   let hexSize = mapGraphicsSettings().hexSize.float
   let GCD = display[GraphicsContextData]
   let worldPos = display[CameraData].camera.pixelToWorld(GCD.framebufferSize, GCD.windowSize, pixel)
   worldPos.toAxialVec(hexSize)