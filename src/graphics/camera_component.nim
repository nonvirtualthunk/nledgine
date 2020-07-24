import nimgl/glfw
import ../engines
import cameras
import ../reflect

type
   CameraComponent = ref object of GraphicsComponent
      initialCamera*: Camera

   CameraData* = object
      camera*: Camera

defineDisplayReflection(CameraData)


proc createCameraComponent*(camera: Camera): GraphicsComponent =
   CameraComponent(
       initialCamera: camera,
       initializePriority: 10,
       eventPriority: -10
   )

method initialize(g: CameraComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "CameraComponent"
   display.attachData(CameraData(camera: g.initialCamera))

   g.onEvent(UIEvent, evt):
      if not evt.consumed:
         display[CameraData].camera.handleEvent(evt)

method update(g: CameraComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   let time = glfwGetTime()
   let deltaTime = time - display[CameraData].camera.lastUpdated
   display[CameraData].camera.update(deltaTime / 0.01666666667)
   display[CameraData].camera.lastUpdated = time

   @[]
