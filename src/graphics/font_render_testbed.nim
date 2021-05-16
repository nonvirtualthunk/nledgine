import main
import application
import glm
import engines
import prelude
import graphics
import tables
import noto
import resources
import graphics/canvas
import graphics/images
import graphics/camera_component
import fonts
import config
import options
import noto
import pixie/fonts as pfonts
import vmath
import windowingsystem/rich_text_layout
import windowingsystem/rich_text
import windowingsystem/windowing_rendering
import arxmath
import noto

type
   DrawQuadComponent = ref object of GraphicsComponent
      canvas: SimpleCanvas

method initialize(g: DrawQuadComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")



  echo "initialized"

method update(g: DrawQuadComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =

  let tf = typeface("pf_ronda_seven.ttf")

  let font = tf.font(32)

  let span = newSpan("This is a test of how well kerning works", font)
  let arrangement = typeset(@[span])

  var qb = QuadBuilder()

  for spanIndex, (start, stop) in arrangement.spans:
    let arFont = arrangement.fonts[spanIndex]
    for runeIndex in start .. stop:
      let img = font.glyphImage(arrangement.runes[runeIndex])
      # img.writeToFile(&"/tmp/out_rune_{runeIndex}.png")

      qb.dimensions = vec2f(img.dimensions.x, img.dimensions.y * -1)
      qb.position = vec3f(arrangement.positions[runeIndex].x, arrangement.positions[runeIndex].y, 0.0f)
      qb.texture = img
      qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
      qb.drawTo(g.canvas)


  let textLayout = layout(richText("This is a test of how well rich text works"), 32, rect(vec2i(0,0), vec2i(1000,500)), 1, RichTextRenderSettings(defaultFont: some(tf)))

  for quad in textLayout.quads:
    let img = quad.image
    case quad.shape.kind:
      of WShapeKind.Rect:
        qb.dimensions = vec2f(quad.shape.dimensions.x, quad.shape.dimensions.y * -1)
        qb.position = vec3f(quad.shape.position.x, quad.shape.position.y + 100, 0.0f)
        qb.texture = img
        qb.color = rgba(0.0f,0.0f,0.0f,1.0f)
        qb.drawTo(g.canvas)
      else:
        info "unsupported wquad shape type"

  g.canvas.swap()

  @[g.canvas.drawCommand(display)]



main(GameSetup(
   windowSize: vec2i(1440, 900),
   resizeable: false,
   windowTitle: "Font Rendering Test",
   gameComponents: @[],
   graphicsComponents: @[DrawQuadComponent(), createCameraComponent(createPixelCamera(1))],
   clearColor: rgba(0.5f,0.5f,0.5f,1.0f)
))
