import prelude
import config_core
import strutils
import noto
import worlds/taxonomy

proc readFromConfig*(cv: ConfigValue, v: var HorizontalAlignment) =
   if cv.isStr:
      let str = cv.asStr.toLowerAscii
      if str == "center" or str == "centered":
         v = HorizontalAlignment.Center
      elif str == "right":
         v = HorizontalAlignment.Right
      elif str == "left":
         v = HorizontalAlignment.Left
      else:
         warn &"invalid horizontal alignment in configuration : {cv.asStr}"
   else:
      warn &"invalid config for horizontal alignment : {cv}"


proc readFromConfig*(cv: ConfigValue, v: var VerticalAlignment) =
   if cv.isStr:
      let str = cv.asStr.toLowerAscii
      if str == "center" or str == "centered":
         v = VerticalAlignment.Center
      elif str == "top":
         v = VerticalAlignment.Top
      elif str == "bottom":
         v = VerticalAlignment.Bottom
      else:
         warn &"invalid vertical alignment in configuration : {cv.asStr}"
   else:
      warn &"invalid config for vertical alignment : {cv}"

proc readFromConfig*(cv: ConfigValue, v: var Taxon) =
   if not cv.isEmpty:
      v = findTaxon(cv.asStr)
      if v == UnknownThing:
         writeStackTrace()
         warn "Could not identify taxon, but expected to do so"

defineSimpleReadFromConfig(Identity)
