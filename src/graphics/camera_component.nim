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

method initialize(g: CameraComponent, display: DisplayWorld) =
   g.name = "CameraComponent"
   display.attachData(CameraData(camera: g.initialCamera))


method onEvent(g: CameraComponent, display: DisplayWorld, event: Event) =
  if event of UIEvent:
    let event = event.UIEvent
    if not event.consumed:
      display[CameraData].camera.handleEvent(event)

method update(g: CameraComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   let time = glfwGetTime()
   let deltaTime = time - display[CameraData].camera.lastUpdated
   display[CameraData].camera.update(deltaTime / 0.01666666667)
   display[CameraData].camera.lastUpdated = time

   @[]
