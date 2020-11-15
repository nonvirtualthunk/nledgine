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
      UpperRight, #0
      LowerRight, #1
      Bottom,     #2
      LowerLeft,  #3
      UpperLeft,  #4
      Top,        #5
      Center

proc axialVec*(q: int, r: int, z: int = 0): AxialVec =
   vec3(q, r, z).AxialVec

const AxialZero* = Vec3int().AxialVec

const AxialDeltas* = [axialVec(1, 0), axialVec(1, -1), axialVec(0, -1),
                    axialVec(-1, 0), axialVec(-1, 1), axialVec(0, 1),
                    axialVec(0, 0)]

proc axialDelta*(d: HexDirection): AxialVec =
   AxialDeltas[d.ord]

proc cubeVec*(x, y, z: int, d: int = 0): CubeVec =
   vec4(x, y, z, d).CubeVec

const CubeDeltas* = [cubeVec(1, -1, 0), cubeVec(1, 0, -1), cubeVec(0, 1, -1), cubeVec(-1, 1, 0), cubeVec(-1, 0, 1), cubeVec(0, -1, 1), cubeVec(0, 0, 0)]

proc cartVec*[XT, YT, ZT](x: XT, y: YT, z: ZT): CartVec =
   vec3f(x.float, y.float, z.float).CartVec

proc cartVec*(v: Vec3f): CartVec =
   v.CartVec

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

proc `*` *(a: AxialVec, b: int): AxialVec =
   axialVec(a.q * b, a.r * b, a.z * b)

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

proc `$`*(v: AxialVec): string = "AxialVec(" & $v.q & "," & $v.r & "," & $v.z & ")"
proc `$`*(v: CartVec): string = "CartVec(" & $v.x & "," & $v.y & "," & $v.z & ")"

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

proc asVec3f*(c: CubeVec): Vec3f = vec3f(c.x.float, c.y.float, c.z.float)


proc roundedCube*(x, y, z: float): CubeVec =
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

proc normalizeSafe*(v: CartVec): CartVec =
   let mag2 = v.x*v.x+v.y*v.y+v.z*v.z
   if mag2 > 0.0f:
      let mag = sqrt(mag2)
      cartVec(v.x/mag, v.y/mag, v.z/mag)
   else:
      cartVec(0.0f, 0.0f, 0.0f)

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

proc sideClosestTo*(a, b, tiebreaker: AxialVec): HexDirection =
   if a == b:
      return HexDirection.Center
   let selfCube = a.asCubeVec.asVec3f
   let deltaA = b.asCubeVec.asVec3f - selfCube
   let deltaB = tieBreaker.asCubeVec.asVec3f - selfCube
   let delta = (deltaA + deltaB * 0.01f).normalize()

   let a = delta.x - delta.y # 0
   let b = delta.y - delta.z # 3
   let c = delta.z - delta.x # -3

   # if c is largest, and c < 0
   #

   if a.abs > b.abs and a.abs > c.abs:
      if a < 0.0f:
         HexDirection.LowerLeft
      else:
         HexDirection.UpperRight
   elif b.abs > a.abs and b.abs > c.abs:
      if b < 0.0f:
         HexDirection.Top
      else:
         HexDirection.Bottom
   else:
      if c < 0.0:
         HexDirection.LowerRight
      else:
         HexDirection.UpperLeft
