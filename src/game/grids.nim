import noto

type
   FiniteGrid2D*[W: static[int], H: static[int], T] = object
      values: array[W*H, T]
      sentinel: T

   FiniteGrid3D*[W: static[int], H: static[int], D: static[int], T] = object
      values: array[W*H*D, T]
      sentinel: T



proc `[]`*[W: static[int], H: static[int], I: int, T](g: FiniteGrid2D[W, H, T], x: I, y: I): T =
   if x < 0 or y < 0 or x >= W or y >= H:
      g.sentinel
   else:
      g.values[x*H+y]


proc `[]=`*[W: static[int], H: static[int], T](g: var FiniteGrid2D[W, H, T], x: int, y: int, t: T) =
   if x < 0 or y < 0 or x >= W or y >= H:
      warn &"attempted to update finite grid out of bounds, ({x}, {y}) is not within [0,0] -> [{W-1},{H-1}]"
   else:
      g.values[x*H+y] = t

proc `[]`*[W: static[int], H: static[int], D: static[int], I: int, T](g: FiniteGrid3D[W, H, D, T], x: I, y: I, z: I): T =
   if x < 0 or y < 0 or x >= W or y >= H:
      g.sentinel
   else:
      g.values[x*H+y]


proc `[]=`*[W: static[int], H: static[int], D: static[int], I: int, T](g: var FiniteGrid3D[W, H, D, T], x: I, y: I, z: I, t: T) =
   if x < 0 or y < 0 or x >= W or y >= H:
      warn &"attempted to update finite grid out of bounds, ({x}, {y}, {z}) is not within [0,0] -> [{W-1},{H-1},{D-1}]"
   else:
      g.values[x*H+y] = t



when isMainModule:
   import prelude
   var grid = FiniteGrid2D[10, 10, array[4, int]]()
   echoAssert grid[0, 0][2] == 0

   var grid3d = FiniteGrid3D[10, 10, 10, int]()
   echoAssert grid3d[0, 0, 0] == 0
   grid3d[0, 0, 0] = 10
   echoAssert grid3d[0, 0, 0] == 10

