import engines
import graphics/canvas
import graphics/color
import options
import prelude
import reflect
import resources
import graphics/images
import glm
import tables
import game/library
import worlds
import noto
import windowingsystem/windowingsystem
import graphics/camera_component
import graphics/cameras
import graphics/fonts
import core
import worlds/identity
import arxmath
import math
import core/metrics
import nimgl/[glfw, opengl]
import graphics/isometric
import game/grids
import bubbles/game/entities
import bubbles/game/logic
import graphics/texture_block
import unicode

type
  BubbleGraphics* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    mousePos: Vec2f
    numerals: array[10, Image]

  NumberGraphics* = object
    numerals*: array[10, Image]


defineDisplayReflection(NumberGraphics)


method initialize(g: BubbleGraphics, world: LiveWorld, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")
  # display[WindowingSystem].desktop.background.draw = bindable(false)

  var ng = new NumberGraphics
  let f = font("goethe.ttf").font(20)
  for i in 0 ..< 10:
    ng.numerals[i] = f.glyphImage(toRunes(&"{i}")[0]).trimmed()
    ng.numerals[i].flipY()
    # ng.numerals[i].writeToFile(&"/tmp/numeral_{i}.png")
  display.attachDataRef(ng)
  g.numerals = ng.numerals



proc drawQuad(g: BubbleGraphics, img: Image, color: RGBA, position: Vec3f, forward: Vec3f, ortho: Vec3f, dimensions: Vec2f) =
  let tc = g.canvas.texture[img]
  var vi = g.canvas.vao.vi
  var ii = g.canvas.vao.ii
  for i in 0 ..< 4:
    let vt = g.canvas.vao[vi+i]
    vt.vertex = position +
                  forward * (CenteredUnitSquareVertices[i].x * dimensions.x) +
                  ortho * (CenteredUnitSquareVertices[i].y * dimensions.y)
    vt.color = color
    vt.texCoords = tc[i]
  g.canvas.vao.addIQuad(ii,vi)


proc drawBubble(g: BubbleGraphics, world: LiveWorld, qb: var QuadBuilder, bubble: Entity, posOverride: Option[Vec2f]) =
  let b = bubble[Bubble]

  let pos = posOverride.get(b.position)
  # let forward = (vec3f(pos, 0.0f) - vec3f(-400f,0.0f, 0.0f)).normalizeSafe
  # let ortho = forward.cross(vec3f(0.0f,0.0f,1.0f))
  let forward = vec3f(1.0f,0.0f,0.0f)
  let ortho = vec3f(0.0f,1.0f,0.0f)

  drawQuad(g, image("bubbles/images/bubble_2.png"), rgba(b.color), vec3f(pos, 0.0f), forward, ortho, vec2f(b.radius * 2.0f, b.radius * 2.0f))

  let numeral = g.numerals[b.number]
  let numeralSizeM = 24 div numeral.dimensions.y
  let numeralSize = numeral.dimensions * numeralSizeM
  qb.position = vec3f(pos.x, pos.y + 2, 0.0f32)
  qb.texture = numeral
  qb.color = rgba(190,190,190,255)
  qb.dimensions = vec2f(numeralSize)
  qb.centered()
  qb.drawTo(g.canvas)


method update(g: BubbleGraphics, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =

  var qb : QuadBuilder

  let aimDot = image("bubbles/images/aim_dot.png")

  for stage in activeStages(world):
    let sd = stage[Stage]
    if sd.magazine.nonEmpty:
      drawBubble(g, world, qb, sd.magazine[0], some(sd.cannon[Cannon].position))
      for i in 1 ..< sd.magazine.len:
        drawBubble(g, world, qb, sd.magazine[i], some(sd.cannon[Cannon].position + vec2f(48.0f, -48.0f) + vec2f(48.0f * i.float32,0.0f)))

    for bubble in sd.bubbles:
      drawBubble(g, world, qb, bubble, none(Vec2f))

    let cannon = sd.cannon
    let c = cannon[Cannon]

    let baseImg = image("bubbles/images/cannon_base.png")
    let turretImg = image("bubbles/images/cannon_turret.png")


    let vel = (c.maxVelocity * c.currentVelocityScale).int
    for dv in countup(50, vel, 50):
      let p = vec2i(c.position + c.direction * (dv.float32 + 50.0f32) * 0.5f32)
      qb.position = vec3f(p.x, p.y, 0)
      qb.color = rgba(255,255,255,255)
      qb.texture = aimDot
      qb.centered()
      qb.dimensions = vec2f(aimDot.dimensions)
      qb.drawTo(g.canvas)



    let turretCenter = vec3f(c.position + c.direction * (baseImg.dimensions.y.float32 * 0.5f32), 0.0f32)
    let turretOrtho = vec3f(c.direction,0.0f32)
    let turretForward = turretOrtho.cross(vec3f(0.0f,0.0f,1.0f))
    drawQuad(g, turretImg, rgba(255,255,255,255), turretCenter, turretForward, turretOrtho, vec2f(turretImg.dimensions))

    qb.position = vec3f(c.position, 0.0f)
    qb.color = rgba(255,255,255,255)
    qb.texture = baseImg
    qb.dimensions = vec2f(qb.texture.dimensions)
    qb.centered()
    qb.drawTo(g.canvas)


  g.canvas.swap()
  @[g.canvas.drawCommand(display)]



proc updateCannonDirection(g: BubbleGraphics, world: LiveWorld, display: DisplayWorld) =
  let GCD = display[GraphicsContextData]
  for stage in activeStages(world):
    let sd = stage[Stage]
    let cannon = sd.cannon
    let cd = cannon[Cannon]

    let worldPos = display[CameraData].camera.pixelToWorld(GCD.framebufferSize, GCD.windowSize, g.mousePos)
    let v = worldPos.xy - cd.position
    cd.direction = v.normalizeSafe
    cd.currentVelocityScale = (v.lengthSafe / 800.0f).max(0.25f).min(1.0f)

method onEvent*(g: BubbleGraphics, world: LiveWorld, display: DisplayWorld, event: Event) =
  let GCD = display[GraphicsContextData]

  matcher(event):
    extract(KeyRelease, key):
      case key:
        of KeyCode.Z:
          display[CameraData].camera.changeScale(+1)
          display.addEvent(CameraChangedEvent())
        of KeyCode.X:
          display[CameraData].camera.changeScale(-1)
          display.addEvent(CameraChangedEvent())
        else:
          discard
    extract(MouseMove, position):
      g.mousePos = position
      updateCannonDirection(g, world, display)
    extract(MouseDrag, position):
      g.mousePos = position
      updateCannonDirection(g, world, display)
    extract(MouseRelease, position):
      for stage in activeStages(world):
        fireBubble(world, stage, stage[Stage].cannon)