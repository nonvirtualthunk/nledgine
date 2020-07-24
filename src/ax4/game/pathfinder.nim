import ax4/game/map
import astar
import hex
import options
import worlds
import game/library
import options
import ax4/game/movement


type Pathfinder* = object
   view: WorldView
   map: ref Map
   entity: Entity

type Path* = object
   hexes*: seq[AxialVec]
   cost*: int
   stepCosts: seq[int]

type PathPriority* {.pure.} = enum
   Shortest
   First

type PathRequest* = object
   fromHex*: AxialVec
   targetHexes*: seq[AxialVec]
   pathPriority*: PathPriority


proc createPathfinder*(view: WorldView, entity: Entity): Pathfinder =
   Pathfinder(view: view, map: view.data(Map), entity: entity)

iterator neighbors(pf: Pathfinder, node: AxialVec): AxialVec =
   for n in node.neighbors:
      if pf.map.tileAt(n.q, n.r).isSome:
         yield n

proc cost(pf: Pathfinder, a, b: AxialVec): float =
   movement.cost(pf.view, pf.map, a, b)


proc heuristic(grid: Pathfinder, node, goal: AxialVec): float =
   node.distance(goal)


proc subPath*(path: Path, maxCost: int): Path =
   if path.hexes.len != 0:
      result.hexes.add(path.hexes[0])
      for i in 1 ..< path.hexes.len:
         let stepCost = path.stepCosts[i-1]
         if result.cost + stepCost <= maxCost:
            result.stepCosts.add(stepCost)
            result.cost += stepCost
            result.hexes.add(path.hexes[i])
         else:
            break


proc findPath*(pf: Pathfinder, request: PathRequest): Option[Path] =
   let fromHex = request.fromHex

   var paths: seq[Path]
   for toHex in request.targetHexes:
      var path: Path

      for h in astar.path[Pathfinder, AxialVec, float](pf, fromHex, toHex):
         if path.hexes.len > 0:
            let stepCost = movement.cost(pf.view, pf.map, path.hexes[path.hexes.len - 1], h).int
            path.cost += stepCost
            path.stepCosts.add(stepCost)
         path.hexes.add(h)
      if path.hexes.len > 0:
         if request.pathPriority == PathPriority.First:
            return some(path)
         paths.add(path)

   case request.pathPriority:
   of PathPriority.Shortest:
      var shortestPath: Option[Path]
      var shortestCost = 10000000
      for path in paths:
         if path.cost < shortestCost:
            shortestPath = some(path)
            shortestCost = path.cost
      shortestPath
   of PathPriority.First:
      # if we've gotten here, there were none
      none(Path)


