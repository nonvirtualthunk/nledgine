import config/config_helpers
import rich_text
import graphics
import graphics/fonts
import windowing_system_core
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
import unicode
import noto
import engines/key_codes
import patty
import nimclipboard/libclipboard
import nimgl/glfw

export rich_text

const AltStopChars = {' ', '\t', '\n', ';', '\'', '"', ':', '.', ',', '(', ')', '{', '}', '/', '\\'}

variantp EditorOperation:
   RuneAppend(appendedRune: Rune, appendPosition: int)
   StringAppend(appendedString: string, stringAppendPosition: int)
   RuneDelete(deletedRune : Rune, deletePosition: int)
   TextReplace(previousText : string, index: int, newText : string)


type
   TextDisplay* = object
      widget*: Widget
      text*: Bindable[RichText]
      fontSize*: int
      font*: Option[ArxFontRoot]
      color*: Option[Bindable[RGBA]]
      tintColor*: Option[Bindable[RGBA]]
      horizontalAlignment*: Option[HorizontalAlignment]
      allowSelection*: bool
      selectedRange*: Option[(int,int)]
      selectionRect*: Recti

      textLayout*: TextLayout

   TextInput* = object
      textData_i: string
      cursorPosition*: int
      undoStack*: seq[EditorOperation]
      undoMarkers*: seq[int]

   TextDataChange* = ref object of WidgetEvent
      operation*: EditorOperation

   TextDataEnter* = ref object of WidgetEvent
      textData*: string

   TextDisplayRenderer* = ref object of WindowingComponent

defineDisplayReflection(TextDisplay)
defineDisplayReflection(TextInput)

proc readFromConfig*(cv: ConfigValue, ti: var TextInput) =
   readInto(cv["textData"], ti.textData_i)

proc readFromConfig*(cv: ConfigValue, td: var TextDisplay) =
   readInto(cv["text"], td.text)
   readIntoOrElse(cv["fontSize"], td.fontSize, 12)
   readIntoOrElse(cv["font"], td.font, none(ArxFontRoot))
   readIntoOrElse(cv["color"], td.color, none(Bindable[RGBA]))
   readInto(cv["tintColor"], td.tintColor)
   readInto(cv["horizontalAlignment"], td.horizontalAlignment)

proc markForUpdateOnChange*(w: Widget) =
   w.markForUpdate(RecalculationFlag.Contents)
   if w.width.isIntrinsic:
      w.markForUpdate(RecalculationFlag.DimensionsX)
   if w.height.isIntrinsic:
      w.markForUpdate(RecalculationFlag.DimensionsY)

template getterSetter(t: untyped): untyped {.dirty.} =
   proc `t=`*(td: ref TextDisplay, text: typeof(TextDisplay.`t`)) =
      if not td.widget.isNil and td.`t` != text:
         markForUpdateOnChange(td.widget)
      td.`t` = text

   proc `t`*(td: ref TextDisplay): typeof(TextDisplay.`t`) = td.`t`

getterSetter(fontSize)
getterSetter(text)
getterSetter(font)

proc textData*(ti: ref TextInput): string =
   ti.textData_i

proc computeLayout*(widget: Widget, inbounds: Recti = rect(vec2i(0, 0), vec2i(10000000, 1000000))): TextLayout =
   let TD = widget.data(TextDisplay)
   var bounds = inbounds
   if not widget.width.isIntrinsic:
      bounds.dimensions.x = widget.resolvedDimensions.x - widget.clientOffset.x * 2
   else:
      if widget.width.intrinsicMax.isSome:
         bounds.dimensions.x = widget.width.intrinsicMax.get.int32

   let renderSettings = RichTextRenderSettings(
      baseColor: TD.color.map(proc (v: Bindable[RGBA]): RGBA = v.value),
      tint: TD.tintColor.map(proc (v: Bindable[RGBA]): RGBA = v.value),
      defaultFont: TD.font,
      horizontalAlignment: TD.horizontalAlignment,
      textPreference: TextPreference.None
   )

   result = layout(TD.text.value, TD.fontSize * widget.windowingSystem.pixelScale, bounds, widget.windowingSystem.pixelScale, renderSettings)



