import ../engines
import cameras
import ../reflect

type
    CameraComponent = ref object of GraphicsComponent
        initialCamera* : Camera

    CameraData* = object
        camera* : Camera

defineReflection(CameraData)


proc createCameraComponent*(camera : Camera) : GraphicsComponent =
    CameraComponent(
        initialCamera: camera,
        initializePriority: 10,
        eventPriority: -10
    )

method initialize(g : CameraComponent, world : World, curView : WorldView, display : DisplayWorld) =
    display.attachData(CameraData, CameraData(camera : g.initialCamera))

    g.onEvent(UIEvent, evt):
        if not evt.consumed:
            display[CameraData].camera.handleEvent(evt)

method update(g : CameraComponent, world : World, curView : WorldView, display : DisplayWorld, df : float) : seq[DrawCommand] =
    display[CameraData].camera.update(df)

    @[]