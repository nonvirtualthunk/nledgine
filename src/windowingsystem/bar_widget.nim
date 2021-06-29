import windowingsystem/windowing_system_core
import config
import config/config_helpers
import graphics
import arxregex
import options
import reflect
import strutils
import windowingsystem/text_widget
import tables


type
  BarWidget* = object
    widget*: Widget
    currentValue*: Bindable[float]
    maxValue*: Bindable[float]
    frame*: NineWayImage
    fill*: NineWayImage
    pixelScale*: int
    textDisplay*: Widget
    textConfig*: ConfigValue

  BarWidgetComponent* = ref object of WindowingComponent


defineDisplayReflection(BarWidget)



method updateBindings*(ws: BarWidgetComponent, widget: Widget, resolver: var BoundValueResolver) =
  if widget.hasData(BarWidget):
    let updated = updateBindings(widget.data(BarWidget)[], resolver)

    if updated:
      widget.markForUpdate(RecalculationFlag.Contents)

    if updated or not widget.data(BarWidget).textDisplay.hasBinding("barText"):
      let cur = widget.data(BarWidget).currentValue.value
      let max = widget.data(BarWidget).maxValue.value
      let str = if cur == cur.int.float and max == max.int.float:
        $cur.int & "/" & $max.int
      else:
        $cur & "/" & $max
      widget.data(BarWidget).textDisplay.bindValue("barText",richText(str))


method render*(ws: BarWidgetComponent, widget: Widget): seq[WQuad] =
  if widget.hasData(BarWidget):
    let bw = widget.data(BarWidget)
    for quad in nineWayImageQuads(bw.frame, widget.resolvedDimensions, bw.pixelScale):
      result.add(quad)

    let frameImg = bw.frame.image.asImage
    let imgMetrics = imageMetricsFor(frameImg)
    let sizeOffset = -imgMetrics.borderWidth

    var nwi = bw.fill
    nwi.dimensionDelta = vec2i(sizeOffset, sizeOffset)
    let pcnt = if bw.maxValue != 0.0f:
      max(min(bw.currentValue / bw.maxValue, 1.0), 0.0)
    else:
      1.0

    if pcnt > 0.0001:
      for quad in nineWayImageQuads(nwi, vec2i((widget.resolvedDimensions.x.float * pcnt).int, widget.resolvedDimensions.y), bw.pixelScale, true):
        result.add(quad)


proc readFromConfig*(cv: ConfigValue, bw: var BarWidget) =
  cv["currentValue"].readInto(bw.currentValue)
  cv["maxValue"].readInto(bw.maxValue)
  cv["frame"].readInto(bw.frame)
  cv["fill"].readInto(bw.fill)
  cv["pixelScale"].readIntoOrElse(bw.pixelScale, 1)
  bw.textConfig = cv["text"]

method readDataFromConfig*(ws: BarWidgetComponent, cv: ConfigValue, widget: Widget) =
  let typeStr = cv["type"].asStr("").toLowerAscii
  if typeStr == "bar" or typeStr == "barwidget":
    if not widget.hasData(BarWidget):
      var bw: BarWidget
      readFromConfig(cv, bw)
      widget.attachData(bw)
    else:
      readFromConfig(cv, widget.data(BarWidget)[])


method onCreated*(ws: BarWidgetComponent, widget: Widget) =
  if widget.hasData(BarWidget):
    let bw = widget.data(BarWidget)
    let baseConfig = config("ui/widgets/bar_widgets.sml")["BarText"]
    let conf = baseConfig.overlay(bw.textConfig)
    bw.textDisplay = createWidgetFromConfig(widget.windowingSystem, "BarText", conf, widget)
    bw.textDisplay.showing = bindable(bw.textConfig.nonEmpty)
