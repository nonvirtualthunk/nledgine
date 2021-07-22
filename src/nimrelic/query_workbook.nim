import engines
import graphics
import prelude
import tables
import graphics/canvas
import core
import game/library
import options
import reflect
import graphics/taxonomy_display
import algorithm
import noto
import windowingsystem/windowing_system_core
import nimrelic/nrquery
import sequtils
import asyncdispatch
import unicode
import windowingsystem/text_widget
import nimrelic/chart_widget
import nimrelic/query_history
import nimrelic/nrql

type
   QueryWorkbookComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas
      workbookWidget: Widget
      query: Future[QResponse]
      updated: bool
      history: seq[string]
      queryHistory: QueryHistory
      queryInput: Widget

   ResultColumn* = object
      heading*: string
      values*: seq[string]

   ActiveType* = object
      error*: bool
      grid*: bool
      chart*: bool



proc highlightNrql(str: string): RichText

method initialize(g: QueryWorkbookComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "QueryWorkbookComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")

   display[WindowingSystem].desktop.background = nineWayImage("ui/singlePixelBorder.png")
   g.workbookWidget = display[WindowingSystem].desktop.createChild("QueryWorkbook", "WorkbookWidget")

   g.queryInput = g.workbookWidget.childByIdentifier("queryInput").get()
   g.queryInput.data(TextInput).textDataToRichTextTransformer = highlightNrql
   g.queryInput.takeFocus(world)

   g.queryHistory = loadQueryHistory()

   # queryInput.onEventOfType(TextDataEnter, enter):
   #    g.query = queryAsync(313870, enter.textData)
   #    g.updated = false




proc render(g: QueryWorkbookComponent, display: DisplayWorld) =
   g.canvas.swap()