method render*(ws: TextDisplayRenderer, widget: Widget): seq[WQuad] =
   if widget.hasData(TextDisplay):
      let TD = widget.data(TextDisplay)
      let layoutRes = computeLayout(widget)
      TD.textLayout = layoutRes
      
      if TD.selectedRange.isSome:
         let (minI,maxI) = TD.selectedRange.get

         for line in layoutRes.lineInfo:
            var minX : Option[int]
            var maxX : Option[int]
            for qi in line.startIndex ..< line.endIndex:
               let subI = layoutRes.quadOrigins[qi].subIndex
               if subI >= minI and subI <= maxI:
                  let quad = layoutRes.quads[qi]
                  if minX.isNone:
                     minX = some(quad.position.x.int)
                  let endX = if qi < line.endIndex - 1: layoutRes.quads[qi+1].position.x.int else: quad.position.x.int + quad.dimensions.x.int
                  maxX = some(endX)

            if minX.isSome and maxX.isSome:
               result.add(WQuad(
                                 position: vec3f(minX.get.float32,line.startY.float32 - line.maximumHeight.float32 * 0.1,0.0f),
                                 dimensions: vec2i(maxX.get - minX.get, (line.maximumHeight.float32 * 1.1).int),
                                 forward: vec2f(1.0f, 0.0f),
                                 texCoords: noImageTexCoords(),
                                 color: rgba(0.3,0.4,0.8,1.0),
                                 beforeChildren: true))

      result.add(layoutRes.quads)

      if widget.hasData(TextInput) and widget.hasFocus:
         let ti = widget.data(TextInput)
         var cursorCoord : Vec2f
         var cursorHeight : int = layoutRes.lineHeight
         var cursorIndex = layoutRes.quadOrigins.len
         for i in countdown(layoutRes.quadOrigins.len-1,0):
            if layoutRes.quadOrigins[i].subIndex >= ti.cursorPosition:
               cursorIndex = i


         if layoutRes.quadOrigins.len == 0:
            cursorCoord = vec2f(0.0f,0.0f)
         elif cursorIndex == layoutRes.quadOrigins.len:
            # special case for when we're at the end of the line
            cursorCoord = layoutRes.quads[cursorIndex-1].position.xy + vec2f(layoutRes.quads[cursorIndex-1].dimensions.x.float32,0.0f)
            cursorIndex.dec
         else:
            cursorCoord = layoutRes.quads[cursorIndex].position.xy


         for line in layoutRes.lineInfo:
            if line.startIndex <= cursorIndex and line.endIndex > cursorIndex:
               cursorCoord.y = line.startY.float
               cursorHeight = line.maximumHeight
               break


         result.add(WQuad(
            position: vec3f(cursorCoord.x, cursorCoord.y, 0.0f),
            dimensions: vec2i(5, cursorHeight),
            forward: vec2f(1.0f, 0.0f),
            texCoords: noImageTexCoords(),
            color: rgba(0.5,0.5,0.5,1.0),
            beforeChildren: true))




method intrinsicSize*(ws: TextDisplayRenderer, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] =
   if widget.hasData(TextDisplay):
      var layoutBounds = rect(vec2i(0, 0), vec2i(maximums.x, maximums.y))
      let textLayout = computeLayout(widget, layoutBounds)
      some(max(textLayout.bounds.dimensions[axis], minimums[axis]))
   else:
      none(int)

proc syncDisplayToData*(widget : Widget) =
   widget.data(TextDisplay).text = bindable(richText(widget.data(TextInput).textData))

proc textDataChanged*(operation: EditorOperation, display: DisplayWorld, widget: Widget) =
   let ti = widget.data(TextInput)
   display.addEvent(TextDataChange(operation : operation, widget: widget))
   ti.undoStack.add(operation)
   ti.undoMarkers.add(ti.undoStack.len-1)
   widget.syncDisplayToData()
   widget.markForUpdateOnChange()

proc setTextData*(widget: Widget, str: string) =
   let ti = widget.data(TextInput)
   let prevStr = ti.textData
   ti.textData_i = str
   ti.cursorPosition = str.len
   textDataChanged(TextReplace(prevStr, 0, str), widget.windowingSystem.display, widget)


