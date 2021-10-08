import engines
import prelude
import cameras
import canvas
import main
import application
import camera_component
import cameras
import color

export cameras

type
   GraphicsTestingComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas
      renderFunc: (DisplayWorld, var SimpleCanvas) -> void



method initialize(g: GraphicsTestingComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")

method initialize(g: GraphicsTestingComponent, world: LiveWorld, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")


method update(g: GraphicsTestingComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  g.renderFunc(display, g.canvas)
  g.canvas.swap()
  @[g.canvas.drawCommand(display)]

method update(g: GraphicsTestingComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  g.renderFunc(display, g.canvas)
  g.canvas.swap()
  @[g.canvas.drawCommand(display)]



proc graphicsTestingMain*(renderFunc: (DisplayWorld, var SimpleCanvas) -> void, cam: Camera = createPixelCamera(1)) =
  let comp = GraphicsTestingComponent(
    renderFunc : renderFunc
  )

  main(GameSetup(
     windowSize: vec2i(1600, 1080),
     resizeable: false,
     windowTitle: "Graphics Testing",
     gameComponents: @[],
     graphicsComponents: @[comp, createCameraComponent(cam)],
     clearColor: rgba(0.5f,0.5f,0.5f,1.0f)
  ))