method update(g: QueryWorkbookComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   if not g.updated and g.query != nil and g.query.finished:
      let response = g.query.read

      var active: ActiveType
      if response.error.isSome:
         active.error = true
         g.workbookWidget.bindValue("error.message", response.error.get)
      else:
         if response.results.nonEmpty:
            let res = response.results[0]
            case res.kind:
               of QResultType.Aggregate:
                  active.grid = true
                  var columns: seq[ResultColumn]

                  for result in response.results:
                     case result.kind:
                        of QResultType.Aggregate:
                           columns.add(ResultColumn(heading: result.label, values: @[$result.value]))
                        else:
                           warn &"Non-aggregate result mixed with aggregates?"

                  g.workbookWidget.bindValue("results.columns", columns)
               of QResultType.Facet:
                  active.grid = true
                  var columns: seq[ResultColumn]

                  var facetColumns : seq[ResultColumn]
                  var valueColumns : Table[string, ResultColumn]

                  let facetedRes = response.results[0]
                  for i in 0 ..< facetedRes.facetAttributes.len:
                     let facetAttr = facetedRes.facetAttributes[i]
                     facetColumns.add(ResultColumn(heading: facetAttr))


                  for facetValues, facetResults in facetedRes.facetedResults:
                     for i in 0 ..< facetValues.len:
                        facetColumns[i].values.add($facetValues[i])
                     for subResult in facetResults:
                        case subResult.kind:
                           of QResultType.Aggregate:
                              discard valueColumns.hasKeyOrPut(subResult.label):
                                 ResultColumn(heading: subResult.label)
                              valueColumns[subResult.label].values.add($subResult.value)
                           else:
                              warn &"Non-aggregate result mixed with aggregates?"

                  columns.add(facetColumns)
                  for column in valueColumns.values:
                     columns.add(column)


                  g.workbookWidget.bindValue("results.columns", columns)
               of QResultType.Events:
                  active.grid = true
                  var columns: seq[ResultColumn]
                  for c in res.columns:

                     columns.add(ResultColumn(heading: c.attributeName, values: c.values.mapIt($it)))

                  g.workbookWidget.bindValue("results.columns", columns)
               of QResultType.Timeseries:
                  active.chart = true
                  let chartDisplay = g.workbookWidget.descendantByIdentifier("chartResult").get()

                  # Pass to set up the axes
                  var chart : Chart = Chart(axes: @[])
                  for bucket in res.buckets:
                     let t = ((bucket.startTimeSeconds + bucket.endTimeSeconds)/2).float
                     if chart.axes.len == 0:
                        chart.axes.add(ChartAxis(name: "Time", axis: Axis.X, axisType: AxisType.Date, min: t, max: t))
                     chart.axes[0].min = min(chart.axes[0].min, t)
                     chart.axes[0].max = max(chart.axes[0].max, t)

                     for i in 0 ..< bucket.results.len:
                        let subRes = bucket.results[i]
                        case subRes.kind:
                           of QResultType.Aggregate:
                              if chart.axes.len < i+2:
                                 chart.axes.add(ChartAxis(name: subRes.label, axis: Axis.Y, axisType: AxisType.Numeric, min: 0.0f, max: 0.0f))
                                 chart.lines.add(ChartLine(xAxisIndex: 0, yAxisIndex: i+1, points: @[]))
                              chart.axes[i+1].min = min(chart.axes[i+1].min, subRes.value.asFloat)
                              chart.axes[i+1].max = max(chart.axes[i+1].max, subRes.value.asFloat)
                              chart.lines[i].points.add(vec2d(t, subRes.value.asFloat))
                           else:
                              warn &"Non-aggregate sub-result in timeseries"



                  info &"Setting chart {chart}"
                  chartDisplay.setChartData(chart)
         else:
            active.error = true
            g.workbookWidget.bindValue("error.message", "No results")

      g.workbookWidget.bindValue("active", active)
      g.updated = true

   @[g.canvas.drawCommand(display)]

method onEvent(g: QueryWorkbookComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   matcher(event):
      extract(TextDataEnter, widget, textData):
         if widget.identifier == "queryInput":
            g.query = queryAsync(313870, textData)
            g.queryHistory.recordQuery(textData)
            g.queryHistory.saveQueryHistory()
            g.updated = false
         else:
            warn &"unexpected text data enter? : {textData}, {widget.identifier}"
      extract(TextDataChange, widget):
         let textData = widget.data(TextInput).textData
         if g.queryHistory.cursor == -1 or g.queryHistory.queryAtCursor.queryString != textData:
            g.queryHistory.cursor = -1
            g.queryHistory.setActiveQuery(textData)
      extract(KeyPress, key):
         if key == KeyCode.Up:
            g.queryInput.setTextData(g.queryHistory.moveCursorBack().queryString)
         elif key == KeyCode.Down:
            g.queryInput.setTextData(g.queryHistory.moveCursorForward().queryString)
   discard



const colorsByTokenKind = {
   TSELECT
}

proc highlightNrql(str: string): RichText =
   var prevColor = rgba(0,0,0,0)

   let tokens = tokenizeNrqlSeq(str)
   var tokenIndex = 0
   var section = ""
   var formatting: seq[RichTextFormatRange]
   for token in tokens:
      let color = if token.isKeyword:
         rgba(195,151,216,255)
      elif token.isOperator:
         rgba(112,192,177,255)
      elif token.kind == TIDENTIFIER:
         rgba(222,222,222,255)
      elif token.kind == TNUMBER:
         rgba(231,140,69,255)
      elif token.kind == TLITERAL:
         rgba(185,202,74,255)
      else:
         rgba(255,255,255,255)

      formatting.add(RichTextFormatRange(startIndex: token.startIndex, endIndex: token.endIndex, color: some(color)))

   richText(RichTextSection(kind: SectionKind.Text, text: str, formatRanges: formatting))
   #[
   for i in 0 ..< str.len:
      while tokenIndex < tokens.len and tokens[tokenIndex].endIndex <= i:
         tokenIndex.inc
      if tokenIndex >= tokens.len:
         section.add(str[i])
         break

      let token = tokens[tokenIndex]
      let color = if token.isKeyword:
         rgba(195,151,216,255)
      elif token.isOperator:
         rgba(112,192,177,255)
      elif token.kind == TIDENTIFIER:
         rgba(222,222,222,255)
      elif token.kind == TNUMBER:
         rgba(231,140,69,255)
      elif token.kind == TLITERAL:
         rgba(185,202,74,255)
      else:
         rgba(255,255,255,255)

      if color != prevColor:
         if section.len > 0:
            result.add(richText(section, color = some(prevColor)))
            section = ""
         prevColor = color

      section.add(str[i])

   if section.len > 0:
      result.add(richText(section, color = some(prevColor)))
      ]#
