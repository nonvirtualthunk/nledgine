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

type
   QueryWorkbookComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas
      workbookWidget: Widget
      query: Future[QResponse]
      updated: bool

   ResultColumn* = object
      heading*: string
      values*: seq[string]

   ActiveType* = object
      error*: bool
      grid*: bool

method initialize(g: QueryWorkbookComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "QueryWorkbookComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")

   display[WindowingSystem].desktop.background = nineWayImage("ui/singlePixelBorder.png")
   g.workbookWidget = display[WindowingSystem].desktop.createChild("QueryWorkbook", "WorkbookWidget")

   let queryInput = g.workbookWidget.childByIdentifier("queryInput").get()
   queryInput.takeFocus(world)

   # queryInput.onEvent(TextDataEnter, enter):
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
               of QResultType.Events:
                  active.grid = true
                  var columns: seq[ResultColumn]
                  for c in res.columns:

                     columns.add(ResultColumn(heading: c.attributeName, values: c.values.mapIt($it)))

                  g.workbookWidget.bindValue("results.columns", columns)
               else:
                  info &"Unsupported QResultType"
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
            g.updated = false
         else:
            warn &"unexpected text data enter? : {textData}, {widget.identifier}"
   discard

