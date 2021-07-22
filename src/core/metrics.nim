import nimgl/glfw
import math
import strformat
import random
import algorithm
import times


const ReservoirSize = 501

type
  Timer* = ref object
    name*: string
    sdSum: float
    sdSum2: float
    sdN: float
    max*: float
    min*: float
    reservoir*: array[ReservoirSize, float32]
    reservoirCount*: int
    rand*: Rand
    count*: int
    noOpCount*: int
    maxMetadata*: string

  TimerDuration* = object
    startTime: float
    timer: Timer

proc timer*(nomen: string) : Timer =
  Timer(name: nomen)

proc recordTime*(t: Timer, dt: float, metadata: string = "") =
  if t != nil:
    if t.reservoirCount == 0:
      t.rand = initRand(now().toTime.toUnix)
      t.min = dt
      t.max = dt
    t.sdSum += dt
    t.sdSum2 += dt * dt
    t.sdN += 1
    if dt > t.max:
      t.max = dt
      t.maxMetadata = metadata
    t.min = min(t.min, dt)
    t.count.inc
    if t.reservoirCount < ReservoirSize:
      t.reservoir[t.reservoirCount] = dt
      t.reservoirCount.inc
    else:
      let i = t.rand.rand(ReservoirSize - 1)
      t.reservoir[i] = dt

proc recordNoOp*(t: Timer) =
  if t != nil:
    t.count.inc
    t.noOpCount.inc

proc start*(t: Timer) : TimerDuration =
  TimerDuration(
    timer: t,
    startTime: glfwGetTime()
  )

proc finish*(t: TimerDuration) =
  t.timer.recordTime(glfwGetTime() - t.startTime)

proc average*(t: Timer): float = t.sdSum / t.sdN

proc stdDev*(t: Timer): float = sqrt(t.sdSum2/t.sdN - t.sdSum*t.sdSum/t.sdN/t.sdN)

proc median*(t: Timer): float =
  # Todo: don't use such an inefficient method
  if t.reservoirCount == 0:
   NaN
  elif t.reservoirCount < ReservoirSize:
   var sortedReservoir : seq[float32]
   for i in 0 ..< t.reservoirCount:
    sortedReservoir.add(t.reservoir[i])
   sort(sortedReservoir)
   sortedReservoir[t.reservoirCount div 2]
  else:
   sort(t.reservoir)
   t.reservoir[ReservoirSize div 2]

template time*(t: Timer, stmts: untyped): untyped =

  let startTime = glfwGetTime()

  stmts

  let endTime = glfwGetTime()
  t.recordTime(endTime - startTime)

# Timing convenience function that times the given statement, but only records values that are
# larger than the given number of milliseconds. Used to avoid counting no-ops in timing. Usually
# relevant for, say, a turn based engine, or roguelike style update
template time*(t: Timer, minimumMsToRecord: float, metadata: string, stmts: untyped): untyped =

  let startTime = glfwGetTime()

  stmts

  let endTime = glfwGetTime()
  let dt = endTime - startTime
  if dt * 1000.0 > minimumMsToRecord:
    t.recordTime(endTime - startTime, metadata)
  else:
    t.recordNoOp()

template time*(t: Timer, minimumMsToRecord: float, stmts: untyped): untyped =
  time(t, minimumMsToRecord, "", stmts)

proc fmtTime*(f: float): string =
  if f < 0.1:
    let ms = f * 1000.0
    fmt"{ms:.4f}ms"
  else:
    fmt"{f:.4f}s"

proc `$`*(t: Timer): string =
  let noOpStr = if t.noOpCount > 0:
      let noOpPcnt = (t.noOpCount.float / t.count.float) * 100.0
      "\tnoOp: " & fmt"{noOpPcnt:.2f}%" & "\n"
    else:
      ""

  let maxMetadataStr = if t.maxMetadata.len > 0:
    "\t\tmax metadata: " & t.maxMetadata & "\n"
  else:
    ""

  t.name & " - \n" &
  "\taverage: " & fmtTime(t.average) & "\n" &
  "\tmedian: " & fmtTime(t.median) & "\n" &
  "\tstddev: " & fmtTime(t.stdDev) & "\n" &
  "\tmax: " & fmtTime(t.max) & "\n" &
  maxMetadataStr &
  "\tmin: " & fmtTime(t.min) & "\n" &
  "\tsum: " & fmtTime(t.sdSum) & "\n" &
  noOpStr
