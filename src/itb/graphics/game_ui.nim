import engines

import itb/game/progress
import itb/game/board
import itb/game/characters
import itb/game/logic
import graphics/canvas
import graphics/color
import options
import prelude
import reflect
import resources
import graphics/images
import glm
import random
import times
import tables
import itb/graphics/common
import graphics/cameras
import graphics/camera_component
import core
import noto
import patty
import strutils

type
  GameUIComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    overlayCanvas: SimpleCanvas
    needsUpdate: bool

  GameUI* = object
    selectedCharacter* : Option[Entity]
    mousedOverTile* : Option[Vec2i]
    activeActionIndex* : Option[int]

  TileMouseRelease* = ref object of InputEvent
    tile*: Vec2i
    position*: Vec2f
    button*: MouseButton

  TileMousePress* = ref object of InputEvent
    tile*: Vec2i
    position*: Vec2f
    button*: MouseButton

  TileMouseEnter* = ref object of InputEvent
    tile*: Vec2i

  TileMouseExit* = ref object of InputEvent
    tile*: Vec2i


defineRealtimeReflection(GameUI)

method initialize(g: GameUIComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.name = "GameUIComponent"
  g.canvas = createITBCanvas("shaders/simple")
  g.overlayCanvas = createITBCanvas("shaders/simple")
  g.overlayCanvas.drawOrder = 15

  display.attachData(GameUI())


proc pixelToTile*(display : DisplayWorld, pixel : Vec2f) : Option[Vec2i] =
   let GCD = display[GraphicsContextData]
   let worldPos = display[CameraData].camera.pixelToWorld(GCD.framebufferSize, GCD.windowSize, pixel)
   let raw = fromPixelPos(worldPos.xy + vec2f(0.0f,4.0f)) # the 4 is to counteract the fact that the image is of a 3d slab in iso
   if raw.x < 0 or raw.y < 0 or raw.x >= BoardSize or raw.y >= BoardSize:
     none(Vec2i)
   else:
     some(raw)

proc selectedAction*(gui: ref GameUI, view: WorldView) : Option[CharAction] =
  for selc in gui.selectedCharacter:
    for actionIndex in gui.activeActionIndex:
      let avail = availableActions(view, selc)
      if avail.len > actionIndex:
        return some(avail[actionIndex])
  none(CharAction)

proc previewActionResults*(display: DisplayWorld, view: WorldView): Table[Entity, seq[CharActionResult]] =
  let gui = display.data(GameUI)
  for selc in gui.selectedCharacter:
    for mot in gui.mousedOverTile:
      for action in selectedAction(gui, view):
        if canPerformAction(view, selc, action, mot):
          result = computeActionResults(view, selc, action, mot)


proc selectCharacter*(display: DisplayWorld, selc : Option[Entity]) =
  let gui = display.data(GameUI)
  if gui.selectedCharacter != selc:
    gui.selectedCharacter = selc
    gui.activeActionIndex = none(int)

method onEvent*(g: GameUIComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  withView(curView):
    let gui = display.data(GameUI)

    matcher(event):
      extract(MouseRelease, button, position):
        for tile in pixelToTile(display, position):
          display.addEvent(TileMouseRelease(tile: tile, position : position, button : button))
      extract(MousePress, button, position):
        for tile in pixelToTile(display, position):
          display.addEvent(TileMousePress(tile: tile, position : position, button : button))
      extract(MouseMove, position):
        let tileOpt = pixelToTile(display, position)
        if tileOpt != gui.mousedOverTile:
          for exitedTile in gui.mousedOverTile:
            display.addEvent(TileMouseExit(tile: exitedTile))
          gui.mousedOverTile = tileOpt
          for enteredTile in gui.mousedOverTile:
            display.addEvent(TileMouseEnter(tile: enteredTile))
          g.needsUpdate = true
      extract(KeyRelease, key, modifiers):
        if key >= KeyCode.K1 and key <= KeyCode.K9:
          let actionIndex = key.ord - KeyCode.K1.ord
          for selc in gui.selectedCharacter:
            if availableActions(curView, selc).len > actionIndex:
              gui.activeActionIndex = some(actionIndex)
        elif key == KeyCode.Escape:
          if gui.activeActionIndex.isSome:
            gui.activeActionIndex = none(int)
          elif gui.selectedCharacter.isSome:
            gui.selectedCharacter = none(Entity)

      extract(TileMouseRelease, tile):
        for boardEnt in curView.data(Progress).activeBoard:
          if gui.activeActionIndex.isSome:
            for selc in gui.selectedCharacter:
              let actionIndex = gui.activeActionIndex.get
              let actions = availableActions(curView, selc)
              if actions.len > actionIndex:
                let action = actions[actionIndex]
                if canPerformAction(world, selc, action, tile):
                  performAction(world, selc, action, tile)
                  gui.activeActionIndex = none(int)
              else:
                warn &"Invalid action index {actionIndex}"
              return
          else:
            for clickedChar in characterAt(curView, tile):
              if clickedChar.data(Character).playerCharacter:
                gui.selectedCharacter = some(clickedChar)
              return

            for selc in gui.selectedCharacter:
              let selcPos = selc.data(Character).position
              let pf = createPathfinder(curView, boardEnt, selc)
              for path in pf.findPath(PathRequest(fromTile: selcPos, targetTiles: @[tile])):
                let reachablePath = subPath(path, selc.data(Character).moves.currentValue)
                if reachablePath.tiles.len > 1:
                  moveCharacter(world, selc, reachablePath)



proc previewAction(g: GameUIComponent, view: WorldView, display: DisplayWorld, boardEnt: Entity, selc: Entity, action: CharAction, target: Vec2i)



proc render(g: GameUIComponent, view: WorldView, display: DisplayWorld, boardEnt : Entity) =
  withView(view):
    let board = boardEnt.data(Board)
    let gui = display.data(GameUI)

    var r : Rand = initRand(programStartTime.toTime.toUnix)

    withView(view):
      for selc in gui.selectedCharacter:
        let selcPos = selc.data(Character).position
        let dy = cos(relTime().inSeconds * 2.0f) * 1.5f

        var qb = ITBQuad()
        qb.layer = 4
        qb.centered
        qb.color = rgba(0.1, 0.8, 0.2, 1.0)
        qb.texture = image(&"itb/ui/selection_arrow.png")
        qb.position = toPixelPos(selcPos) + vec2f(0.0f,30.0f + dy)
        qb.dimensions = vec2f(10.0f, 8.0f)
        qb.drawTo(g.overlayCanvas)

        for mot in gui.mousedOverTile:
          if gui.activeActionIndex.isSome:
            let actions = availableActions(view, selc)
            if actions.len > gui.activeActionIndex.get:
              let action = actions[gui.activeActionIndex.get]
              if canPerformAction(view, selc, action, mot):
                previewAction(g, view, display, boardEnt, selc, action, mot)
            else:
              warn &"Action index out of bounds"
          elif characterAt(view, mot).isNone:
            let pf = createPathfinder(view, boardEnt, selc)
            for path in pf.findPath(PathRequest(fromTile: selcPos, targetTiles: @[mot])):
              var totalCost = 0
              for i in 0 ..< path.tiles.len:
                let tile = path.tiles[i]
                let stepCost = if i > 0: path.stepCosts[i-1] else: 0
                totalCost += stepCost
                if tile != selcPos:
                  qb.centered
                  qb.layer = 2
                  qb.color = rgba(1.0f,1.0f,1.0f,0.5f)
                  if totalCost <= selc.data(Character).moves.currentValue:
                    qb.texture = image("itb/ui/tile_selection_green.png")
                  else:
                    qb.texture = image("itb/ui/tile_selection_blue.png")
                  qb.position = toPixelPos(tile) + vec2f(0.0f, 2.0f * TileScale)
                  qb.dimensions = vec2f(32.0f * TileScale, 21.0f * TileScale)
                  qb.drawTo(g.canvas)


      for mot in gui.mousedOverTile:
        var qb = ITBQuad()
        qb.layer = 2
        qb.centered
        qb.color = rgba(1.0, 1.0, 1.0, 1.0)
        qb.texture = image("itb/ui/tile_cursor.png")
        qb.position = toPixelPos(mot) + vec2f(0.0f,1.0f)
        qb.dimensions = vec2f(32.0f * TileScale, 23.0f * TileScale)
        qb.drawTo(g.canvas)







proc previewAction(g: GameUIComponent, view: WorldView, display: DisplayWorld, boardEnt: Entity, selc: Entity, action: CharAction, target: Vec2i) =
  withView(view):
    let board = boardEnt.data(Board)
    let gui = display.data(GameUI)


    for char, charResults in computeActionResults(view, selc, action, target):
      for charResult in charResults:
        match charResult:
          CharMove(path):
            var prev = char.data(Character).position
            for t in path:
              let vec = t - prev
              let dir = vectorToDirection(vec)

              if dir.isSome:
                var qb = ITBQuad()
                qb.layer = 2
                qb.centered
                qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
                qb.texture = image(&"itb/ui/tile_arrow_{($dir.get()).toLowerAscii}.png")
                qb.position = toPixelPos(prev) + vec2f(0.0f, 2.0f * TileScale)
                qb.dimensions = vec2f(32.0f * TileScale, 21.0f * TileScale)
                qb.drawTo(g.canvas)
              else:
                warn &"Previewing diagonal moves not supported, {prev}, {t}"

              prev = t
          CharDamage(damage):
            discard






method update(g: GameUIComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  let board = curView.data(Progress).activeBoard
  if board.isSome:
    let gui = display.data(GameUI)

    if g.needsUpdate or gui.selectedCharacter.isSome:
      render(g, curView, display, board.get)
      g.canvas.swap()
      g.overlayCanvas.swap()
      g.needsUpdate = false

    @[g.canvas.drawCommand(display), g.overlayCanvas.drawCommand(display)]
  else:
    @[]
