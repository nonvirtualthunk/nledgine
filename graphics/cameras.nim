import glm
import ../engines/event
import ../engines/event_types
import ../engines/key_codes
import ../reflect
import ../prelude

type
    CameraKind* {.pure.} = enum
        PixelCamera

    Camera* = object
        case kind : CameraKind
        of PixelCamera: 
            translation : Vec2f
            delta : Vec2f
            scale : int
            initialized : bool

        moveSpeed : float # in pixels / second



proc createPixelCamera*(scale : int) : Camera =
    Camera(
        kind : PixelCamera,
        translation : vec2f(0.0f,0.0f),
        delta : vec2f(0.0f,0.0f),
        scale : 1,
        moveSpeed : 100.0f,
        initialized : true
    )


proc handleEvent*(camera : var Camera, evt : Event) =
    case camera.kind:
    of PixelCamera:
        ifOfType(evt, KeyPress):
            case evt.key:
            of KeyCode.Up: camera.delta.y = 1.0f
            of KeyCode.Down: camera.delta.y = -1.0f
            of KeyCode.Right: camera.delta.x = 1.0f
            of KeyCode.Left: camera.delta.x = -1.0f
            else: discard

        
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

proc modelviewMatrix*(camera : Camera, framebufferSize : Vec2i) : Mat4f =
    case camera.kind:
    of PixelCamera:
        mat4f().scale(camera.scale.float, camera.scale.float, 1.0f).translate(vec3f(camera.translation.x.float, camera.translation.y.float, 0.0f))

proc projectionMatrix*(camera : Camera, framebufferSize : Vec2i) : Mat4f =
    case camera.kind:
    of PixelCamera:
        ortho(0.0f,(float) framebufferSize.x, 0.0f, (float) framebufferSize.y,-100.0f,100.0f)