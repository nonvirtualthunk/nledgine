import glm
import math
import hashes

type
   Vec3int = Vec3[int]
   Vec4int = Vec4[int]
   Vec3float = Vec3f
   AxialVec* {.borrow: `.`.} = distinct Vec3int

   CubeVec* {.borrow: `.`.} = distinct Vec4int

   CartVec* {.borrow: `.`.} = distinct Vec3float

   HexDirection* {.pure.} = enum
      UpperRight,
      LowerRight,
      Bottom,
      LowerLeft,
      UpperLeft,
      Top,
      Center

proc axialVec*(q: int, r: int, z: int = 0): AxialVec =
   vec3(q, r, z).AxialVec

const AxialDeltas* = [axialVec(1, 0), axialVec(1, -1), axialVec(0, -1),
                    axialVec(-1, 0), axialVec(-1, 1), axialVec(0, 1),
                    axialVec(0, 0)]

proc cubeVec*(x, y, z: int, d: int = 0): CubeVec =
   vec4(x, y, z, d).CubeVec

const CubeDeltas* = [cubeVec(1, -1, 0), cubeVec(1, 0, -1), cubeVec(0, 1, -1), cubeVec(-1, 1, 0), cubeVec(-1, 0, 1), cubeVec(0, -1, 1), cubeVec(0, 0, 0)]

proc cartVec*[XT, YT, ZT](x: XT, y: YT, z: ZT): CartVec =
   vec3f(x.float, y.float, z.float).CartVec

proc q*(v: AxialVec): int = v.Vec3int.x
proc r*(v: AxialVec): int = v.Vec3int.y
proc z*(v: AxialVec): int = v.Vec3int.z

proc x*(v: CubeVec): int = v.Vec4int.x
proc y*(v: CubeVec): int = v.Vec4int.y
proc z*(v: CubeVec): int = v.Vec4int.z
proc d*(v: CubeVec): int = v.Vec4int.w

proc x*(v: CartVec): float = v.Vec3float.x
proc y*(v: CartVec): float = v.Vec3float.y
proc z*(v: CartVec): float = v.Vec3float.z


proc `+` *(a, b: AxialVec): AxialVec =
   axialVec(a.q + b.q, a.r + b.r, a.z + b.z)

proc `-` *(a, b: AxialVec): AxialVec =
   axialVec(a.q - b.q, a.r - b.r, a.z - b.z)

proc `+` *(a, b: CubeVec): CubeVec =
   cubeVec(a.x + b.x, a.y + b.y, a.z + b.z, a.d + b.d)

proc `-` *(a, b: CubeVec): CubeVec =
   cubeVec(a.x - b.x, a.y - b.y, a.z - b.z, a.d - b.d)

proc `*` *(a: CubeVec, b: int): CubeVec =
   cubeVec(a.x * b, a.y * b, a.z * b, a.d * b)

proc `*` *(a: CartVec, b: float): CartVec =
   cartVec(a.x * b, a.y * b, a.z * b)

proc `+` *(a, b: CartVec): CartVec =
   cartVec(a.x + b.x, a.y + b.y, a.z + b.z)

proc `-` *(a, b: CartVec): CartVec =
   cartVec(a.x - b.x, a.y - b.y, a.z - b.z)

proc `==` *(a, b: AxialVec): bool =
   a.q == b.q and a.r == b.r

proc hash*(k: AxialVec): Hash =
   var h: Hash
   h = h !& k.q
   h = h !& k.r
   !$h

proc `$`*(v: AxialVec): string = "AxialVec(" & $v.q & "," & $v.r & ")"

proc asCubeVec*(v: AxialVec): CubeVec =
   cubeVec(v.q, -v.q - v.r, v.r)

proc asAxialVec*(v: CubeVec): AxialVec =
   axialVec(v.x, v.z, v.d)

proc neighbor*(v: AxialVec, n: int): AxialVec =
   v + AxialDeltas[n]

proc neighbor*(v: AxialVec, n: HexDirection): AxialVec =
   v + AxialDeltas[n.ord]

iterator neighbors*(v: AxialVec): AxialVec =
   for i in 0 ..< 6:
      yield neighbor(v, i)

proc distance*(a: AxialVec, b: AxialVec): float =
   ((a.q - b.q).abs + (a.q + a.r - b.q - b.r).abs + (a.r - b.r).abs).float / 2.0f

proc asCartesian*(v: AxialVec): CartVec =
   cartVec(v.q.float * 0.75f, (v.r.float + v.q.float * 0.5f) * 0.866025388f, v.z)

proc asCartVec*(v: AxialVec): CartVec =
   asCartesian(v)

proc roundedCube(x, y, z: float): CubeVec =
   var rx = x.round
   var ry = y.round
   var rz = z.round

   let xDiff = (rx - x).abs
   let yDiff = (ry - y).abs
   let zDiff = (rz - z).abs

   if (xDiff > yDiff and xDiff > zDiff):
      rx = -ry - rz
   elif (yDiff > zDiff):
      ry = -rx - rz
   else:
      rz = -rx - ry
   cubeVec(rx.int, ry.int, rz.int)

proc roundedAxial(q, r: float): AxialVec =
   let x = q
   let y = -q - r
   let z = r
   roundedCube(x, y, z).asAxialVec

proc asAxialVec*(c: CartVec): AxialVec =
   let q = c.x * 1.3333333333f
   let r = (-c.x / 1.5f) + (math.sqrt(3.0f)/1.5f) * c.y
   roundedAxial(q, r)

proc toAxialVec*(v: Vec3f, hexSize: float): AxialVec =
   let q = (v.x * 1.33333333f) / hexSize
   let r = ((-v.x / 1.5f) + ((sqrt(3.0f)/1.5f) * v.y)) / hexSize
   roundedAxial(q, r)

iterator hexRing*(center: AxialVec, radius: int): AxialVec =
   let center = center.asCubeVec + CubeDeltas[4] * radius

   var i, j = 0
   var cur = center

   if radius == 0:
      yield center.asAxialVec
   else:
      while i < 6 and j < radius:
         yield cur.asAxialVec
         cur = cur + CubeDeltas[i]
         j += 1
         if j >= radius:
            j = 0
            i.inc


proc hexHeight*(hexSize: float): float = hexSize / 1.1547005f
