import game/grids
import glm
import prelude
import astar
import hashes
import options
import engines
import engines/event_types
import itb/game/characters

export grids


const BoardSize* = 10

const BoardCardinals* = [vec2i(1,0), vec2i(0,-1), vec2i(-1,0), vec2i(0,1)]


type
  Board* = object
    tiles* : FiniteGrid2D[BoardSize, BoardSize, Tile]


  Tile* = object
    position*: Vec2i
    terrain*: Terrain
    height*: int


  Terrain* = object
    name*: string
    moveCost*: int

  Pathfinder* = object
    view: WorldView
    board: ref Board
    entity: Entity

  PathRequest* = object
    fromTile*: Vec2i
    targetTiles*: seq[Vec2i]

  Path* = object
    tiles*: seq[Vec2i]
    cost*: int
    stepCosts*: seq[int]

  EntityMoved* = ref object of GameEvent
    entity*: Entity
    origin*: Vec2i
    destination*: Vec2i
    cost*: int
    forced*: bool



defineReflection(Board)


proc vectorToDirection*(v: Vec2i): Option[Direction] =
  for dir in Direction:
    if BoardCardinals[dir.ord] == v:
      return some(dir)
  none(Direction)


method toString*(evt: EntityMoved): string =
   return &"{$evt[]}"

const Grass* = Terrain(
  name: "grass",
  moveCost: 1
)

const Stone* = Terrain(
  name: "stone",
  moveCost: 1
)

const Soil* = Terrain(
  name: "soil",
  moveCost: 1
)

const Water* = Terrain(
  name: "water",
  moveCost: 2
)

const UnderWater* = Terrain(
  name: "water_full",
  moveCost: 2
)

proc inBounds*(v : Vec2i) : bool = v.x >= 0 and v.y >= 0 and v.x < BoardSize and v.y < BoardSize

proc moveCost*(board: ref Board, pos : Vec2i) : int =
  board.tiles[pos.x, pos.y].terrain.moveCost


proc createPathfinder*(view: WorldView, board: Entity, entity: Entity): Pathfinder =
  withView(view):
    Pathfinder(view: view, board: board.data(Board), entity: entity)

iterator neighbors*(pf: Pathfinder, node: Vec2i): Vec2i  =
  for q in 0 ..< 4:
    let n = node + BoardCardinals[q]
    if inBounds(n) and characterAt(pf.view, n).isNone:
      yield n

proc cost*(pf: Pathfinder, a, b: Vec2i): int =
  moveCost(pf.board, b)

proc heuristic*(grid: Pathfinder, node, goal: Vec2i): int =
  (goal.x - node.x).abs + (goal.y - node.y).abs


proc findPath*(pf: Pathfinder, request : PathRequest) : Option[Path] =
  var paths: seq[Path]
  for toTile in request.targetTiles:
    var path: Path

    for h in astar.path[Pathfinder, Vec2i, int](pf, request.fromTile, toTile):
      if path.tiles.len > 0:
        let stepCost = moveCost(pf.board, path.tiles[path.tiles.len - 1])
        path.stepCosts.add(stepCost)
        path.cost += stepCost
      path.tiles.add(h)
    if path.tiles.len > 0:
      paths.add(path)

  var shortestPath : Option[Path]
  var shortestCost = 10000000
  for path in paths:
    if path.cost < shortestCost:
      shortestPath = some(path)
      shortestCost = path.cost
  shortestPath


proc subPath*(path: Path, maxCost: int): Path =
  if path.tiles.len != 0:
    result.tiles.add(path.tiles[0])
    for i in 1 ..< path.tiles.len:
      let stepCost = path.stepCosts[i-1]
      if result.cost + stepCost <= maxCost:
        result.stepCosts.add(stepCost)
        result.cost += stepCost
        result.tiles.add(path.tiles[i])
      else:
        break