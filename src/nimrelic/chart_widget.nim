import config/config_helpers
import rich_text
import graphics
import graphics/fonts
import windowingsystem/windowing_system_core
import options
import prelude
import reflect
import arxmath
import config
import strutils
import sugar
import windowingsystem/rich_text_layout
import worlds
import engines/event_types
import noto
import engines/key_codes
import nimgl/glfw
import math


type
   AxisType* {.pure.} = enum
      Numeric
      Integral
      Date

   ChartAxis* = object
      name*: string
      axis*: Axis
      axisType*: AxisType
      min*: float64
      max*: float64

   DisplayAxis* = object
      min: float64
      max: float64
      interval: float64

   ChartLine* = object
      xAxisIndex*: int
      yAxisIndex*: int
      points*: seq[Vec2d]

   Chart* = object
      axes*: seq[ChartAxis]
      lines*: seq[ChartLine]



   ChartDisplay* = object
      fontSize*: int
      font*: Option[ArxTypeface]
      chart : Chart
      chartBackgroundColor*: Option[RGBA]


   ChartDisplayRenderer* = ref object of WindowingComponent

defineDisplayReflection(ChartDisplay)


proc setChartData*(w : Widget, chart : Chart) =
   w.data(ChartDisplay).chart = chart
   w.markForUpdate(RecalculationFlag.Contents)



proc readFromConfig*(cv: ConfigValue, td: var ChartDisplay) =
   readIntoOrElse(cv["fontSize"], td.fontSize, 12)
   readIntoOrElse(cv["font"], td.font, none(ArxTypeface))
   readInto(cv["chartBackgroundColor"], td.chartBackgroundColor)

proc scaled*(axis: ChartAxis, value: float) : float =
   if axis.min == axis.max:
      0.0
   else:
      (value - axis.min) / (axis.max - axis.min)

proc scaled*(axis: DisplayAxis, value: float) : float =
   if axis.min == axis.max:
      0.0
   else:
      (value - axis.min) / (axis.max - axis.min)


proc calculateDisplayAxis(axis: ChartAxis): DisplayAxis =
   let maxTicks = 10.0f
   let range = axis.max - axis.min
   if range == 0.0f:
      return DisplayAxis(min: axis.min, max: axis.max, interval: 1.0f)
   let minInterval = range / maxTicks
   let orderOfMagnitude = pow(10, floor(log10(minInterval)))
   let residual = minInterval/orderOfMagnitude
   let interval = if residual > 5.0f:
      10.0 * orderOfMagnitude
   elif residual > 2.0f:
      5.0 * orderOfMagnitude
   elif residual > 1.0f:
      2.0 * orderOfMagnitude
   else:
      orderOfMagnitude

   let numTicks = ceil(range / interval)

   if axis.min == 0.0f:
      DisplayAxis(min: axis.min, max: axis.min + interval * numTicks, interval: interval)
   else:
      warn &"Non-zero min when calculating display axis, might want to think about how exactly we want to treat that"
      DisplayAxis(min: axis.min, max: axis.min + interval * numTicks, interval: interval)

proc formatTickNumber(f : float, interval: float) : string =
   let (integral,decimal) = splitDecimal(f)
   if decimal == 0.0:
      &"{integral.int}"
   else:
      &"{integral.int}{decimal:0.2}"



