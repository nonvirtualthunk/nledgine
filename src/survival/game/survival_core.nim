import config
import noto
import options
import arxregex
import strutils
import glm

export noto
export options


type Ticks* = distinct int
type Ticks16* = distinct int16

proc `==`*(a, b: Ticks): bool {.borrow.}
proc `<`*(a, b: Ticks): bool {.borrow.}
proc `<=`*(a, b: Ticks): bool {.borrow.}
proc `>`*(a, b: Ticks): bool = a.int > b.int
proc `>=`*(a, b: Ticks): bool = a.int >= b.int
proc `!=`*(a, b: Ticks): bool = a.int != b.int
proc `+`*(a, b: Ticks): Ticks = Ticks(a.int + b.int)
proc `+=`*(a : var Ticks, b: Ticks) = a = Ticks(a.int + b.int)
proc `+=`*(a : var Ticks, b: int) = a = Ticks(a.int + b.int)
proc `-=`*(a : var Ticks, b: Ticks) = a = Ticks(a.int - b.int)
proc `-=`*(a : var Ticks, b: int) = a = Ticks(a.int - b.int)
proc `-`*(a, b: Ticks): Ticks = Ticks(a.int - b.int)
proc `+`*(a : Ticks, b: int): Ticks = Ticks(a.int + b)
proc min(a,b: Ticks): Ticks = Ticks(min(a.int, b.int))
proc `*`*(a: Ticks, b: int) : Ticks = (a.int * b).Ticks

proc `==`*(a, b: Ticks16): bool {.borrow.}
proc `<`*(a, b: Ticks16): bool {.borrow.}
proc `<=`*(a, b: Ticks16): bool {.borrow.}
proc `>`*(a, b: Ticks16): bool = a.int > b.int
proc `>=`*(a, b: Ticks16): bool = a.int >= b.int
proc `!=`*(a, b: Ticks16): bool = a.int != b.int
proc `+`*(a, b: Ticks16): Ticks16 = Ticks16(a.int + b.int)
proc `+=`*(a : var Ticks16, b: Ticks16) = a = Ticks16(a.int + b.int)
proc `+=`*(a : var Ticks16, b: int) = a = Ticks16(a.int + b.int)
proc `+=`*(a : var Ticks, b: Ticks16) = a = Ticks(a.int + b.int)
proc `-`*(a, b: Ticks16): Ticks16 = Ticks16(a.int - b.int)
proc `+`*(a : Ticks16, b: int): Ticks16 = Ticks16(a.int + b)
proc min(a,b: Ticks16): Ticks16 = Ticks16(min(a.int, b.int))
proc `*`*(a: Ticks16, b: int) : Ticks16 = (a.int * b).Ticks16


converter toTicksFull*(t: Ticks16) : Ticks = Ticks(t.int16.int)

const ticksRe = "([+-]?[0-9]+\\.?[0-9]?)\\s*([a-zA-Z ]+)?".re
const ticksPerRe = "([+-]?[0-9]+\\.?[0-9]?)\\s*per\\s*([a-zA-Z ]+)".re

const TicksPerDay* = 12000
const DaysPerSeason* = 13
const SeasonsPerYear* = 4
const TicksPerShortAction* = 20
const TicksPerMediumAction* = 50
const TicksPerLongAction* = 100
const LongActionTime* = TicksPerLongAction.Ticks
const ShortActionTime* = TicksPerShortAction.Ticks
const DayDuration* = TicksPerDay.Ticks
const DistantPastInTicks* = (-100000).Ticks

proc `$`*(ticks: Ticks) : string =
  &"{ticks.int}"

proc readFromConfig*(cv: ConfigValue, ticks: var Ticks) =
  if cv.isStr:
    matcher(cv.asStr.toLowerAscii):
      extractMatches(ticksPerRe, numberStr, units):
        let number = numberStr.parseFloat
        case units:
          of "day", "days":
            ticks = Ticks(TicksPerDay / number)
          of "season", "seasons":
            ticks = Ticks((TicksPerDay * DaysPerSeason) / number)
          of "year", "years":
            ticks = Ticks((TicksPerDay * DaysPerSeason * SeasonsPerYear) / number)
          of "long action", "long actions":
            ticks = Ticks(TicksPerLongAction / number)
          of "short action", "short actions":
            ticks = Ticks(TicksPerShortAction / number)
          else:
            warn &"Invalid unit of measure for ticks: {units}"
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
            of "ticks":
              ticks = Ticks(number)
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

  Path* = object
    steps*: seq[Vec3i]
    cost*: int
    stepCosts*: seq[int]

defineReflection(TimeData)