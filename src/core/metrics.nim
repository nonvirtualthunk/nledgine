import nimgl/glfw
import math
import strformat

type
   Timer* = object
      name*: string
      sdSum: float
      sdSum2: float
      sdN: float
      max*: float
      min*: float

proc recordTime*(t: var Timer, dt: float) =
   t.sdSum += dt
   t.sdSum2 += dt * dt
   t.sdN += 1
   t.max = max(t.max, dt)
   t.min = min(t.min, dt)

proc average*(t: Timer): float = t.sdSum / t.sdN

proc stdDev*(t: Timer): float = sqrt(t.sdSum2/t.sdN - t.sdSum*t.sdSum/t.sdN/t.sdN)

template time*(t: var Timer, stmts: untyped): untyped =

   let startTime = glfwGetTime()

   stmts

   let endTime = glfwGetTime()
   t.recordTime(endTime - startTime)

proc fmtTime(f: float): string =
   if f < 0.1:
      let ms = f * 1000.0
      fmt"{ms:.4f}ms"
   else:
      fmt"{f:.4f}s"

proc `$`*(t: Timer): string =
   t.name & " - \n" &
   "\taverage: " & fmtTime(t.average) & "\n" &
   "\tstddev: " & fmtTime(t.stdDev) & "\n" &
   "\tmax: " & fmtTime(t.max) & "\n" &
   "\tmin: " & fmtTime(t.min) & "\n" &
   "\tsum: " & fmtTime(t.sdSum) & "\n"
