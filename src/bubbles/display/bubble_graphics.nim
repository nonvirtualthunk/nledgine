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
    bubbleImage: Image

  NumberGraphics* = object
    numerals*: array[10, Image]


defineDisplayReflection(NumberGraphics)


proc bubbleImageLayers*(b: ref Bubble): seq[ImageLayer] =
  if b.color == BubbleColor.Red:
    result.add(ImageLayer(image: image("bubbles/images/bubble/red_bubble.png"), color: White))
  elif b.color == BubbleColor.Blue:
    result.add(ImageLayer(image: image("bubbles/images/bubble/blue_bubble.png"), color: White))
  else:
    result.add(ImageLayer(image: image("bubbles/images/bubble_2.png"), color: rgba(b.color)))
  for c in b.secondaryColors:
    result.add(ImageLayer(image: image("bubbles/images/bicolor_bubble_ring.png"), color: rgba(c)))
  if b.image != nil:
    result.add(ImageLayer(image: b.image, color: White))


method initialize(g: BubbleGraphics, world: LiveWorld, display: DisplayWorld) =
  g.canvas = createSimpleCanvas("shaders/simple")
  # display[WindowingSystem].desktop.background.draw = bindable(false)

  var ng = new NumberGraphics
  let f = font("goethe.ttf").font(20)
  for i in 0 ..< 10:
    let baseImg = f.glyphImage(toRunes(&"{i}")[0]).trimmed()
    baseImg.flipY()
    baseImg.writeToFile(&"/tmp/numeral_base_{i}.png")
    let img = createImage(vec2i(baseImg.width + 2, baseImg.height + 2))
    copyFrom(img, baseImg, vec2i(1,1), vec2i(0,0), baseImg.dimensions)
    for x in 0 ..< img.width:
      for y in 0 ..< img.height:
        if img[x,y,3] == 0:
          if (x > 0 and img[x-1,y,0] > 0) or (y > 0 and img[x,y-1,0] > 0) or (x < img.width - 1 and img[x+1,y,0] > 0) or (y < img.height - 1 and img[x,y+1,0] > 0):
            img[x,y] = rgba(0,0,0,255)


    ng.numerals[i] = img
    ng.numerals[i].writeToFile(&"/tmp/numeral_{i}.png")
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


  for imgLayer in bubbleImageLayers(b):
    drawQuad(g, imgLayer.image.asImage, imgLayer.color, vec3f(pos, 0.0f), forward, ortho, vec2f(imgLayer.image.asImage.dimensions))

  let numeral = g.numerals[b.number]
  let numeralSizeM = 30 div numeral.dimensions.y
  let numeralSize = numeral.dimensions * numeralSizeM
  qb.position = vec3f(pos.x, pos.y + 2, 0.0f32)
  qb.texture = numeral
  qb.color = b.numeralColor
  qb.dimensions = vec2f(numeralSize)
  qb.centered()
  qb.drawTo(g.canvas)

  if b.modifiers.nonEmpty and b.image.isNil:
    qb.position = vec3f(pos, 0.0f)
    qb.color = rgba(190,190,190,255)
    qb.dimensions = vec2f(12.0f,12.0f)
    qb.centered()

    let d = b.radius - 8.0f
    var i = 0
    for m in b.modifiers:
      qb.position = case i:
        of 0: vec3f(pos + vec2f(0.0f,-d), 0.0f)
        of 1: vec3f(pos + vec2f(d, 0.0f), 0.0f)
        of 2: vec3f(pos + vec2f(0.0f, d), 0.0f)
        else: vec3f(pos + vec2f(-d, 0.0f), 0.0f)

      qb.texture = case m.kind:
        of BubbleModKind.Power: image("bubbles/images/bubble_modifiers/x2.png")
        of BubbleModKind.Potency: image(&"bubbles/images/bubble_modifiers/plus_{max(m.number, 1)}.png")
        of BubbleModKind.Juggernaut: image(&"bubbles/images/bubble_modifiers/juggernaut.png")
        of BubbleModKind.Chain: image(&"bubbles/images/bubble_modifiers/chain.png")
        of BubbleModKind.Chromophilic: image(&"bubbles/images/bubble_modifiers/chromophilic.png")
        of BubbleModKind.Chromophobic: image(&"bubbles/images/bubble_modifiers/chromophobic.png")
        of BubbleModKind.Exchange: image(&"bubbles/images/bubble_modifiers/exchange.png")
        of BubbleModKind.Exhaust: image(&"bubbles/images/bubble_modifiers/exhaust.png")
        else: continue
      i.inc

      qb.drawTo(g.canvas)


method update(g: BubbleGraphics, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =

  var qb : QuadBuilder

  let aimDot = image("bubbles/images/aim_dot.png")

  let magazineVectors = @[vec2f(-0.5,-0.5).normalize, vec2f(0.0,-1.0f), vec2f(0.5,-0.5).normalize]
  for stage in activeStages(world):
    let sd = stage[Stage]
    for mi in 0 ..< sd.magazines.len:
      let magazine = sd.magazines[mi]
      if magazine.nonEmpty:
        var indexOffset = 0
        if magazine == sd.activeMagazine:
          indexOffset = 1
          drawBubble(g, world, qb, magazine.bubbles[0], some(sd.cannon[Cannon].position))

        for i in indexOffset ..< magazine.bubbles.len:
          drawBubble(g, world, qb, magazine.bubbles[i], some(sd.cannon[Cannon].position + magazineVectors[mi] * 48.0f * (i - indexOffset + 2).float32))

    for bubble in sd.bubbles:
      drawBubble(g, world, qb, bubble, none(Vec2f))

    let cannon = sd.cannon
    let c = cannon[Cannon]

    let baseImg = image("bubbles/images/cannon_base.png")
    let turretImg = image("bubbles/images/cannon_turret.png")
    let feedImg = image("bubbles/images/cannon_feed.png")


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

    let feedVec = magazineVectors[sd.activeMagazineIndex]
    let feedCenter = vec3f(c.position + feedVec * (baseImg.height.float32 * 0.5f32 + feedImg.height.float32 * 0.3f32), 0.0f32)
    let feedOrtho = vec3f(feedVec,0.0f32) * -1.0f32
    let feedForward = feedOrtho.cross(vec3f(0.0f,0.0f,1.0f))
    drawQuad(g, feedImg, rgba(255,255,255,255), feedCenter, feedForward, feedOrtho, vec2f(feedImg.dimensions))

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
    let rawDir = v.normalizeSafe
    let dir = vec2f(rawDir.x, max(rawDir.y, 0.2f)).normalize
    cd.direction = dir
    cd.currentVelocityScale = (v.lengthSafe / 500.0f).max(0.25f).min(1.0f)

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
        of KeyCode.Left:
          for stage in activeStagesD(world):
            stage.activeMagazine = stage.magazines[(stage.activeMagazineIndex + stage.magazines.len - 1) mod stage.magazines.len]
        of KeyCode.Right:
          for stage in activeStagesD(world):
            stage.activeMagazine = stage.magazines[(stage.activeMagazineIndex + stage.magazines.len + 1) mod stage.magazines.len]
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