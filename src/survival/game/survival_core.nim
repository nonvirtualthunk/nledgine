import config
import noto
import options
import arxregex
import strutils

export noto
export options


type Ticks* = distinct int



const ticksRe = "([0-9]+)\\s*([a-zA-Z]+)?".re

const ticksPerDay = 1000

proc `$`*(ticks: Ticks) : string =
  &"{ticks.int}"

proc readFromConfig*(cv: ConfigValue, ticks: var Ticks) =
  if cv.isStr:
    matcher(cv.asStr.toLowerAscii):
      extractMatches(ticksRe, numberStr, units):
        let number = numberStr.parseInt
        if units.len == 0:
          ticks = Ticks(number)
        else:
          case units:
            of "day", "days":
              ticks = Ticks(number * ticksPerDay)
            of "season", "seasons":
              ticks = Ticks(number * ticksPerDay * 13)
            else:
              warn &"Invalid unit of measure for ticks: {units}"
      warn &"Config string for ticks did not match expected format: {cv.asStr}"
  elif cv.isNumber:
    ticks = Ticks(cv.asFloat.int)
  else:
    warn &"Unexpected config value for ticks: {cv}"