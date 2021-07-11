import engines

import itb/game/progress
import itb/game/board
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
import itb/game/characters
import itb/graphics/common
import sequtils
import algorithm
import core
import patty
import itb/game/logic
import itb/graphics/game_ui
import math

type
  CharacterGraphicsComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    needsUpdate: bool
    startOfAnim: float

method initialize(g: CharacterGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "CharacterGraphicsComponent"
   g.canvas = createITBCanvas("shaders/simple")
   g.canvas.drawOrder = 10

method onEvent*(g: CharacterGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  g.needsUpdate = true



proc render(g: CharacterGraphicsComponent, view: WorldView, display: DisplayWorld, boardEnt : Entity) =
  var r : Rand = initRand(programStartTime.toTime.toUnix)

  let actionResults = previewActionResults(display, view)
  let gui = display.data(GameUI)

  if actionResults.len == 0:
    g.startOfAnim = 0.0
  elif g.startOfAnim == 0.0:
    g.startOfAnim = relTime().inSeconds

  withView(view):
    for characterEnt in toSeq(view.entitiesWithData(Character)).sortedByIt(it.data(Character).position.y * -1):
      let character = characterEnt.data(Character)

      let charActRes = actionResults.getOrDefault(characterEnt)

      var hp = character.health.currentValue
      var previewHP = hp
      var movePath : seq[Vec2i]
      for actRes in charActRes:
        match actRes:
          CharMove(path): movePath = path
          CharDamage(damage): previewHP = max(hp - damage, 0)

      var qb = ITBQuad()
      qb.layer = 4
      qb.origin = vec2f(0.5,-0.1)
      qb.color = rgba(1.0, 1.0, 1.0, 1.0)
      qb.texture = image(&"itb/character/{character.className}.png")
      qb.position = toPixelPos(character.position)
      qb.dimensions = vec2f(24.0f, 24.0f)
      qb.drawTo(g.canvas)

      if movePath.nonEmpty:
        var tiles = @[character.position, character.position]
        tiles.add(movePath)
        tiles.add(tiles[tiles.len - 1])
        tiles.add(tiles[tiles.len - 1])

        var prev = toPixelPos(character.position)
        # we want 1 slot at the beginning, 1 slot at the end
        let (_, f) = splitDecimal(((relTime().inSeconds - g.startOfAnim) * 2.5f) / (tiles.len).float)
        let (i, subf) = splitDecimal(f * (tiles.len-1).float)
        let fromT = tiles[i.int]
        let toT = tiles[i.int+1]

        let fromP = toPixelPos(fromT)
        let toP = toPixelPos(toT)

        qb.position = fromP + (toP - fromP) * subf
        qb.color = rgba(1.0, 1.0, 1.0, 0.5)
        qb.drawTo(g.canvas)





      let maxHP = character.health.maxValue
      for i in 0 ..< maxHP:
        let img = if previewHP > i:
          image("itb/ui/hp_point_small.png")
        else:
          image("itb/ui/hp_point_small_frame.png")
        qb.origin = vec2f(0.0f,0.0f)
        qb.position = toPixelPos(character.position) + vec2f(10.0,20.0 - (img.height - 1).float * i.float)
        qb.texture = img
        qb.color = rgba(1.0,1.0,1.0,1.0)
        qb.dimensions = vec2f(img.width, img.height)
        qb.drawTo(g.canvas)

        if previewHP <= i and hp > i:
          qb.texture = image("itb/ui/hp_point_small.png")
          qb.color = rgba(1.0,1.0,1.0, (cos(relTime().inSeconds * 4.0f) + 1.0) * 0.5)
          qb.drawTo(g.canvas)






method update(g: CharacterGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  let board = curView.data(Progress).activeBoard
  if board.isSome:
    if g.needsUpdate or previewActionResults(display, curView).nonEmpty:
      render(g, curView, display, board.get)
      g.canvas.swap()
      g.needsUpdate = false
    @[g.canvas.drawCommand(display)]
  else:
    @[]
