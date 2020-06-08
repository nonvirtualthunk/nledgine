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


type
   ImageDisplayScalingStyle* = enum
      ScaleToFit
      Scale
      ScaleToAxis

   ImageDisplayScale* = object
      case kind : ImageDisplayScalingStyle
      of ScaleToFit: discard
      of Scale: 
         scale : float
      of ScaleToAxis: 
         axis : Axis
         targetSize : int

   ImageDisplay* = object
      widget* : Widget
      image* : Bindable[ImageLike]
      scale* : ImageDisplayScale
      color* : Bindable[RGBA]
      fractionalScaling* : bool

   ImageDisplayComponent* = ref object of WindowingComponent

const scaleToFitPattern = re"(?i)scale\s?to\s?fit"
const scaleFractionPattern = re"scale\(([0-9.]+)\)"
const scalePercentPattern = re"scale\(([0-9]+)%\)"
const scaleToAxisPattern = re"(?i)scale\s?to\s?(width|height)\(?([0-9]+)px\)?"
proc readFromConfig*(cv : ConfigValue, v : var ImageDisplayScale) =
   if cv.nonEmpty: discard
   elif cv.isStr:
      matcher(cv.asStr):
         extractMatches(scaleFractionPattern, scale):
            v = ImageDisplayScale(kind : Scale, scale : parseFloat(scale))
         extractMatches(scalePercentPattern, scalePcnt):
            v = ImageDisplayScale(kind : Scale, scale : parseFloat(scalePcnt) / 100.0)
         extractMatches(scaleToAxisPattern, wh, target):
            let axis = if wh == "width" : Axis.X else: Axis.Y
            v = ImageDisplayScale(kind : ScaleToAxis, axis : axis, targetSize : parseInt(target))
         extractMatches(scaleToFitPattern):
            v = ImageDisplayScale(kind : ScaleToFit)
         warn "invalid str format for image display scale: ", cv.asStr
   else:
      warn "invalid config for image display scale: ", cv

proc readFromConfig*(cv : ConfigValue, v : var ImageDisplay) =
   readIntoOrElse(cv["image"], v.image, bindable(imageLike("images/defaultium.png")))
   readIntoOrElse(cv["scale"], v.scale, ImageDisplayScale(kind : Scale, scale : 1.0))
   readIntoOrElse(cv["fractionalScaling"], v.fractionalScaling, false)
   readIntoOrElse(cv["color"], v.color, bindable(rgba(1.0,1.0,1.0,1.0)))

defineReflection(ImageDisplay)


proc calcSize(ID : ref ImageDisplay, widget : Widget, axis : Axis) : int =
   let img = ID.image.asImage
   case ID.scale.kind:
   of Scale:
      (img.dimensions[axis].float * ID.scale.scale).int
   of ScaleToAxis:
      let effScale = if ID.fractionalScaling: ID.scale.targetSize / img.dimensions[ID.scale.axis]
                     else: (ID.scale.targetSize div img.dimensions[ID.scale.axis]).float
      (img.dimensions[axis].float * effScale).int
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

proc calcPos(ID : ref ImageDisplay, widget : Widget, axis : Axis, axisDim : int) : int =
   (widget.resolvedDimensions[axis] - widget.clientOffset[axis] * 2 - axisDim) div 2

method render*(ws : ImageDisplayComponent, widget : Widget) : seq[WQuad] =
   if widget.hasData(ImageDisplay):
      let ID = widget.data(ImageDisplay)
      let width = calcSize(ID, widget, Axis.X)
      let height = calcSize(ID, widget, Axis.Y)
      let x = calcPos(ID, widget, Axis.X, width)
      let y = calcPos(ID, widget, Axis.Y, height)
      
      @[WQuad(position : vec3f(x.float,y.float,0.0f), dimensions : vec2i(width, height), forward : vec2f(1.0f,0.0f), texCoords : simpleTexCoords(), color : ID.color, beforeChildren : true, image : ID.image)]
   else:
      @[]

method intrinsicSize*(ws : ImageDisplayComponent, widget : Widget, axis : Axis) : Option[int] =
   if widget.hasData(ImageDisplay):
      let ID = widget.data(ImageDisplay)
      case ID.scale.kind:
      of Scale, ScaleToAxis:
         some(calcSize(ID, widget, axis))
      else:
         none(int)
   else:
      none(int)

method readDataFromConfig*(ws : ImageDisplayComponent, cv : ConfigValue, widget : Widget) =
   if cv["type"].asStr("").toLowerAscii == "imagedisplay":
      echo "image display detected"
      if not widget.hasData(ImageDisplay):
         var td : ImageDisplay
         readFromConfig(cv, td)
         widget.attachData(td)
      else:
         readFromConfig(cv, widget.data(ImageDisplay)[])

method updateBindings*(ws : ImageDisplayComponent, widget : Widget, resolver : var BoundValueResolver) =
   if widget.hasData(ImageDisplay) and updateBindings(widget.data(ImageDisplay)[], resolver):
      widget.markForUpdate(RecalculationFlag.Contents)
      if widget.width.isIntrinsic:
         widget.markForUpdate(RecalculationFlag.DimensionsX)
      if widget.height.isIntrinsic:
         widget.markForUpdate(RecalculationFlag.DimensionsY)