method render*(ws: ChartDisplayRenderer, widget: Widget): seq[WQuad] =
   if widget.hasData(ChartDisplay):
      let labelAreaSize = 150.0f
      let lineWidth = 8
      let hlw = lineWidth.float/2.0f
      let tickHeight = 4
      let tickWidth = 15
      let tickTextSize = 30
      let borderSize = 4


      let CD = widget.data(ChartDisplay)
      let drawArea = rect(vec2f(labelAreaSize,labelAreaSize), vec2f(widget.resolvedDimensions.x.float - labelAreaSize*2.0f, widget.resolvedDimensions.y.float - labelAreaSize * 2.0f))

      proc toWPos(v : Vec2f) : Vec3f = vec3f(v.x * drawArea.width, v.y * drawArea.height, 0.0f)
      proc finalizePos(v: Vec3f) : Vec3f = vec3f(drawArea.x + v.x, drawArea.y + drawArea.height - v.y, v.z)

      let oval = image("nimrelic/images/oval.png")

      if CD.chartBackgroundColor.isSome:
         result.add(WQuad(
                     shape: rectShape(
                        position = vec3f(drawArea.x, drawArea.y, 0.0f),
                        dimensions = vec2i(drawArea.width.int, drawArea.height.int)
                     ),
                     texCoords: noImageTexCoords(),
                     color: CD.chartBackgroundColor.get,
                     beforeChildren: true
                  ))

      for line in CD.chart.lines:
         let lineColor = rgba(0.25f,0.35f,0.8f,1.0f)

         let xAxis = CD.chart.axes[line.xAxisIndex]
         let yAxis = CD.chart.axes[line.yAxisIndex]

         let yDisplayAxis = calculateDisplayAxis(yAxis)
         info &"Display axis: {yDisplayAxis}"

         var scaledPoints : seq[Vec2f]
         for point in line.points:
            let xScaled = xAxis.scaled(point.x)
            let yScaled = yDisplayAxis.scaled(point.y)
            scaledPoints.add(vec2f(xScaled, yScaled))



         for i in 0 ..< scaledPoints.len:
            result.add(WQuad(
               shape: polyShape([
                                 finalizePos(toWPos(scaledPoints[i]) + vec3f(-hlw, hlw, 0.0f)),
                                 finalizePos(toWPos(scaledPoints[i]) + vec3f(hlw, hlw, 0.0f)),
                                 finalizePos(toWPos(scaledPoints[i]) + vec3f(hlw, -hlw, 0.0f)),
                                 finalizePos(toWPos(scaledPoints[i]) + vec3f(-hlw, -hlw, 0.0f)),
                              ]),
               texCoords: simpleTexCoords(),
               image: imageLike(oval),
               color: lineColor,
               beforeChildren: true))


            if i < scaledPoints.len - 1:
               let delta = scaledPoints[i+1]-scaledPoints[i]
               let forward = delta.normalizeSafe
               let up = vec3f(-forward.y, forward.x, 0.0f)

               let points = [
                  finalizePos(toWPos(scaledPoints[i]) + up * (hlw)),
                  finalizePos(toWPos(scaledPoints[i+1]) + up * (hlw)),
                  finalizePos(toWPos(scaledPoints[i+1]) - up * (hlw)),
                  finalizePos(toWPos(scaledPoints[i]) - up * (hlw)),
               ]

               result.add(WQuad(
                  shape: polyShape(points),
                  texCoords: noImageTexCoords(),
                  color: lineColor,
                  beforeChildren: true))


      # Border
      for (pos,dim) in @[(vec3f(drawArea.x - borderSize.float, drawArea.y - borderSize.float, 0.0f), vec2i(borderSize,drawArea.height.int + borderSize * 2)),
                           (vec3f(drawArea.x + drawArea.width, drawArea.y - borderSize.float, 0.0f), vec2i(borderSize, drawArea.height.int + borderSize * 2)),
                           (vec3f(drawArea.x - borderSize.float, drawArea.y + drawArea.height, 0.0f), vec2i(drawArea.width.int + bordersize * 2, borderSize)),
                           (vec3f(drawArea.x - borderSize.float, drawArea.y - borderSize.float, 0.0f), vec2i(drawArea.width.int + borderSize * 2, borderSize))
                           ]:
         result.add(WQuad(
            shape: rectShape(
               position = pos,
               dimensions = dim
            ),
            texCoords: noImageTexCoords(),
            color: rgba(0.0f,0.0f,0.0f,1.0f),
            beforeChildren: true
         ))

      # Ticks and labelling
      for axis in CD.chart.axes:
         if axis.axis == Axis.Y:
            let yDisplayAxis = calculateDisplayAxis(axis)
            let renderSettings = RichTextrenderSettings()

            var tick = yDisplayAxis.min
            while tick <= yDisplayAxis.max * 1.00001:
               let tickPos = finalizePos(toWPos(vec2f(0.0f,yDisplayAxis.scaled(tick)))) - vec3f(tickWidth.float,tickHeight.float/2.0f,0.0f)
               result.add(WQuad(
                  shape: rectShape(
                     position = tickPos,
                     dimensions = vec2i(tickWidth,tickHeight)
                  ),
                  texCoords: noImageTexCoords(),
                  color: rgba(0.0f,0.0f,0.0f,1.0f),
                  beforeChildren: true
               ))

               let tickText = formatTickNumber(tick, yDisplayAxis.interval)
               var textLayout = layout(richText(tickText), tickTextSize, rect(vec2i(0,0), vec2i(labelAreaSize.int - tickWidth * 2,1000000)), 2, RichTextRenderSettings(horizontalAlignment: some(HorizontalAlignment.Right)))

               for quad in textLayout.quads.mitems:
                  quad.move(0.0f, tickPos.y - tickTextSize.float/2.0f, 0.0f)
               result.add(textLayout.quads)


               tick += yDisplayAxis.interval


method readDataFromConfig*(ws: ChartDisplayRenderer, cv: ConfigValue, widget: Widget) =
   let typeStr = cv["type"].asStr("").toLowerAscii
   if typeStr == "chartdisplay":
      if not widget.hasData(ChartDisplay):
         var td: ChartDisplay
         readFromConfig(cv, td)
         widget.attachData(td)
      else:
         readFromConfig(cv, widget.data(ChartDisplay)[])