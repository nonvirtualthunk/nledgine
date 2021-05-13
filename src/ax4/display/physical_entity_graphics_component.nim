import engines
import graphics
import prelude
import tables
import ax4/game/map
import hex
import graphics/cameras
import graphics/camera_component
import ax4/game/characters
import ax4/display/data/mapGraphicsData
import graphics/canvas
import core
import ax4/game/resource_pools
import ax4/game/enemies
import game/library
import options
import ax4/game/enemies
import patty
import ax4/game/effect_types
import ax4/game/flags
import ax4/display/ax_display_events
import reflect
import ax4/display/tactical_ui_component
import graphics/taxonomy_display
import ax4/game/vision
import sets
import ax4/game/targeting_types
import algorithm
import noto

type
   PhysicalEntityGraphicsComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas
      uiCanvas: SimpleCanvas
      worldWatcher: Watcher[WorldEventClock]
      curFlagDisplay: Table[Entity, float]
      hexSize: float
      mousedOverHex: Option[AxialVec]


variantp PreviewElement:
   Image(image: string)
   Text(text: string)
   Spacing

method initialize(g: PhysicalEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "PhysicalEntityGraphicsComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.uiCanvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.canvas.drawOrder = 10
   g.worldWatcher = watcher(() => curView.currentTime())
   g.hexSize = mapGraphicsSettings().hexSize.float


proc entityBasePos(g: PhysicalEntityGraphicsComponent, physical: ref Physical): Vec3f =
   let cart = (physical.position.asCartVec + physical.offset) * g.hexSize
   let hexHeight = g.hexSize.hexHeight
   cart.Vec3f - vec3f(0.0f, hexHeight * 0.4f, 0.0f)



proc drawFlagUI(g: PhysicalEntityGraphicsComponent, view: WorldView, display: DisplayWorld, entity: Entity, percent: float) =
   withView(view):
      let physical = entity[Physical]
      let pos = g.entityBasePos(physical)

      var iconPos = pos - vec3f(0.0f, 16.0f, 0.0f)

      var qb = QuadBuilder()
      qb.centered
      qb.color = rgba(1.0, 1.0, 1.0, percent)

      for flag, value in flagValues(view, entity):
         if value > 0:
            let lib = library(TaxonomyDisplay)
            let tdisp = lib.get(flag)
            if tdisp.isSome and tdisp.get.icon.isSome:
               qb.texture = tdisp.get.icon.get
            else:
               qb.texture = image("ax4/images/icons/question_mark_small_outlined.png")

            qb.position = iconPos
            qb.dimensions = vec2f(24.0f, 24.0f)

            qb.drawTo(g.uiCanvas)
            iconPos.x += qb.dimensions.x - 8

            let numStr = $value
            for c in numStr:
               let numImg = image(&"ax4/images/ui/numerals/{value}_outlined.png")
               qb.position = iconPos - vec3f(0.0f, 8.0f, 0.0f)
               qb.dimensions = vec2f(numImg.dimensions) * 0.5
               qb.texture = numImg
               qb.drawTo(g.uiCanvas)
               iconPos.x += qb.dimensions.x
            iconPos.x += 10




proc render(g: PhysicalEntityGraphicsComponent, view: WorldView, display: DisplayWorld) =
   let vertFrame = image("ax4/images/ui/vertical_bar_frame.png")
   let vertContent = image("ax4/images/ui/vertical_bar_content.png")
   let stamFrame = image("ax4/images/ui/stamina_frame.png")
   let stamContent = image("ax4/images/ui/stamina_content.png")

   let stamina = taxon("resource pools", "stamina points")

   withView(view):
      var vision = playerVisionContext(view)

      let hexSize = g.hexSize
      let hexHeight = hexSize.hexHeight

      var qb = QuadBuilder()
      qb.origin = vec2f(0.5f, 0.0f)

      var uiqb = QuadBuilder()
      let monsterLib = library(MonsterClass)

      var toDraw: seq[(AxialVec, Entity)]
      for physEnt in view.entitiesWithData(Physical):
         let physical = physEnt[Physical]
         if vision.isVisible(physical.position):
            toDraw.add((physical.position, physEnt))

      let sortedEnts = toDraw.sortedByIt((it[0].asCartVec.y * 1000.0f) * -1)
      for (pos, physEnt) in sortedEnts:
         let physical = physEnt[Physical]
         let entBasePos = g.entityBasePos(physical)

         if physEnt.hasData(Character):
            if physEnt[Character].dead: continue

            var charImg = if physEnt.id mod 2 == 0:
               image("ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_38.png")
            else:
               image("ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_39.png")

            if physEnt.hasData(Monster):
               let monster = physEnt[Monster]
               let mc = monsterLib[monster.monsterClass]
               charImg = mc.images[permute(physEnt.id).abs mod mc.images.len]
            let scale = ((hexSize * 0.65).int div charImg.dimensions.x).float

            qb.texture = charImg
            qb.position = entBasePos
            qb.dimensions = vec2f(charImg.dimensions) * scale
            qb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
            qb.drawTo(g.canvas)

            let barScale = ((hexHeight * 0.5).int div vertFrame.dimensions.y)
            let barHeight = vertFrame.dimensions.y * barScale

            let cd = physEnt.data(Character)
            let maxHP = cd.health.maxValue
            let curHP = cd.health.currentValue
            let pcntHP = curHP.float / maxHP.max(1).float

            let healthBarPos = entBasePos + vec3f(((charImg.dimensions.x div 2).float * scale + 0.0f), 0.0f, 0.0f)
            let healthBarDim = vec2f(vertFrame.dimensions) * barScale.float
            uiqb.texture = vertFrame
            uiqb.position = healthBarPos
            uiqb.dimensions = healthBarDim
            uiqb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
            uiqb.drawTo(g.canvas)

            let maxContentHeight = barHeight - barScale * 2
            uiqb.position += vec3f(barScale.float, barScale.float, 0.0f)
            uiqb.texture = vertContent
            uiqb.color = rgba(0.8f, 0.1f, 0.1f, 1.0f)
            uiqb.dimensions = vec2f(vertContent.dimensions.x.float * barScale.float, maxContentHeight.float * pcntHP)
            uiqb.drawTo(g.canvas)
            var maxBarY = healthBarPos.y + healthBarDim.y

            if physEnt.hasData(ResourcePools):
               let rsrc = physEnt[ResourcePools]
               let currentStamina = rsrc.currentResourceValue(stamina)
               let maxStamina = rsrc.maximumResourceValue(stamina)

               let staminaBarPos = healthBarPos + vec3f(healthBarDim.x - barScale.float, 0.0f, 0.0f)
               uiqb.position = staminaBarPos
               uiqb.dimensions = vec2f(stamFrame.dimensions) * barScale.float
               for i in 0 ..< maxStamina:
                  uiqb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
                  uiqb.texture = stamFrame
                  uiqb.drawTo(g.canvas)
                  if i < currentStamina:
                     uiqb.color = rgba(0.1f, 0.7f, 0.2f, 1.0f)
                     uiqb.texture = stamContent
                     uiqb.drawTo(g.canvas)
                  uiqb.position.y += uiqb.dimensions.y - barScale.float
                  maxBarY = max(maxBarY, uiqb.position.y)


            let healthString = &"{curHP}/{maxHP}"
            var healthTextPos = vec3f(healthBarPos.x - 12.0f, maxBarY, 0.0f)
            uiqb.color = rgba(0.8f, 0.1f, 0.1f, 1.0f)
            for c in healthString:
               let img = if c == '/':
                     image(&"ax4/images/ui/numerals/slash_outlined.png")
                  else:
                     image(&"ax4/images/ui/numerals/{c}_outlined.png")
               uiqb.position = healthTextPos
               uiqb.texture = img
               uiqb.dimensions = vec2f(img.dimensions)
               healthTextPos.x += uiqb.dimensions.x
               uiqb.drawTo(g.canvas)

            if physEnt.hasData(Monster):
               var mqb = QuadBuilder()
               let monster = physEnt[Monster]
               let mc = monsterLib[monster.monsterClass]

               var previewElements: seq[PreviewElement]
               if monster.nextAction.isSome:
                  let actionKey = monster.nextAction.get
                  let action = mc.actions[actionKey]
                  var first = true
                  for monsterEffect in action.effects:
                     if not first:
                        previewElements.add(Spacing())

                     let effect = monsterEffect.effect
                     case effect.kind:
                     of GameEffectKind.Move:
                        previewElements.add(Image("ax4/images/icons/monster_move.png"))
                        previewElements.add(Text($effect.moveRange))
                     of GameEffectKind.SimpleAttack:
                        previewElements.add(Text(effect.attack.accuracy.toSignedString))
                        previewElements.add(Image("ax4/images/icons/piercing.png"))
                        previewElements.add(Spacing())
                        let (minDmg, maxDmg) = effect.attack.damage.damageRange
                        previewElements.add(Text(&"{minDmg}-{maxDmg}"))
                     of GameEffectKind.ChangeFlag:
                        let buffing = effect.flag.isA(taxon("flags", "positive flag"))
                        if buffing:
                           previewElements.add(Image("ax4/images/icons/buffing_16.png"))
                        else:
                           previewElements.add(Image("ax4/images/icons/debuffing_16.png"))
                        for filter in monsterEffect.target.filters.expand:
                           match filter:
                              InRange(minRange, maxRange):
                                 previewElements.add(Image("ax4/images/icons/range_16.png"))
                                 previewElements.add(Text($maxRange))
                              _: discard
                     else:
                        discard
                     first = false
               else:
                  previewElements.add(Image("ax4/images/icons/question_mark_small_outlined.png"))

               var images: seq[(Image, int)]

               var spacingWidth = 0
               for elem in previewElements:
                  match elem:
                     Image(img):
                        images.add((image(img), 1))
                     Text(text):
                        for c in text:
                           images.add((image(&"ax4/images/ui/numerals/{c}_outlined.png"), 1))
                     Spacing():
                        images.add((nil, 1))

               var totalWidth = 0
               for img in images:
                  if img[0] == nil:
                     totalWidth += 8
                  else:
                     totalWidth += img[0].dimensions.x * img[1]

               mqb.position = entBasePos + vec3f(totalWidth.float * -0.5f, charImg.dimensions.y.float * scale, 0.0f)
               mqb.color = White

               for img in images:
                  if img[0] != nil:
                     mqb.texture = img[0]
                     mqb.dimensions = vec2f(img[0].dimensions.x*img[1], img[0].dimensions.y*img[1])
                     mqb.drawTo(g.canvas)

                     mqb.position.x += mqb.dimensions.x
                  else:
                     mqb.position.x += 8

      g.canvas.swap()


proc updateFlagUI(g: PhysicalEntityGraphicsComponent, view: WorldView, display: DisplayWorld, force: bool) =
   let speed = 0.04

   var desiredFlagDisplay: Table[Entity, float]
   g.mousedOverHex.ifPresent(hex):
      entityAt(view, hex).ifPresent(mousedOverEnt):
         desiredFlagDisplay[mousedOverEnt] = 1.0

   display.withSelectedCharacter:
      desiredFlagDisplay[selC] = 1.0

   for ent in desiredFlagDisplay.keys:
      if not g.curFlagDisplay.hasKey(ent):
         g.curFlagDisplay[ent] = 0.0f

   var updateRequired = force
   var toRemove: seq[Entity]
   for ent, cur in g.curFlagDisplay:
      let desired = desiredFlagDisplay.getOrDefault(ent)
      let delta = (desired - cur).sign * speed
      let newValue = if (desired - cur).abs < speed:
         desired
      else:
         cur + delta

      if newValue != cur:
         updateRequired = true

      if newValue <= 0.0:
         toRemove.add(ent)
      else:
         g.curFlagDisplay[ent] = newValue


   for h in toRemove:
      g.curFlagDisplay.del(h)

   if updateRequired:
      for ent, value in g.curFlagDisplay:
         drawFlagUI(g, view, display, ent, value)

      g.uiCanvas.swap()




method update(g: PhysicalEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   if world.hasData(Maps):
      var worldChanged = g.worldWatcher.hasChanged
      if worldChanged or curView.hasActiveOverlay:
         g.render(curView, display)

      g.updateFlagUI(curView, display, worldChanged or curView.hasActiveOverlay)

   @[g.canvas.drawCommand(display), g.uiCanvas.drawCommand(display)]

method onEvent(g: PhysicalEntityGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   matchType(event):
      extract(HexMouseEnter, hex):
         g.mousedOverHex = some(hex)

