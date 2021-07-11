import prelude
import config_core
import strutils
import noto
import worlds/taxonomy
import worlds/identity
import arxregex

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
         warn &"Could not identify taxon, but expected to do so: {cv.asStr}"

proc readFromConfig*(cv: ConfigValue, v: var ComparisonKind) =
   if cv.isStr:
      case cv.asStr.toLowerAscii:
      of ">=", "greatthanorequalto": v = ComparisonKind.GreaterThanOrEqualTo
      of "<=", "lessthanorequalto": v = ComparisonKind.LessThanOrEqualTo
      of ">", "greaterthan": v = ComparisonKind.GreaterThan
      of "<", "lessthan": v = ComparisonKind.LessThan
      of "==", "equalto": v = ComparisonKind.EqualTo
      of "!=", "notequalto": v = ComparisonKind.NotEqualTo
      else:
         warn &"Invalid string value for comparison kind: {cv.asStr}"
   else:
      warn &"Invalid config value for comparison kind: {cv}"

proc readFromConfig*(cv: ConfigValue, v: var BooleanOperator) =
   if cv.isStr:
      case cv.asStr.toLowerAscii:
      of "and", "&&": v = BooleanOperator.AND
      of "or", "||": v = BooleanOperator.OR
      of "xor", "^": v = BooleanOperator.XOR
      of "not", "!": v = BooleanOperator.NOT
      else:
         warn &"Invalid string value for boolean operator kind: {cv.asStr}"
   else:
      warn &"Invalid config value for boolean operator kind: {cv}"

proc writeToConfig*(t: Taxon) : ConfigValue =
  asConf(&"{t.namespace}.{t.name}")


const timeRegex = "([0-9.]+)\\s?([a-z]+)".re
proc readFromConfig*(cv: ConfigValue, v: var UnitOfTime) =
  if cv.isStr:
    matcher(cv.asStr):
      extractMatches(timeRegex, amountStr, unit):
        let amount = amountStr.parseFloat
        case unit.toLowerAscii:
          of "s", "second", "seconds": v = amount.seconds
          else: warn &"Unknown unit of time: {unit}"
      warn &"Unknown format for unit of time: {cv.asStr}"
  else:
    warn &"Unknown config value for unit of time: {cv}"


defineSimpleReadFromConfig(Identity)
