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

type Path* = object
   hexes*: seq[AxialVec]

proc createPathfinder*(view: WorldView): Pathfinder =
   Pathfinder(view: view, map: view.data(Map))

iterator neighbors(pf: Pathfinder, node: AxialVec): AxialVec =
   for n in node.neighbors:
      if pf.map.tileAt(n.q, n.r).isSome:
         yield n

proc cost(pf: Pathfinder, a, b: AxialVec): float =
   movement.cost(pf.view, pf.map, a, b)


proc heuristic(grid: Pathfinder, node, goal: AxialVec): float =
   node.distance(goal)


proc findPath*(pf: Pathfinder, character: Entity, fromHex: AxialVec, toHex: AxialVec): Option[Path] =
   var hexes: seq[AxialVec] = @[]
   for h in astar.path[Pathfinder, AxialVec, float](pf, fromHex, toHex):
      hexes.add(h)
   if hexes.len > 0:
      some(Path(hexes: hexes))
   else:
      none(Path)