proc undo(ti : ref TextInput, op: EditorOperation) =
   match op:
      RuneAppend(appendedRune, appendPosition):
         ti.textData_i.delete(appendPosition, appendPosition)
         ti.cursorPosition = appendPosition
      RuneDelete(deletedRune, deletePosition):
         ti.textData_i.insert(deletedRune.toUTF8(), deletePosition)
         ti.cursorPosition = deletePosition+1
      TextReplace(previousText, index, newText):
         ti.textData_i.delete(index, index + newText.len - 1)
         ti.textData_i.insert(previousText, index)
         ti.cursorPosition = index + previousText.len
      StringAppend(str, index):
         ti.textData_i.delete(index, index + str.len - 1)
         ti.cursorPosition = index


proc undo(w: Widget) =
   let ti = w.data(TextInput)
   let marker = if ti.undoMarkers.nonEmpty: ti.undoMarkers.last else: 0
   if ti.undoMarkers.nonEmpty:
      discard ti.undoMarkers.pop()

   while ti.undoStack.len > marker:
      let operation = ti.undoStack.last
      discard ti.undoStack.pop()
      undo(ti, operation)

   syncDisplayToData(w)
   markForUpdateOnChange(w)


proc positionToDataIndex(widget: Widget, position : Vec2i) : Option[int] =
   let td = widget.data(TextDisplay)
   for li in 0 ..< td.textLayout.lineInfo.len:
      let line = td.textLayout.lineInfo[li]
      let startY = line.startY
      let endY = if li < td.textLayout.lineInfo.len - 1: td.textLayout.lineInfo[li+1].startY else: startY + line.maximumHeight

      if position.y >= startY and position.y <= endY:
         for qi in line.startIndex ..< line.endIndex:
            let dataIndex = td.textLayout.quadOrigins[qi].subIndex
            let quad = td.textLayout.quads[qi]
            let endX = if qi < line.endIndex - 1: td.textLayout.quads[qi+1].position.x.int else: quad.position.x.int + quad.dimensions.x
            if position.x >= quad.position.x.int and position.x <= endX:
               if abs(position.x - quad.position.x.int) < abs(position.x - (quad.position.x.int + quad.dimensions.x)):
                  return some(dataIndex)
               else:
                  return some(dataIndex+1)
         return some(td.textLayout.quadOrigins[line.endIndex-1].subIndex+1)
   none(int)

proc selectText(widget: Widget, selectionRect: Recti, forwardSelection: bool) =
   let td = widget.data(TextDisplay)
   var minIndex : Option[int]
   var maxIndex : Option[int]
   for line in td.textLayout.lineInfo:
      for qi in line.startIndex ..< line.endIndex:
         let dataIndex = td.textLayout.quadOrigins[qi].subIndex
         let quad = td.textLayout.quads[qi]
         let quadRect = rect(vec2i(quad.position.x.int, line.startY), vec2i(quad.dimensions.x, line.maximumHeight))
         if hasIntersection(quadRect, selectionRect):
            if minIndex.isNone:
               minIndex = some(dataIndex)
            maxIndex = some(dataIndex)

   let newSelectedRange = if minIndex.isSome and maxIndex.isSome:
      some((minIndex.get, maxIndex.get))
   else:
      none((int,int))

   td.selectionRect = selectionRect
   if newSelectedRange != td.selectedRange:
      td.selectedRange = newSelectedRange
      if widget.hasData(TextInput) and newSelectedRange.isSome:
         let ti = widget.data(TextInput)
         if forwardSelection:
            ti.cursorPosition = newSelectedRange.get()[1] + 1
         else:
            ti.cursorPosition = newSelectedRange.get()[0]


   widget.markForUpdate(RecalculationFlag.Contents)



