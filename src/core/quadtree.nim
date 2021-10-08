import noto
import math
import arxmath



type
  FixedResolutionQuadTree*[T] = ref object
    resolution: int
    root: Node[T]
    bounds: Recti


  NodeKind = enum
    Root
    Parent
    Leaf

  Node[T] = ref object
    case kind: NodeKind
      of NodeKind.Root, NodeKind.Parent:
        children*: array[4, Node[T]]
      of NodeKind.Leaf:
        values*: seq[T]


proc newQuadTree*[T](bounds: Recti, resolution: int) : FixedResolutionQuadTree[T] =
  result = FixedResolutionQuadTree[T](bounds: bounds, root: Node[T](kind: NodeKind.Root), resolution: resolution)

proc getOrCreateLeafNode[T](qt: FixedResolutionQuadTree[T], n: Node[T], x: int, y: int, nx: int, ny: int, nw: int, nh: int) : Node[T] =
  case n.kind:
    of NodeKind.Root, NodeKind.Parent:
      let hnw = nw shr 1
      let hnh = nh shr 1

      let xp = if x > nx + hnw: 1 else: 0
      let yp = if y > ny + hnh: 1 else: 0
      let index = xp + (yp shl 1)
      let child = n.children[index]
      if child == nil:
        if hnw <= qt.resolution:
          n.children[index] = Node[T](kind: NodeKind.Leaf)
        else:
          n.children[index] = Node[T](kind: NodeKind.Parent)

      getOrCreateLeafNode(qt, n.children[index], x, y, nx + xp * hnw, ny + yp * hnh, hnw, hnh)
    of NodeKind.Leaf:
      n

proc getValuesInArea[T](qt: FixedResolutionQuadTree[T], n: Node[T], cx: int, cy: int, hw: int, hh: int, nx: int, ny: int, nw: int, nh: int, res: var seq[T]) =
  let hnw = nw shr 1
  let hnh = nh shr 1

  let dx = cx - (nx + hnw)
  let dy = cy - (ny + hnh)
  if abs(dx) <= hnw + hw and abs(dy) <= hnh + hh:
    case n.kind:
      of NodeKind.Root, NodeKind.Parent:
        for i in 0 ..< 4:
          if n.children[i] != nil:
            getValuesInArea(qt, n.children[i], cx, cy, hw, hh, nx + (i mod 2) * hnw, ny + (i shr 1) * hnh, hnw, hnh, res)
      of NodeKind.Leaf:
        res.add(n.values)

proc move*[T](qt: FixedResolutionQuadTree[T], xprime: int, yprime: int, x: int, y: int, v: T) =
  # todo: optimize by avoiding the need to get the node twice
  let oldN = getOrCreateLeafNode(qt, qt.root, xprime, yprime, qt.bounds.x, qt.bounds.y, qt.bounds.width, qt.bounds.height)
  let newN = getOrCreateLeafNode(qt, qt.root, x, y, qt.bounds.x, qt.bounds.y, qt.bounds.width, qt.bounds.height)

  if oldN != newN:
    assert oldN.kind == NodeKind.Leaf
    assert newN.kind == NodeKind.Leaf
    for i in 0 ..< oldN.values.len:
      if oldN.values[i] == v:
        oldN.values.del(i)
        break
    newN.values.add(v)

proc insert*[T](qt: FixedResolutionQuadTree[T], x: int, y: int, v: T) =
  let n = getOrCreateLeafNode(qt, qt.root, x, y, qt.bounds.x, qt.bounds.y, qt.bounds.width, qt.bounds.height)
  assert n.kind == NodeKind.Leaf
  n.values.add(v)

proc remove*[T](qt: FixedResolutionQuadTree[T], x: int, y: int, v: T) =
  let n = getOrCreateLeafNode(qt, qt.root, x, y, qt.bounds.x, qt.bounds.y, qt.bounds.width, qt.bounds.height)
  assert n.kind == NodeKind.Leaf
  for i in 0 ..< n.values.len:
    if n.values[i] == v:
      n.values.del(i)
      break

proc getNear*[T](qt: FixedResolutionQuadTree[T], cx: int, cy: int, radius: int) : seq[T] =
  result = @[]
  getValuesInArea(qt, qt.root, cx, cy, radius, radius, qt.bounds.x, qt.bounds.y, qt.bounds.width, qt.bounds.height, result)

proc getNear*[T](qt: FixedResolutionQuadTree[T], cx: int, cy: int, radius: int, accum: var seq[T]) =
  getValuesInArea(qt, qt.root, cx, cy, radius, radius, qt.bounds.x, qt.bounds.y, qt.bounds.width, qt.bounds.height, accum)


when isMainModule:
  import random
  import sets

  let resolution = 4
  let qt = newQuadTree[(int,int)](recti(0,0,128,128), resolution)

  for x in 0 ..< 128:
    for y in 0 ..< 128:
      qt.insert(x,y, (x,y))


  for i in 0 ..< 32:
    let x = rand(127)
    let y = rand(127)

    var seen : HashSet[(int,int)]
    for v in qt.getNear(x,y, i):
      let (ox,oy) = v
      # assert that they aren't further than radius + resolution away (we're not including totally unnecessary values)
      assert abs(ox - x) <= i + resolution
      assert abs(oy - y) <= i + resolution
      seen.incl(v)

    for dx in -i .. i:
      for dy in -i .. i:
        # assert that all of the values within radius of the center point are included
        assert seen.contains((min(max(x + dx, 0), 127), min(max(y + dy, 0), 127)))

  # 0                                                              128
  # 0                                        64                    128
  # 0                     32                 64         96         128
  # 0         16          32       48        64   80    96   112   128
  # 0    8    16    24    32  40   48   56   64
  # 0 4  8 12 16 20 24 28 32
