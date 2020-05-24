import glm

type
    RGBA* = distinct Vec4u8


proc r*(c : RGBA) : float =
    result = c.Vec4u8[0].float / 255.0f

proc g*(c : RGBA) : float =
    result = c.Vec4u8[1].float / 255.0f

proc b*(c : RGBA) : float =
    result = c.Vec4u8[2].float / 255.0f

proc a*(c : RGBA) : float =
    result = c.Vec4u8[3].float / 255.0f

proc rgba*(r : float, g : float, b : float, a : float) : RGBA =
    result.Vec4u8[0] = (clamp(r, 0.0f, 1.0f) * 255.0f).uint8
    result.Vec4u8[1] = (clamp(g, 0.0f, 1.0f) * 255.0f).uint8
    result.Vec4u8[2] = (clamp(b, 0.0f, 1.0f) * 255.0f).uint8
    result.Vec4u8[3] = (clamp(a, 0.0f, 1.0f) * 255.0f).uint8