import glm
import config/config_core
import noto
import strutils
import chroma
import hashes
import bitops

type
  RGBA* = distinct Vec4u8

  ColorRamp* = object
    colors*: seq[RGBA]

  Palette* = object
    ramps*: seq[ColorRamp]


proc hash*(v : RGBA) : Hash =
  # Hash(v.Vec4u8[0].uint32 bitor (v.Vec4u8[1].uint32 shl 8) bitor (v.Vec4u8[2].uint32 shl 16) bitor (v.Vec4u8[3].uint32 shl 24))
  Hash(cast[ptr uint32](v.unsafeAddr)[])
  # var h : Hash
  # h = h !& v.Vec4u8[0]
  # h = h !& v.Vec4u8[1]
  # h = h !& v.Vec4u8[2]
  # h = h !& v.Vec4u8[3]
  # !$h

proc `==`*(a, b: RGBA): bool =
  a.Vec4u8 == b.Vec4u8

proc r*(c: RGBA): float =
  result = c.Vec4u8[0].float / 255.0f

proc `r=`*(c: var RGBA, f: float) =
  c.Vec4u8[0] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc g*(c: RGBA): float =
  result = c.Vec4u8[1].float / 255.0f

proc `g=`*(c: var RGBA, f: float) =
  c.Vec4u8[1] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc b*(c: RGBA): float =
  result = c.Vec4u8[2].float / 255.0f

proc `b=`*(c: var RGBA, f: float) =
  c.Vec4u8[2] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc a*(c: RGBA): float =
  result = c.Vec4u8[3].float / 255.0f

proc `a=`*(c: var RGBA, f: float) =
  c.Vec4u8[3] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc `r=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[0] = u

proc `g=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[1] = u

proc `b=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[2] = u

proc `a=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[3] = u

proc `ri=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[0] = u

proc `gi=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[1] = u

proc `bi=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[2] = u

proc `ai=`*(c: var RGBA, u: uint8) =
  c.Vec4u8[3] = u

proc `ri`*(c: RGBA) : uint8 =
  c.Vec4u8[0]

proc `gi`*(c: RGBA): uint8 =
  c.Vec4u8[1]

proc `bi`*(c: RGBA): uint8 =
  c.Vec4u8[2]

proc `ai`*(c: RGBA): uint8 =
  c.Vec4u8[3]

proc luminance(c: RGBA): float32 = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

proc rgba*(r: float, g: float, b: float, a: float): RGBA =
  result.Vec4u8[0] = (clamp(r, 0.0f, 1.0f) * 255.0f).uint8
  result.Vec4u8[1] = (clamp(g, 0.0f, 1.0f) * 255.0f).uint8
  result.Vec4u8[2] = (clamp(b, 0.0f, 1.0f) * 255.0f).uint8
  result.Vec4u8[3] = (clamp(a, 0.0f, 1.0f) * 255.0f).uint8

proc rgba*(r: uint8, g: uint8, b: uint8, a: uint8): RGBA =
  result.Vec4u8[0] = r
  result.Vec4u8[1] = g
  result.Vec4u8[2] = b
  result.Vec4u8[3] = a


const White* = rgba(255, 255, 255, 255)
const Black* = rgba(0, 0, 0, 255)
const Clear* = rgba(255, 255, 255, 0)

proc `$`*(rgba: RGBA): string =
  $rgba.Vec4u8

proc `*`*(a, b: RGBA): RGBA =
  rgba(a.r * b.r, a.g * b.g, a.b * b.b, a.a * b.a)

proc `*`*(a: RGBA, f: float): RGBA =
  rgba(a.r * f, a.g * f, a.b * f, a.a * f)

proc mix*(a, b: RGBA, f: float): RGBA =
  rgba(b.r * f + a.r * (1.0f - f), b.g * f + a.g * (1.0f - f), b.b * f + a.b * (1.0f - f), b.a * f + a.a * (1.0f - f))
  
proc mix*(a, b: RGBA, fa,fb: float): RGBA =
  let fsum = fa+fb
  let fap = fa / fsum
  let fbp = 1.0 - fap
  rgba(b.r * fbp + a.r * fap, b.g * fbp + a.g * fap, b.b * fbp + a.b * fap, b.a * fbp + a.a * fap)

proc asUint32s*(r: ColorRamp): seq[uint32] =
  for c in r.colors:
    result.add(cast[ptr uint32](c.unsafeAddr)[])

proc readFromConfig*(v: ConfigValue, color: var RGBA) =
  if v.isStr:
    let str = v.asStr
    if str.startsWith("#") or str.startsWith("rgb"):
      let parsed = chroma.parseHtmlColor(str)
      color = rgba(parsed.r, parsed.g, parsed.b, 1.0f)
    else:
      warn &"Color could not be parsed: {str}"
  else:
    let elems = v.asArr
    if elems.len != 4:
      warn &"RGBA cannot be read, less than 4 elements: {v}"
    else:
      if elems[0].asFloat <= 1.0f and elems[1].asFloat <= 1.0f and elems[2].asFloat <= 1.0f and elems[3].asFloat <= 1.0f:
        color = rgba(elems[0].asFloat, elems[1].asFloat, elems[2].asFloat, elems[3].asFloat)
      else:
        color = rgba(elems[0].asInt.uint8, elems[1].asInt.uint8, elems[2].asInt.uint8, elems[3].asInt.uint8)

proc readFromConfig*(v: ConfigValue, ramp: var ColorRamp) =
  if v.isArr:
    v.readInto(ramp.colors)
  else:
    warn &"Color ramp could not be parsed from {v}"