method handleEvent*(ws: TextDisplayRenderer, widget: Widget, event: UIEvent, world: World, display: DisplayWorld) =
   proc insertText(widget : Widget, td : ref TextDisplay, ti: ref TextInput, str : string, rune : Option[Rune]) =
      if td.selectedRange.isSome:
         let (minSel, maxSel) = td.selectedRange.get
         let index = minSel
         let oldStr = ti.textData_i[minSel..maxSel]
         ti.textData_i.delete(minSel, maxSel)
         ti.textData_i.insert(str, index)
         textDataChanged(TextReplace(oldStr, index, str), display, widget)
         ti.cursorPosition = index+str.len
         td.selectedRange = none((int,int))
      else:
         let index = ti.cursorPosition
         ti.textData_i.insert(str, index)
         if rune.isSome:
            textDataChanged(RuneAppend(rune.get, index), display, widget)
         else:
            textDataChanged(StringAppend(str, index), display, widget)
         ti.cursorPosition.inc str.len

   proc moveCursorToWindowPosition(widget: Widget, td: ref TextDisplay, ti: ref TextInput, position : Vec2f, select : bool) =
      let offset = widget.resolvedPosition.xy + widget.clientOffset.xy
      let rawDataIndex = positionToDataIndex(widget, vec2i(position.xy) - offset)
      let dataIndex = rawDataIndex.get(ti.textData_i.len)
      let originalCursor = ti.cursorPosition

      ti.cursorPosition = dataIndex

      if not select:
         td.selectedRange = none((int,int))
      else:
         var (minSel, maxSel) = td.selectedRange.get((originalCursor, originalCursor))
         let cursorAtMin = originalCursor <= minSel
         if dataIndex < originalCursor:
            if cursorAtMin:
               td.selectedRange = some((dataIndex, maxSel))
            else:
               td.selectedRange = some(( min(minSel, dataIndex), max(minSel, dataIndex-1) ))
         elif dataIndex > originalCursor:
            if not cursorAtMin:
               td.selectedRange = some((minSel, dataIndex-1))
            else:
               td.selectedRange = some(( min(maxSel, dataIndex), max(maxSel, dataIndex-1) ))

         if td.selectedRange.isSome and td.selectedRange.get()[0] > td.selectedRange.get()[1]:
            td.selectedRange = none((int,int))
      widget.markForUpdate(RecalculationFlag.Contents)

   if widget == widget.windowingSystem.desktop:
      matcher(event):
         extract(WidgetMouseDrag, position, origin, modifiers):
            for textDisplay in widget.descendantsMatching(w => w.hasData(TextDisplay) and w.data(TextDisplay).allowSelection):
               if (position.xy - origin.xy).lengthSafe < 5:
                  moveCursorToWindowPosition(textDisplay, textDisplay.data(TextDisplay), textDisplay.data(TextInput), position, modifiers.shift)
               else:
                  if modifiers.shift:
                     moveCursorToWindowPosition(textDisplay, textDisplay.data(TextDisplay), textDisplay.data(TextInput), position, modifiers.shift)
                  else:
                     let offset = textDisplay.resolvedPosition.xy + textDisplay.clientOffset.xy
                     selectText(textDisplay, rectContaining(@[vec2i(position) - offset, vec2i(origin) - offset]), position.x > origin.x)


