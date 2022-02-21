import windowing_system_core
import config
import graphics/images
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
  ImageDisplayScalingStyle* = enum
    ScaleToFit
    Scale
    ScaleToAxis

  ImageDisplayScale* = object
    case kind: ImageDisplayScalingStyle
    of ScaleToFit: discard
    of Scale:
      scale: float
    of ScaleToAxis:
      axis: Axis
      targetSize: int

  ConditionalImage = object
    condition: Bindable[bool]
    image: Bindable[ImageRef]
    color: Bindable[RGBA]

  ImageDisplay* = object
    widget*: Widget
    image*: Bindable[ImageRef]
    conditionalImage*: seq[ConditionalImage]
    scale*: ImageDisplayScale
    color*: Bindable[RGBA]
    fractionalScaling*: bool
    drawAfterChildren*: bool

  ImageDisplayComponent* = ref object of WindowingComponent

const scaleToFitPattern = re"(?i)scale\s?to\s?fit"
const scaleFractionPattern = re"scale\(([0-9.]+)\)"
const scalePercentPattern = re"scale\(([0-9]+)%\)"
const scaleToAxisPattern = re"(?i)scale\s?to\s?(width|height)\(?([0-9]+)px\)?"
proc readFromConfig*(cv: ConfigValue, v: var ImageDisplayScale) =
  if cv.isEmpty: discard
  elif cv.isStr:
    matcher(cv.asStr):
      extractMatches(scaleFractionPattern, scale):
        v = ImageDisplayScale(kind: Scale, scale: parseFloat(scale))
      extractMatches(scalePercentPattern, scalePcnt):
        v = ImageDisplayScale(kind: Scale, scale: parseFloat(scalePcnt) / 100.0)
      extractMatches(scaleToAxisPattern, wh, target):
        let axis = if wh == "width": Axis.X else: Axis.Y
        v = ImageDisplayScale(kind: ScaleToAxis, axis: axis, targetSize: parseInt(target))
      extractMatches(scaleToFitPattern):
        v = ImageDisplayScale(kind: ScaleToFit)
      warn &"invalid str format for image display scale: {cv.asStr}"
  else:
    warn &"invalid config for image display scale: {cv}"

proc readFromConfig*(cv: ConfigValue, v: var ConditionalImage) =
  if cv.isObj:
    cv["condition"].readIntoOrElse(v.condition, bindable(true))
    cv["image"].readInto(v.image)
    cv["color"].readIntoOrElse(v.color, bindable(rgba(1.0,1.0,1.0,1.0)))
  else:
    warn &"Unsupported config format for conditional image section: {cv}"

proc readFromConfig*(cv: ConfigValue, v: var ImageDisplay) =
  readIntoOrElse(cv["image"], v.image, bindable(imageRef("images/defaultium.png")))
  readIntoOrElse(cv["conditionalImage"], v.conditionalImage, @[])
  readIntoOrElse(cv["scale"], v.scale, ImageDisplayScale(kind: Scale, scale: 1.0))
  readIntoOrElse(cv["fractionalScaling"], v.fractionalScaling, false)
  readIntoOrElse(cv["color"], v.color, bindable(rgba(1.0, 1.0, 1.0, 1.0)))
  readIntoOrElse(cv["drawImageAfterChildren"], v.drawAfterChildren, false)

defineDisplayReflection(ImageDisplay)


proc effectiveImage*(ID: ref ImageDisplay) : ImageRef =
  result = ID.image.value
  for ci in ID.conditionalImage:
    if ci.condition.value:
      result = ci.image.value
      break

proc effectiveColor*(ID: ref ImageDisplay) : RGBA =
  result = ID.color.value
  for ci in ID.conditionalImage:
    if ci.condition.value:
      result = result * ci.color.value
      break


