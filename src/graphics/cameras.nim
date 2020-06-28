import glm
import ../engines/event
import ../engines/event_types
import ../engines/key_codes
import ../reflect
import ../prelude

type
    CameraKind* {.pure.} = enum
        PixelCamera
        WindowingCamera

    Camera* = object
        case kind : CameraKind
        of PixelCamera: 
            translation : Vec2f
            delta : Vec2f
            scale : int 
        of WindowingCamera:
            windowingScale : int

        initialized : bool
        moveSpeed : float # in pixels / second
        lastUpdated* : float



proc createPixelCamera*(scale : int) : Camera =
    Camera(
        kind : PixelCamera,
        translation : vec2f(0.0f,0.0f),
        delta : vec2f(0.0f,0.0f),
        scale : scale,
        moveSpeed : 100.0f,
        initialized : true
    )

proc createWindowingCamera*(scale : int) : Camera =
    Camera(
        kind : WindowingCamera,
        windowingScale : scale,
        initialized : true
    )

proc handleEvent*(camera : var Camera, evt : Event) =
    case camera.kind:
    of PixelCamera:
        ifOfType(evt, KeyPress):
            case evt.key:
            of KeyCode.Up: camera.delta.y = -1.0f
            of KeyCode.Down: camera.delta.y = 1.0f
            of KeyCode.Right: camera.delta.x = -1.0f
            of KeyCode.Left: camera.delta.x = 1.0f
            else: discard
    of WindowingCamera:
        discard

        
proc update*(camera : var Camera, df : float) =
    case camera.kind:
    of PixelCamera:
        if not camera.initialized:
            camera.scale = 1
            camera.moveSpeed = 100.0f
            camera.initialized = true

        if not isKeyDown(KeyCode.Up) and not isKeyDown(KeyCode.Down):
            camera.delta.y = 0.0f
        if not isKeyDown(KeyCode.Left) and not isKeyDown(KeyCode.Right):
            camera.delta.x = 0.0f

        camera.translation += camera.delta * (camera.moveSpeed * 0.016666667f * df)
    of WindowingCamera:
        if not camera.initialized:
            camera.windowingScale = 1
            camera.initialized = true

proc modelviewMatrix*(camera : Camera) : Mat4f =
    case camera.kind:
    of PixelCamera:
        mat4f().scale(camera.scale.float, camera.scale.float, 1.0f).translate(vec3f(camera.translation.x.float, camera.translation.y.float, 0.0f))
    of WindowingCamera:
        mat4f().scale(camera.windowingScale.float, camera.windowingScale.float, 1.0f)

proc projectionMatrix*(camera : Camera, framebufferSize : Vec2i) : Mat4f =
    case camera.kind:
    of PixelCamera:
        ortho((float32) -framebufferSize.x/2,(float32) framebufferSize.x/2, (float32) -framebufferSize.y/2, (float32) framebufferSize.y/2,-100.0f,100.0f)
    of WindowingCamera:
        ortho((float32) 0.0f, (float32) framebufferSize.x, (float32) framebufferSize.y, 0.0f, -100.0f, 100.0f)

proc eye*(camera : Camera) : Vec3f =
    case camera.kind:
    of PixelCamera:
        vec3f(-camera.translation.x, -camera.translation.y, 0)
    of WindowingCamera:
        vec3f(0,0,0)


proc worldToScreenSpace*(camera : Camera, framebufferSize : Vec2i, worldv : Vec3f) : Vec3f =
    # let projected = (vec4(worldV, 1.0f) * camera.modelviewMatrix() * camera.projectionMatrix(framebufferSize))
    let projected = (camera.projectionMatrix(framebufferSize) * camera.modelviewMatrix() * vec4(worldV, 1.0f))
    vec3f(projected.x / projected.w, projected.y / projected.w, projected.z / projected.w)

proc worldToPixel*(camera : Camera, framebufferSize : Vec2i, windowSize : Vec2i, worldv : Vec3f) : Vec2f =
    let screenSpace = worldToScreenSpace(camera, framebufferSize, worldv)
    vec2f(screenSpace.x * windowSize.x.float, screenSpace.y * windowSize.y.float)

proc pixelToWorld*(camera : Camera, framebufferSize : Vec2i, windowSize : Vec2i, pixel : Vec2f) : Vec3f =
    let screenSpace = vec4f((pixel.x / windowSize.x.float) * 2.0 - 1.0, (1.0 - (pixel.y / windowSize.y.float)) * 2.0 - 1.0, 0.0, 1.0)
    let unprojected = (camera.projectionMatrix(framebufferSize) * camera.modelviewMatrix()).inverse * screenSpace
    vec3f(unprojected.x / unprojected.w, unprojected.y / unprojected.w, unprojected.z / unprojected.w)


# proc pixelToWorld*(camera : Camera, framebufferSize : Vec2i, worldv : Vec3f) : Vec3f =
#     (camera.projectionMatrix(framebufferSize) * camera.modelviewMatrix() * vec4(worldV, 0.0f)).xyz