import prelude

import heapqueue
import options
import sets



type
  FloodNode*[T] = object
    value: T
    cost: float32

proc `<`*[T](a,b: FloodNode[T]) : bool = a.cost < b.cost


## Simple flood search implemented as an iterator. Searches outward from the origin, examining lower cost paths first.
## Assumes that the cost of an individual node is independent of where that node is being reached from (i.e. entering a
## tile from the south will have the same cost as entering from the north), costs are not guaranteed to be correct if that
## is not true.
## Search stops once the given cost limit is reached, otherwise it will run as long as more values are requested
## Requires that T has hash and equality defined
iterator floodIterator*[T](origin: T, neighborFunc: (T, var seq[T]) -> void, costFunc: (T) -> Option[float], costLimit: float) : (T, float32) =
  var seen : HashSet[T]
  var queue = initHeapQueue[FloodNode[T]]()
  queue.push(FloodNode[T](value: origin, cost: 0.0f32))

  var neighbors: seq[T] = @[]

  while queue.len > 0:
    let n = queue.pop()
    if n.cost > costLimit:
      break
    yield (n.value, n.cost)

    neighborFunc(n.value, neighbors)
    for neighbor in neighbors:
      if not seen.contains(neighbor):
        let costOpt = costFunc(neighbor)
        if costOpt.isSome:
          queue.push(FloodNode[T](value: neighbor, cost: n.cost + costOpt.get.float32))
        seen.incl(neighbor)
    neighbors.setLen(0)