#   if widget.hasData(TextDisplay):
#      let td = widget.data(TextDisplay)
#      if td.allowSelection:
#         matcher(event):
#            extract(WidgetMouseDrag, position, origin):
#               selectText(td, rectContaining(@[vec2i(position), vec2i(origin)]))

   if widget.hasData(TextInput):
      let ti = widget.data(TextInput)
      let td = widget.data(TextDisplay)

      proc performDelete() =
         if td.selectedRange.isSome:
            let (minSel,maxSel) = td.selectedRange.get
            let index = minSel
            let oldStr = ti.textData_i[minSel..maxSel]
            ti.textData_i.delete(minSel, maxSel)
            textDataChanged(TextReplace(oldStr, index, ""), display, widget)
            ti.cursorPosition = index
            td.selectedRange = none((int,int))
         else:
            let tdata = widget.data(TextInput).textData
            let index = ti.cursorPosition - 1
            if index >= 0:
               let rune = ti.textData.runeAt(index)
               ti.textData_i.delete(index, index)
               textDataChanged(RuneDelete(rune, index), display, widget)
               ti.cursorPosition.dec

      matcher(event):
         extract(WidgetMousePress, position, button, modifiers):
            if button == MouseButton.Left:
               if modifiers.shift:
                  moveCursorToWindowPosition(widget, td, ti, position, true)
               else:
                  moveCursorToWindowPosition(widget, td, ti, position, false)

         extract(WidgetRuneEnter, rune):
            insertText(widget, td, ti, rune.toUTF8(), some(rune))
         extract(WidgetKeyPress, key, modifiers):
            case key:
            of KeyCode.Enter:
               display.addEvent(TextDataEnter(textData: widget.data(TextInput).textData, widget: widget))
            of KeyCode.Backspace:
               performDelete()
            of KeyCode.Z:
               if modifiers.ctrl:
                  widget.undo()
            of KeyCode.Left:
               if modifiers.alt:
                  ti.cursorPosition = clamp(ti.cursorPosition - 1, 0, ti.textData.len)
                  while ti.cursorPosition >= 0 and not AltStopChars.contains(ti.textData[ti.cursorPosition]):
                     ti.cursorPosition.dec
               else:
                  if td.selectedRange.isSome:
                     ti.cursorPosition = td.selectedRange.get()[0]
                     td.selectedRange = none((int,int))
                  else:
                     let moveDist = if modifiers.ctrl: 1000000 else : 1
                     ti.cursorPosition = clamp(ti.cursorPosition - moveDist, 0, ti.textData.len)
               widget.markForUpdate(RecalculationFlag.Contents)
            of KeyCode.Right:
               if modifiers.alt:
                  ti.cursorPosition = clamp(ti.cursorPosition + 1, 0, ti.textData.len)
                  while ti.cursorPosition < ti.textData.len and not AltStopChars.contains(ti.textData[ti.cursorPosition]):
                     ti.cursorPosition.inc
               else:
                  if td.selectedRange.isSome:
                     ti.cursorPosition = clamp(td.selectedRange.get()[1]+1, 0, ti.textData.len)
                     td.selectedRange = none((int,int))
                  else:
                     let moveDist = if modifiers.ctrl: 1000000 else : 1
                     ti.cursorPosition = clamp(ti.cursorPosition + moveDist, 0, ti.textData.len)
               widget.markForUpdate(RecalculationFlag.Contents)
            of KeyCode.V:
               if modifiers.ctrl:
                  let str = $(widget.windowingSystem.clipboard.clipboard_text())

                  insertText(widget, td, ti, str, none(Rune))
            of KeyCode.C:
               if modifiers.ctrl:
                  if td.selectedRange.isSome:
                     let (minSel, maxSel) = td.selectedRange.get
                     let str = ti.textData_i[minSel..maxSel]
                     if not widget.windowingSystem.clipboard.clipboard_set_text(cstring(str)):
                        warn &"Setting clipboard returned false, uncertain what that indicates"
            of KeyCode.X:
               if modifiers.ctrl:
                  if td.selectedRange.isSome:
                     let (minSel, maxSel) = td.selectedRange.get
                     let str = ti.textData_i[minSel..maxSel]
                     if not widget.windowingSystem.clipboard.clipboard_set_text(cstring(str)):
                        warn &"Setting clipboard returned false, uncertain what that indicates"
                     performDelete()

            else:
               discard




method readDataFromConfig*(ws: TextDisplayRenderer, cv: ConfigValue, widget: Widget) =
   let typeStr = cv["type"].asStr("").toLowerAscii
   if typeStr == "textdisplay" or typeStr == "textinput":
      let isInput = typeStr == "textinput"
      if not widget.hasData(TextDisplay):
         var td: TextDisplay
         if isInput:
            td.allowSelection = true
         readFromConfig(cv, td)
         widget.attachData(td)
      else:
         readFromConfig(cv, widget.data(TextDisplay)[])

      widget.cursor = some(GLFWIbeamCursor)

   if typeStr == "textinput":
      if not widget.hasData(TextInput):
         var ti: TextInput
         readFromConfig(cv, ti)
         widget.attachData(ti)
      else:
         readFromConfig(cv, widget.data(TextInput)[])
      let ti = widget.data(TextInput)
      ti.cursorPosition = ti.textData.len

      syncDisplayToData(widget)


method updateBindings*(ws: TextDisplayRenderer, widget: Widget, resolver: var BoundValueResolver) =
   if widget.hasData(TextDisplay) and updateBindings(widget.data(TextDisplay)[], resolver):
      widget.markForUpdate(RecalculationFlag.Contents)
      if widget.width.isIntrinsic:
         widget.markForUpdate(RecalculationFlag.DimensionsX)
      if widget.height.isIntrinsic:
         widget.markForUpdate(RecalculationFlag.DimensionsY)
