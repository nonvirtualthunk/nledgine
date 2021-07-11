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
import itb/graphics/common

type
  BoardGraphicsComponent* = ref object of GraphicsComponent
    canvas: SimpleCanvas
    needsUpdate: bool
    imagesByTerrain: Table[string, seq[Image]]

method initialize(g: BoardGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "BoardGraphicsComponent"
   g.canvas = createITBCanvas("shaders/simple")

method onEvent*(g: BoardGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   ifOfType(BoardEnteredEvent, event):
     g.needsUpdate = true


proc imageForTerrain(g: BoardGraphicsComponent, view: WorldView, display: DisplayWorld, terrain: Terrain, imgRand : int): Image =
  let terrainImages = g.imagesByTerrain.getOrCreate(terrain.name):
    var imgs : seq[Image]
    for i in 0 ..< 4:
      let img = image(&"itb/terrain/{terrain.name}{i}.png")
      if not img.sentinel:
        imgs.add(img)
    imgs
  terrainImages[imgRand mod terrainImages.len]

proc render(g: BoardGraphicsComponent, view: WorldView, display: DisplayWorld, boardEnt : Entity) =
  withView(view):
    let board = boardEnt.data(Board)

    var r : Rand = initRand(programStartTime.toTime.toUnix)

    withView(view):
      for i in countdown(BoardSize-1, 0):
        for j in countdown(BoardSize-1, 0):
          let tile = board.tiles[i,j]

          let underTerrain = if tile.terrain == Grass:
            Soil
          elif tile.terrain == Stone:
            Stone
          elif tile.terrain == Water:
            UnderWater
          else:
            Soil

          let imgRand = r.rand(1000)

          var qb = ITBQuad()
          qb.centered
          qb.layer = -1
          qb.color = rgba(1.0, 1.0, 1.0, 1.0)
          qb.texture = imageForTerrain(g, view, display, underTerrain, imgRand)
          qb.position = toPixelPos(vec2i(i,j)) - vec2f(0.0f,7.0f * TileScale)
          qb.dimensions = vec2f(32.0f * TileScale, 23.0f * TileScale)
          qb.drawTo(g.canvas)

          qb.centered
          qb.layer = 0
          qb.color = rgba(1.0, 1.0, 1.0, 1.0)
          qb.texture = imageForTerrain(g, view, display, tile.terrain, imgRand)
          qb.position = toPixelPos(vec2i(i,j))
          qb.dimensions = vec2f(32.0f * TileScale, 23.0f * TileScale)
          qb.drawTo(g.canvas)

      discard


method update(g: BoardGraphicsComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  let board = curView.data(Progress).activeBoard
  if board.isSome:
    if g.needsUpdate:
      render(g, curView, display, board.get)
      g.canvas.swap()
      g.needsUpdate = false

    @[g.canvas.drawCommand(display)]
  else:
    @[]
