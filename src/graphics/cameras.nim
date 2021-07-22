import glm
import engines/event
import engines/event_types
import engines/key_codes
import reflect
import prelude
import noto
import options
import atomics


var CameraIDCounter*: Atomic[int]

type
  CameraKind* {.pure.} = enum
    PixelCamera
    WindowingCamera

  CameraMovement* = object
    targetLocation*: Vec2f
    overrideManualInput*: bool
    speedMultiplier*: float


  Camera* = object
    id*: int
    case kind: CameraKind
    of PixelCamera:
      translation: Vec2f
      delta: Vec2f
      scale: int
    of WindowingCamera:
      windowingScale: int

    initialized: bool
    moveSpeed: float # in pixels / second
    lastUpdated*: float
    useWasd*: bool

    # Camera movement
    cameraMovement*: Option[CameraMovement]



# proc `==`*(a,b: Camera): bool =
#   if a.id == b.id and
#       a.kind == b.kind and
#       a.initialized == b.initialized and
#       a.moveSpeed == b.moveSpeed and
#       a.lastUpdated == b.lastUpdated and
#       a.useWasd == b.useWasd and
#       a.cameraMovement == b.cameraMovement:
#     case a.kind:
#       of CameraKind.PixelCamera:
#         a.translation == b.translation and
#         a.delta == b.delta and
#         a.scale == b.scale
#       of CameraKind.WindowingCamera:
#         a.windowingScale == b.windowingScale



proc createPixelCamera*(scale: int, translation : Vec2f = vec2f(0.0f,0.0f)): Camera =
  Camera(
     kind: PixelCamera,
     id: CameraIDCounter.fetchAdd(1)+1,
     translation: translation,
     delta: vec2f(0.0f, 0.0f),
     scale: scale,
     moveSpeed: 300.0f,
     initialized: true,
     useWasd: true
  )

proc withMoveSpeed*(cam: Camera, moveSpeed: float): Camera =
  result = cam
  result.moveSpeed = moveSpeed

proc createWindowingCamera*(scale: int): Camera =
  Camera(
     kind: WindowingCamera,
     id: CameraIDCounter.fetchAdd(1)+1,
     windowingScale: scale,
     initialized: true
  )

proc handleEvent*(camera: var Camera, evt: Event) =
  case camera.kind:
  of PixelCamera:
    ifOfType(KeyPress, evt):
      case evt.key:
      of KeyCode.Up: camera.delta.y = -1.0f
      of KeyCode.Down: camera.delta.y = 1.0f
      of KeyCode.Right: camera.delta.x = -1.0f
      of KeyCode.Left: camera.delta.x = 1.0f
      of KeyCode.W:
        if camera.useWasd: camera.delta.y = -1.0f
      of KeyCode.S:
        if camera.useWasd: camera.delta.y = 1.0f
      of KeyCode.D:
        if camera.useWasd: camera.delta.x = -1.0f
      of KeyCode.A:
        if camera.useWasd: camera.delta.x = 1.0f
      else: discard
  of WindowingCamera:
    discard


proc update*(camera: var Camera, df: float) =
  case camera.kind:
  of PixelCamera:
    if not camera.initialized:
      camera.scale = 1
      camera.moveSpeed = 100.0f
      camera.initialized = true

    if not isKeyDown(KeyCode.Up) and not isKeyDown(KeyCode.Down) and (not camera.useWasd or not isKeyDown(KeyCode.W)) and (not camera.useWasd or not isKeyDown(KeyCode.S)):
      camera.delta.y = 0.0f
    if not isKeyDown(KeyCode.Left) and not isKeyDown(KeyCode.Right) and (not camera.useWasd or not isKeyDown(KeyCode.A)) and (not camera.useWasd or not isKeyDown(KeyCode.D)):
      camera.delta.x = 0.0f

    # if there is explicit movement from the user, ignore the camera animation unless it overrides that
    if camera.delta.x != 0.0f or camera.delta.y != 0.0f:
      if camera.cameraMovement.isSome and not camera.cameraMovement.get.overrideManualInput:
        camera.cameraMovement = none(CameraMovement)

    if camera.cameraMovement.isSome:
      let movement = camera.cameraMovement.get
      let delta = (movement.targetLocation * -1.0f) - camera.translation
      var speed = 1.0f
      if movement.speedMultiplier != 0.0f:
        speed = movement.speedMultiplier

      if delta.lengthSafe < camera.moveSpeed * 0.016666667f * df * speed:
        camera.translation = movement.targetLocation * -1.0f
        camera.delta = vec2f(0.0f, 0.0f)
      else:
        camera.delta = delta.normalizeSafe * speed


    camera.translation += camera.delta * (camera.moveSpeed * 0.016666667f * df)
  of WindowingCamera:
    if not camera.initialized:
      camera.windowingScale = 1
      camera.initialized = true

