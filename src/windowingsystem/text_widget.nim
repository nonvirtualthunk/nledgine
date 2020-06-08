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

export rich_text

type
   TextDisplay* = object
      widget* : Widget
      text* : Bindable[RichText]
      fontSize* : int
      font* : ArxFontRoot
      color* : Bindable[RGBA]
      tintColor* : Option[Bindable[RGBA]]

   TextDisplayRenderer* = ref object of WindowingComponent

defineReflection(TextDisplay)
defineBasicReadFromConfig(TextDisplay)

proc computeLayout*(widget : Widget) : TextLayout =
   let TD = widget.data(TextDisplay)
   var bounds = rect(vec2i(0,0), vec2i(10000000,1000000))
   if not widget.width.isIntrinsic:
      bounds.dimensions.x = widget.resolvedDimensions.x - widget.clientOffset.x * 2
   
   let tintColor = if TD.tintColor.isSome:
      some(TD.tintColor.get.value)
   else:
      none(RGBA)
   result = layout(TD.text.value, TD.color.value, tintColor, TD.font, TD.fontSize, bounds)
   # echo "computed layout: ", result

method render*(ws : TextDisplayRenderer, widget : Widget) : seq[WQuad] =
   if widget.hasData(TextDisplay):
      computeLayout(widget).quads
   else:
      @[]

method intrinsicSize*(ws : TextDisplayRenderer, widget : Widget, axis : Axis) : Option[int] =
   if widget.hasData(TextDisplay):
      let textLayout = computeLayout(widget)
      some(textLayout.bounds.dimensions[axis])
   else:
      none(int)

method readDataFromConfig*(ws : TextDisplayRenderer, cv : ConfigValue, widget : Widget) =
   if cv["type"].asStr("").toLowerAscii == "textdisplay":
      echo "text display detected"
      if not widget.hasData(TextDisplay):
         var td : TextDisplay
         readFromConfig(cv, td)
         widget.attachData(td)
      else:
         readFromConfig(cv, widget.data(TextDisplay)[])

method updateBindings*(ws : TextDisplayRenderer, widget : Widget, resolver : var BoundValueResolver) =
   if widget.hasData(TextDisplay) and updateBindings(widget.data(TextDisplay)[], resolver):
      widget.markForUpdate(RecalculationFlag.Contents)
      widget.markForUpdate(RecalculationFlag.DimensionsX)
      widget.markForUpdate(RecalculationFlag.DimensionsY)

template getterSetter(t : untyped)  : untyped {.dirty.} =
   proc `t =`*(td : ref TextDisplay, text : typeof(TextDisplay.`t`)) =
      if not td.widget.isNil and td.`t` != text:
         td.widget.markForUpdate(RecalculationFlag.Contents)
         if td.widget.width.isIntrinsic or td.widget.height.isIntrinsic:
            td.widget.markForUpdate(RecalculationFlag.DimensionsX)
            td.widget.markForUpdate(RecalculationFlag.DimensionsY)
      td.`t` = text

   proc `t`*(td : ref TextDisplay) : typeof(TextDisplay.`t`) = td.`t`

getterSetter(fontSize)
getterSetter(text)
getterSetter(font)
