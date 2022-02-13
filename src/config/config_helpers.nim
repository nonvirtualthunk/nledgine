import prelude
import config_core
import strutils
import noto
import worlds/taxonomy
import worlds/identity
import arxregex
import core

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
    v = findTaxon(cv.asStr.replace('-','.'))
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

proc readIntoTaxonTable*[V](cv: ConfigValue, t: var Table[Taxon,V], namespace: string) =
  if cv.isEmpty:
    discard
  elif cv.isObj:
    for k,v in cv.fields:
      t[taxon(namespace, k)] = readInto(v, V)
  else:
    warn &"Cannot read a non-object config value into a taxon table: {cv}"

proc readIntoTaxons*(cv: ConfigValue, namespace: string) : seq[Taxon] =
  result = @[]
  for v in cv.asArr:
    result.add(taxon(namespace, v.asStr))

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


const gtltRegex = "([<>]=?)\\s?([0-9]+)".re
const rangeRegex = "([0-9]+)\\s?(?:..|-)\\s?([0-9]+)".re
proc readFromConfig*(cv: ConfigValue, i: var IntRange) =
  if cv.isNumber:
    i = closedRange(cv.asInt, cv.asInt)
  elif cv.isStr:
    let str = cv.asStr
    if str.nonEmpty:
      matcher(str):
        extractMatches(gtltRegex, op, val):
          let valInt = val.parseInt
          case op:
            of ">": i = openTopRange(valInt+1)
            of ">=": i = openTopRange(valInt)
            of "<": i = openBottomRange(valInt-1)
            of "<=": i = openBottomRange(valInt)
            else: warn &"Impossible case in int range parsing for {op}, {val}"
        extractMatches(rangeRegex, min, max):
          i = closedRange(min.parseInt, max.parseInt)
        warn &"Unknown format for int range string: {str}"
    else:
      warn &"Empty string for int range?"
  elif cv.isArr:
    let arr = cv.asArr
    if arr.len == 2:
      i = closedRange(arr[0].asInt, arr[1].asInt)
    else:
      warn &"Array representation of int range must have 2 values: {cv}"

proc readFromConfig*(cv: ConfigValue, i: var ClosedIntRange) =
  if cv.isNumber:
    i = closedRange(cv.asInt, cv.asInt)
  elif cv.isStr:
    let str = cv.asStr
    if str.nonEmpty:
      matcher(str):
        extractMatches(rangeRegex, min, max):
          i = closedRange(min.parseInt, max.parseInt)
        warn &"Unknown format for int range string: {str}"
    else:
      warn &"Empty string for int range?"
  elif cv.isArr:
    let arr = cv.asArr
    if arr.len == 2:
      i = closedRange(arr[0].asInt, arr[1].asInt)
    else:
      warn &"Array representation of int range must have 2 values: {cv}"

defineSimpleReadFromConfig(Identity)
