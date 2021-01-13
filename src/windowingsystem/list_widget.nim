import config/config_helpers
import graphics
import windowing_system_core
import options
import prelude
import reflect
import arxmath
import config
import strutils
import arxregex
import noto
import tables
import worlds

type
   ListWidget* = object
      widget*: Widget
      gapSize*: int
      separatorArchetype*: Option[WidgetArchetypeIdentifier]
      listItemArchetype*: WidgetArchetypeIdentifier
      selectable*: bool
      sourceBinding*: string
      targetBinding*: string
      listItemChildren*: seq[Widget]
      separatorChildren*: seq[Widget]
      horizontal*: bool

   ListItemWidget* = object
      data*: BoundValue

   ListWidgetComponent* = ref object of WindowingComponent

   ListItemMouseOver* = ref object of WidgetEvent
      index*: int
      data*: BoundValue

   ListItemSelect* = ref object of WidgetEvent
      index*: int
      data*: BoundValue

defineDisplayReflection(ListWidget)
defineDisplayReflection(ListItemWidget)


method updateBindings*(ws: ListWidgetComponent, widget: Widget, resolver: var BoundValueResolver) =
   if widget.hasData(ListWidget):
      let lw = widget.data(ListWidget)
      let boundSrcValue = resolver.resolve(lw.sourceBinding)
      if boundSrcValue.kind == BoundValueKind.Empty:
         discard
      elif boundSrcValue.kind != BoundValueKind.Seq:
         warn &"Updating binding for list widget with non-empty, non-seq value: {boundSrcValue}"
      else:
         var contentsChanged = false
         # Map each of the values in the bound seq to the appropriate value for each child, creating children as needed
         for i in 0 ..< boundSrcValue.values.len:
            let value = boundSrcValue.values[i]
            if lw.listItemChildren.len <= i:
               contentsChanged = true
               let newItem = widget.createChild(lw.listItemArchetype)
               newItem.attachData(ListItemWidget())
               newItem.identifier = widget.identifier & ".item[" & $i & "]"

               capture newItem, i:
                  newItem.onEvent(WidgetMouseEnter, enter):
                     display.addEvent(ListItemMouseOver(index: i, data: newItem.data(ListItemWidget).data, widget: newItem))
                  if lw.selectable:
                     newItem.onEvent(WidgetMouseRelease, evt):
                        display.addEvent(ListItemSelect(index: i, data: newItem.data(ListItemWidget).data, widget: newItem))

               lw.listItemChildren.add(newItem)
               if i != 0:
                  if lw.separatorArchetype.isSome:
                     let separator = widget.createChild(lw.separatorArchetype.get)
                     separator.identifier = widget.identifier & ".separator[" & $(i-1) & "]"
                     lw.separatorChildren.add(separator)
                     if not lw.horizontal:
                        separator.position[Axis.Y.ord] = relativePos(lw.listItemChildren[i-1].identifier, lw.gapSize, WidgetOrientation.BottomLeft)
                        newItem.position[Axis.Y.ord] = relativePos(separator.identifier, lw.gapSize, WidgetOrientation.BottomLeft)
                     else:
                        separator.position[Axis.X.ord] = relativePos(lw.listItemChildren[i-1].identifier, lw.gapSize, WidgetOrientation.BottomRight)
                        newItem.position[Axis.X.ord] = relativePos(separator.identifier, lw.gapSize, WidgetOrientation.BottomRight)
                  else:
                     if not lw.horizontal:
                        newItem.position[Axis.Y.ord] = relativePos(lw.listItemChildren[i-1].identifier, lw.gapSize, WidgetOrientation.BottomLeft)
                     else:
                        newItem.position[Axis.X.ord] = relativePos(lw.listItemChildren[i-1].identifier, lw.gapSize, WidgetOrientation.BottomRight)

            lw.listItemChildren[i].bindValue(lw.targetBinding, value)
            if value.kind == BoundValueKind.Nested:
               if value.nestedValues.contains("data"):
                  lw.listItemChildren[i].data(ListItemWidget).data = value.nestedValues["data"]
         # Clean up any children that are no longer needed
         let numValues = boundSrcValue.values.len
         if numValues < lw.listItemChildren.len:
            for i in numValues .. (lw.listItemChildren.len - 1):
               contentsChanged = true
               lw.listItemChildren[i].destroyWidget()
               if lw.separatorArchetype.isSome:
                  lw.separatorChildren[i-1].destroyWidget()
         lw.listItemChildren.setLen(boundSrcValue.values.len)
         if lw.separatorArchetype.isSome:
            lw.separatorChildren.setLen(max(boundSrcValue.values.len-1, 0))

         if contentsChanged:
            for e in enumValues(RecalculationFlag):
               widget.markForUpdate(e)




method render*(ws: ListWidgetComponent, widget: Widget): seq[WQuad] =
   discard





const bindingPattern = re"([a-zA-Z0-9.]+)\s->\s([a-zA-Z0-9.]+)"

proc readFromConfig*(cv: ConfigValue, v: var ListWidget) =
   readIntoOrElse(cv["gapSize"], v.gapSize, 2)
   readIntoOrElse(cv["separatorArchetype"], v.separatorArchetype, none(WidgetArchetypeIdentifier))
   readInto(cv["listItemArchetype"], v.listItemArchetype)
   readIntoOrElse(cv["selectable"], v.selectable, true)
   readInto(cv["horizontal"], v.horizontal)
   if not cv["vertical"].asBool(true): v.horizontal = true

   if cv.hasField("sourceBinding") and cv.hasField("targetBinding"):
      readInto(cv["sourceBinding"], v.sourceBinding)
      readInto(cv["targetBinding"], v.targetBinding)
   elif cv.hasField("listItemBinding"):
      matcher(cv["listItemBinding"].asStr):
         extractMatches(bindingPattern, fromBinding, toBinding):
            v.sourceBinding = fromBinding
            v.targetBinding = toBinding
         let cvstr = cv["listItemBinding"].asStr
         warn &"Invalid listItemBinding str: {cvstr}"
   else:
      warn "List widget must have a sourceBinding and targetBinding, or a listItemBinding expression"


method readDataFromConfig*(ws: ListWidgetComponent, cv: ConfigValue, widget: Widget) =
   let lowerType = cv["type"].asStr("").toLowerAscii
   if lowerType == "list" or lowerType == "listwidget":
      if not widget.hasData(ListWidget):
         var td: ListWidget
         readFromConfig(cv, td)
         widget.attachData(td)
      else:
         readFromConfig(cv, widget.data(ListWidget)[])