proc calcSize(ID: ref ImageDisplay, widget: Widget, axis: Axis): int =
  let img = ID.effectiveImage.asImage
  case ID.scale.kind:
  of Scale:
    (img.dimensions[axis].float * ID.scale.scale).int * widget.pixelScale
  of ScaleToAxis:
    let effScale = if ID.fractionalScaling: ID.scale.targetSize / img.dimensions[ID.scale.axis]
              else: (ID.scale.targetSize div img.dimensions[ID.scale.axis]).float
    (img.dimensions[axis].float * effScale).int * widget.pixelScale
  of ScaleToFit:
    if ID.fractionalScaling:
      let xscale = widget.resolvedDimensions.x.float / img.dimensions.x.float
      let yscale = widget.resolvedDimensions.y.float / img.dimensions.y.float
      (img.dimensions[axis].float * min(xscale, yscale)).int
    else:
      let xscale = widget.resolvedDimensions.x div img.dimensions.x
      let yscale = widget.resolvedDimensions.y div img.dimensions.y
      if xscale == 0 or yscale == 0:
        let xscale = widget.resolvedDimensions.x.float / img.dimensions.x.float
        let yscale = widget.resolvedDimensions.y.float / img.dimensions.y.float
        (img.dimensions[axis].float * min(xscale, yscale)).int
      else:
        img.dimensions[axis] * min(xscale, yscale)

proc calcPos(ID: ref ImageDisplay, widget: Widget, axis: Axis, axisDim: int): int =
  (widget.resolvedDimensions[axis] - widget.clientOffset[axis] * 2 - axisDim) div 2

method render*(ws: ImageDisplayComponent, widget: Widget): seq[WQuad] =
  if widget.hasData(ImageDisplay):
    let ID = widget.data(ImageDisplay)
    let width = calcSize(ID, widget, Axis.X)
    let height = calcSize(ID, widget, Axis.Y)
    let x = calcPos(ID, widget, Axis.X, width)
    let y = calcPos(ID, widget, Axis.Y, height)

    let color = ID.effectiveColor

    @[WQuad(shape: rectShape(position = vec3f(x.float, y.float, 0.0f), dimensions = vec2i(width, height), forward = vec2f(1.0f, 0.0f)), texCoords: simpleTexCoords(), color: color, beforeChildren: not ID.drawAfterChildren,
        image: ID.effectiveImage.asImage)]
  else:
    @[]

method intrinsicSize*(ws: ImageDisplayComponent, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] =
  if widget.hasData(ImageDisplay):
    let ID = widget.data(ImageDisplay)
    case ID.scale.kind:
    of Scale, ScaleToAxis:
      let rawSize = calcSize(ID, widget, axis)
      # todo: this doesn't maintain the aspect ratio, it's not great
      some(clamp(rawSize, minimums[axis], maximums[axis]))
    else:
      none(int)
  else:
    none(int)

method readDataFromConfig*(ws: ImageDisplayComponent, cv: ConfigValue, widget: Widget) =
  if cv["type"].asStr("").toLowerAscii == "imagedisplay":
    if not widget.hasData(ImageDisplay):
      var td: ImageDisplay
      readFromConfig(cv, td)
      widget.attachData(td)
    else:
      readFromConfig(cv, widget.data(ImageDisplay)[])

proc updateAllBindings*(id: var ImageDisplay, resolver : var BoundValueResolver) : bool =
  result = updateBindings(id, resolver)
  for ct in id.conditionalImage.mitems:
    result = updateBindings(ct.condition, resolver) or result
    result = updateBindings(ct.image, resolver) or result

method updateBindings*(ws: ImageDisplayComponent, widget: Widget, resolver: var BoundValueResolver) =
  if widget.hasData(ImageDisplay) and updateAllBindings(widget.data(ImageDisplay)[], resolver):
    widget.markForUpdate(RecalculationFlag.Contents)
    if widget.width.isIntrinsic:
      widget.markForUpdate(RecalculationFlag.DimensionsX)
    if widget.height.isIntrinsic:
      widget.markForUpdate(RecalculationFlag.DimensionsY)
