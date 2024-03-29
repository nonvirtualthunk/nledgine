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
import strformat
import ax4/display/ax_display_events
import util
import options
import ax4/game/ax_events
import ax4/game/pathfinder
import windowingsystem/windowingsystem
import ax4/game/resource_pools
import graphics/color
import ax4/game/turns

type
  TacticalUIComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    worldWatcher: Watcher[WorldEventClock]

  TacticalUIData* = object
    selectedCharacter*: Option[Entity]

defineDisplayReflection(TacticalUIData)

template withSelectedCharacter*(display: DisplayWorld, stmts: untyped) =
  let tuid = display[TacticalUIData]
  if tuid.selectedCharacter.isSome:
    let selC {.inject.} = tuid.selectedCharacter.get
    stmts

method initialize(g: TacticalUIComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.name = "TacticalUIComponent"
  g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
  g.worldWatcher = watcher(() => curView.currentTime())
  g.eventPriority = 10
  g.canvas.drawOrder = 5
  display.attachData(TacticalUIData())

  let ws = display[WindowingSystem]
  ws.desktop.background.drawCenter = false


proc render(g: TacticalUIComponent, view: WorldView, display: DisplayWorld) =
  withView(view):
    display.withSelectedCharacter:
      let AP = taxon("resource pools", "action points")

      let hexSize = mapGraphicsSettings().hexSize.float
      let hexHeight = hexSize.hexHeight

      var qb = QuadBuilder()
      qb.centered()

      let dy = cos(relTime().inSeconds * 2.0f) * 0.03f
      let pos = (selC[Physical].position.asCartVec + selC[Physical].offset).Vec3f * hexSize + vec3f(0.0f, hexHeight.float * (0.4 + dy), 0.0f)
      let curAP = selC[ResourcePools].currentResourceValue(AP)
      let maxAP = selC[ResourcePools].maximumResourceValue(AP)
      let fractionalImage = if curAP == maxAP:
        image("ax4/images/ui/selection_arrow.png")
      else:
        image(&"ax4/images/ui/selection_arrow_{curAP}_{maxAP}.png")
      let backgroundImage = image("ax4/images/ui/selection_arrow.png")

      qb.position = pos
      qb.texture = backgroundImage
      qb.dimensions = vec2f(backgroundImage.dimensions * 2)
      qb.color = color.White
      qb.drawTo(g.canvas)

      if curAP > 0:
        qb.texture = fractionalImage
        qb.color = factionData(view, selC).color
        qb.drawTo(g.canvas)

    g.canvas.swap()

proc setSelectedCharacter(g: TacticalUIComponent, world: World, display: DisplayWorld, character: Entity) =
  withView(world):
    let tuid = display[TacticalUIData]
    tuid.selectedCharacter = some(character)
    display.addEvent(CharacterSelect(character: character))

    display[CameraData].camera.cameraMovement = some(
      CameraMovement(
        targetLocation: (character[Physical].position.asCartVec.Vec3f.xy + vec2f(0.0f,1.0f)) * mapGraphicsSettings().hexSize.float,
        speedMultiplier: 4.0f,
      )
    )

method onEvent(g: TacticalUIComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  let tuid = display[TacticalUIData]
  let selc = tuid.selectedCharacter

  withWorld(world):
    matchType(event):
      extract(HexMouseRelease, hex, button, position):
        # if tuid.selectedCharacter.isSome:
          # discard
        # else:
          for entity in world.entitiesWithData(Physical):
            if entity[Physical].position == hex:
              if tuid.selectedCharacter != some(entity):
                if entity.hasData(Character) and faction(world, entity) == world[TurnData].activeFaction and not entity[Character].dead:
                  g.setSelectedCharacter(world, display, entity)
      extract(KeyRelease, key):
        case key:
        of KeyCode.Enter, KeyCode.KPEnter:
          endTurn(world)
        of KeyCode.Tab:
          var playerCharacters: seq[Entity]
          for character in playerCharacters(world):
            if not character[Character].dead:
              playerCharacters.add(character)
          var selectedIndex = -1
          if selc.isSome:
            selectedIndex = playerCharacters.find(selc.get)
          let newIndex = (selectedIndex+1) mod playerCharacters.len
          if newIndex <= playerCharacters.len:
            g.setSelectedCharacter(world, display, playerCharacters[newIndex])

        else: discard
      extract(FactionTurnEndEvent, faction):
        if not faction[Faction].playerControlled:
          tuid.selectedCharacter = none(Entity)
      extract(FactionTurnStartEvent, faction):
        if faction[Faction].playerControlled:
          for ent in entitiesInFaction(world, faction):
            if not ent[Character].dead:
              g.setSelectedCharacter(world, display, ent)
              break
      extract(CharacterMoveEvent, toHex):
        let absoluteLocation = toHex.asCartVec.Vec3f.xy * mapGraphicsSettings().hexSize.float
        if distance(display[CameraData].camera.eye.xy, absoluteLocation) > mapGraphicsSettings().hexSize.float * 3.0f:
          display[CameraData].camera.cameraMovement = some(
            CameraMovement(
              targetLocation: toHex.asCartVec.Vec3f.xy * mapGraphicsSettings().hexSize.float,
              speedMultiplier: 4.0f,
            )
          )


method update(g: TacticalUIComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  g.render(curView, display)
  @[g.canvas.drawCommand(display)]
  # @[]
