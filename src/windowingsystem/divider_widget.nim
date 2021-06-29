import windowing_system_core
import config
import graphics/image_extras
import graphics/color
import reflect
import options
import strutils
import prelude
import arxregex
import noto
import glm
import math
import worlds
import arxmath


type
  Divider* = object
    image*: Bindable[ImageLike]
    pixelScale*: int
    color*: Bindable[RGBA]

  DividerComponent* = ref object of WindowingComponent

proc readFromConfig*(cv: ConfigValue, v: var Divider) =
  readIntoOrElse(cv["image"], v.image, bindable(imageLike("ui/divider.png")))
  readIntoOrElse(cv["pixelScale"], v.pixelScale, 1)
  readIntoOrElse(cv["color"], v.color, bindable(rgba(0.25, 0.25, 0.25, 1.0)))

defineDisplayReflection(Divider)


method render*(ws: DividerComponent, widget: Widget): seq[WQuad] =
  if widget.hasData(Divider):
    let DD = widget.data(Divider)
    let pos = vec3f(0.0f,0.0f,0.0f)
    let dim = widget.resolvedDimensions

    let leftSR = subRectTexCoords(rect(vec2f(0.0,0.0), vec2f(0.5,1.0)), flipX = false)
    let rightSR = subRectTexCoords(rect(vec2f(0.0,0.0), vec2f(0.5,1.0)), flipX = true)
    let mainSR = subRectTexCoords(rect(vec2f(0.5,0.0), vec2f(0.5,1.0)), flipX = false)

    let sideDim = dim.y div 2
    if dim.x > sideDim * 2:
      let leftShape = rectShape(position = vec3f(pos.x.float, pos.y.float, 0.0f), dimensions = vec2i(sideDim, dim.y))
      let rightShape = rectShape(position = vec3f(pos.x.float + dim.x.float - sideDim.float, pos.y.float, 0.0f), dimensions = vec2i(sideDim, dim.y))
      let mainShape = rectShape(position = vec3f(pos.x.float + sideDim.float, pos.y.float, 0.0f), dimensions = vec2i(dim.x - sideDim * 2 + 1, dim.y))
      @[
        WQuad(shape: leftShape, texCoords: leftSR, color: DD.color, beforeChildren: true, image: DD.image),
        WQuad(shape: rightShape, texCoords: rightSR, color: DD.color, beforeChildren: true, image: DD.image),
        WQuad(shape: mainShape, texCoords: mainSR, color: DD.color, beforeChildren: true, image: DD.image)
      ]
    else:
      let shape = rectShape(position = vec3f(pos.x.float, pos.y.float, 0.0f), dimensions = vec2i(dim.x, dim.y))
      @[
        WQuad(shape: shape, texCoords: mainSR, color: DD.color, beforeChildren: true, image: DD.image)
      ]
  else:
    @[]

method intrinsicSize*(ws: DividerComponent, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] =
  if widget.hasData(Divider):
    if axis == Axis.Y:
      let DD = widget.data(Divider)
      some(clamp(DD.image.asImage.dimensions[axis] * DD.pixelScale, minimums[axis], maximums[axis]))
    else:
      none(int)
  else:
    none(int)



method readDataFromConfig*(ws: DividerComponent, cv: ConfigValue, widget: Widget) =
  if cv["type"].asStr("").toLowerAscii == "divider":
    if not widget.hasData(Divider):
      var td: Divider
      readFromConfig(cv, td)
      widget.attachData(td)
    else:
      readFromConfig(cv, widget.data(Divider)[])