proc modelviewMatrix*(camera: Camera): Mat4f =
  case camera.kind:
  of PixelCamera:
    mat4f().scale(camera.scale.float, camera.scale.float, 1.0f).translate(vec3f(camera.translation.x.float, camera.translation.y.float, 0.0f))
  of WindowingCamera:
    mat4f().scale(camera.windowingScale.float, camera.windowingScale.float, 1.0f)

proc projectionMatrix*(camera: Camera, framebufferSize: Vec2i): Mat4f =
  case camera.kind:
  of PixelCamera:
    ortho((float32) -framebufferSize.x/2, (float32)framebufferSize.x/2, (float32) -framebufferSize.y/2, (float32)framebufferSize.y/2, -100.0f, 100.0f)
  of WindowingCamera:
    ortho((float32)0.0f, (float32)framebufferSize.x, (float32)framebufferSize.y, 0.0f, -100.0f, 100.0f)

proc eye*(camera: Camera): Vec3f =
  case camera.kind:
  of PixelCamera:
    vec3f(-camera.translation.x, -camera.translation.y, 0)
  of WindowingCamera:
    vec3f(0, 0, 0)

proc moveTo*(camera: var Camera, to: Vec3f) =
  case camera.kind:
  of PixelCamera:
    camera.translation.x = to.x * -1
    camera.translation.y = to.y * -1
  of WindowingCamera:
    warn &"Moving a WindowingCamera is not currently supported"

proc withEye*(camera: Camera, eye: Vec3f) : Camera =
  result = camera
  moveTo(result, eye)

proc changeScale*(camera : var Camera, delta: int) =
  case camera.kind:
   of CameraKind.PixelCamera:
    camera.scale = max(1, camera.scale + delta)
   of CameraKind.WindowingCamera:
    camera.windowingScale = max(1, camera.windowingScale + delta)




proc worldToScreenSpace*(camera: Camera, framebufferSize: Vec2i, worldv: Vec3f): Vec3f =
  # let projected = (vec4(worldV, 1.0f) * camera.modelviewMatrix() * camera.projectionMatrix(framebufferSize))
  let projected = (camera.projectionMatrix(framebufferSize) * camera.modelviewMatrix() * vec4(worldV, 1.0f))
  vec3f(projected.x / projected.w, projected.y / projected.w, projected.z / projected.w)

proc worldToPixel*(camera: Camera, framebufferSize: Vec2i, windowSize: Vec2i, worldv: Vec3f): Vec2f =
  let screenSpace = worldToScreenSpace(camera, framebufferSize, worldv)
  vec2f(screenSpace.x * windowSize.x.float, screenSpace.y * windowSize.y.float)

proc pixelToWorld*(camera: Camera, framebufferSize: Vec2i, windowSize: Vec2i, pixel: Vec2f): Vec3f =
  let screenSpace = vec4f((pixel.x / windowSize.x.float) * 2.0 - 1.0, (1.0 - (pixel.y / windowSize.y.float)) * 2.0 - 1.0, 0.0, 1.0)
  let unprojected = (camera.projectionMatrix(framebufferSize) * camera.modelviewMatrix()).inverse * screenSpace
  vec3f(unprojected.x / unprojected.w, unprojected.y / unprojected.w, unprojected.z / unprojected.w)


proc effectivelyEquivalent*(a,b: Camera) : bool =
  a.modelviewMatrix == b.modelviewMatrix and a.projectionMatrix(vec2i(100,100)) == b.projectionMatrix(vec2i(100,100))

# proc pixelToWorld*(camera : Camera, framebufferSize : Vec2i, worldv : Vec3f) : Vec3f =
#    (camera.projectionMatrix(framebufferSize) * camera.modelviewMatrix() * vec4(worldV, 0.0f)).xyz
