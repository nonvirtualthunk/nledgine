import config
import noto
import options
import arxregex
import strutils

export noto
export options


type Ticks* = distinct int

proc `==`*(a, b: Ticks): bool {.borrow.}
proc `<`*(a, b: Ticks): bool {.borrow.}
proc `<=`*(a, b: Ticks): bool {.borrow.}
proc `>`*(a, b: Ticks): bool = a.int > b.int
proc `>=`*(a, b: Ticks): bool = a.int >= b.int
proc `!=`*(a, b: Ticks): bool = a.int != b.int
proc `+`*(a, b: Ticks): Ticks = Ticks(a.int + b.int)
proc `+=`*(a : var Ticks, b: Ticks) = a = Ticks(a.int + b.int)
proc `-`*(a, b: Ticks): Ticks = Ticks(a.int - b.int)
proc `+`*(a : Ticks, b: int): Ticks = Ticks(a.int + b)
proc min(a,b: Ticks): Ticks = Ticks(min(a.int, b.int))


const ticksRe = "([0-9]+\\.?[0-9]?)\\s*([a-zA-Z ]+)?".re

const TicksPerDay* = 12000
const DaysPerSeason* = 13
const SeasonsPerYear* = 4
const TicksPerShortAction* = 20
const TicksPerLongAction* = 100

proc `$`*(ticks: Ticks) : string =
  &"{ticks.int}"

proc readFromConfig*(cv: ConfigValue, ticks: var Ticks) =
  if cv.isStr:
    matcher(cv.asStr.toLowerAscii):
      extractMatches(ticksRe, numberStr, units):
        let number = numberStr.parseFloat
        if units.len == 0:
          ticks = Ticks(number)
        else:
          case units:
            of "day", "days":
              ticks = Ticks(number * TicksPerDay)
            of "season", "seasons":
              ticks = Ticks(number * TicksPerDay * DaysPerSeason)
            of "year", "years":
              ticks = Ticks(number * TicksPerDay * DaysPerSeason * SeasonsPerYear)
            of "long action", "long actions":
              ticks = Ticks(number * TicksPerLongAction)
            of "short action", "short actions":
              ticks = Ticks(number * TicksPerShortAction)
            else:
              warn &"Invalid unit of measure for ticks: {units}"
      warn &"Config string for ticks did not match expected format: {cv.asStr}"
  elif cv.isNumber:
    ticks = Ticks(cv.asFloat.int)
  else:
    warn &"Unexpected config value for ticks: {cv}"




type
  TimeData* = object
    currentTime*: Ticks


defineReflection(TimeData)