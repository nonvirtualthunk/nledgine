import glm
import config
import noto

type
    RGBA* = distinct Vec4u8


proc `==`*(a,b : RGBA) : bool =
    a.Vec4u8 == b.Vec4u8

proc r*(c : RGBA) : float =
    result = c.Vec4u8[0].float / 255.0f

proc `r=`*(c : var RGBA, f : float) =
    c.Vec4u8[0] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc g*(c : RGBA) : float =
    result = c.Vec4u8[1].float / 255.0f

proc `g=`*(c : var RGBA, f : float) =
    c.Vec4u8[1] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc b*(c : RGBA) : float =
    result = c.Vec4u8[2].float / 255.0f

proc `b=`*(c : var RGBA, f : float) =
    c.Vec4u8[2] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc a*(c : RGBA) : float =
    result = c.Vec4u8[3].float / 255.0f

proc `a=`*(c : var RGBA, f : float) =
    c.Vec4u8[3] = (clamp(f, 0.0f, 1.0f) * 255.0f).uint8

proc rgba*(r : float, g : float, b : float, a : float) : RGBA =
    result.Vec4u8[0] = (clamp(r, 0.0f, 1.0f) * 255.0f).uint8
    result.Vec4u8[1] = (clamp(g, 0.0f, 1.0f) * 255.0f).uint8
    result.Vec4u8[2] = (clamp(b, 0.0f, 1.0f) * 255.0f).uint8
    result.Vec4u8[3] = (clamp(a, 0.0f, 1.0f) * 255.0f).uint8

proc rgba*(r : uint8, g : uint8, b : uint8, a : uint8) : RGBA =
    result.Vec4u8[0] = r
    result.Vec4u8[1] = g
    result.Vec4u8[2] = b
    result.Vec4u8[3] = a

proc `$`*(rgba : RGBA) : string =
    $rgba.Vec4u8

proc `*`*(a,b : RGBA) : RGBA =
    rgba(a.r * b.r, a.g * b.g, a.b * b.b, a.a * a.a)

proc readFromConfig*(v : ConfigValue, color : var RGBA) =
    let elems = v.asArr
    if elems.len != 4:
        warn "RGBA cannot be read, less than 4 elements: ", $v
    else:
        if elems[0].asFloat <= 1.0f and elems[1].asFloat <= 1.0f and elems[2].asFloat <= 1.0f and elems[3].asFloat <= 1.0f:
            color = rgba(elems[0].asFloat, elems[1].asFloat, elems[2].asFloat, elems[3].asFloat)
        else:
            color = rgba(elems[0].asInt.uint8, elems[1].asInt.uint8, elems[2].asInt.uint8, elems[3].asInt.uint8)