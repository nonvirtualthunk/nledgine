import algorithm
import prelude
import survival/game/logic
import survival/game/entities
import survival/game/tiles
import survival/game/survival_core
import glm
import astar
import sequtils

type
  PathSelection* = enum
    Any
    Shortest

  PathRequest* = object
    origin*: Vec3i
    targets*: seq[Vec3i]
    pathSelection*: PathSelection

  Pathfinder* = object
    world: LiveWorld
    region: ref Region
    entity: Entity
    baseMoveCost: int




proc pathRequest*(fromPos: Vec3i, toPos: Vec3i): PathRequest = PathRequest(origin: fromPos, targets: @[toPos])

proc pathRequest*(world: LiveWorld, fromPos: Vec3i, target: Target, moveAdjacentTo: bool): PathRequest =
  let pos = positionOf(world, target)
  if pos.isSome:
    if moveAdjacentTo:
      var targets : seq[Vec3i]
      for c in CardinalVectors2D:
        targets.add(pos.get() + vec3i(c.x,c.y,0))
      PathRequest(origin: fromPos, targets: targets)
    else:
      PathRequest(origin: fromPos, targets: @[pos.get()])
  else:
    warn &"Attempting to create a path request to a non-physical entity: {target}"
    writeStackTrace()
    # return a path request with no targets, which will always return no path
    PathRequest(origin: fromPos, targets: @[])

proc createPathfinder*(world: LiveWorld, entity: Entity): Pathfinder =
  Pathfinder(world: world, region: entity[Physical].region[Region], entity: entity, baseMoveCost: entity[Creature].baseMoveTime.int)

iterator neighbors*(pf: Pathfinder, node: Vec3i): Vec3i  =
  for q in 0 ..< 4:
    let n = vec3i(node.x + CardinalVectors2D[q].x, node.y + CardinalVectors2D[q].y, node.z)
    if n.x > -RegionHalfSize and n.x < RegionHalfSize and n.y > -RegionHalfSize and n.y < RegionHalfSize:
      if passable(pf.world, pf.region, n):
        yield n

proc cost*(pf: Pathfinder, a, b: Vec3i): int =
  tileMoveTime(tile(pf.region, b.x, b.y, b.z)).int + pf.baseMoveCost

proc heuristic*(pf: Pathfinder, node, goal: Vec3i): int =
  ((goal.x - node.x).abs + (goal.y - node.y).abs + (goal.z - node.z).abs) * pf.baseMoveCost

proc findPath*(pf: Pathfinder, request: PathRequest) : Option[Path] =
  var paths: seq[Path]
  let sortedTargets = request.targets.sortedByIt(distance(it, request.origin))
  for target in sortedTargets:
    var path: Path

    for h in astar.path[Pathfinder, Vec3i, int](pf, request.origin, target):
      if path.steps.len > 0:
        let stepCost = cost(pf, path.steps[^1], h)
        path.stepCosts.add(stepCost)
        path.cost += stepCost
      else:
        path.stepCosts.add(0)
      path.steps.add(h)

    if path.steps.len > 0:
      paths.add(path)
      if request.pathSelection == PathSelection.Any:
        return some(path)

  var shortestPath : Option[Path]
  var shortestCost = 10000000
  for path in paths:
    if path.cost < shortestCost:
      shortestPath = some(path)
      shortestCost = path.cost
  shortestPath

