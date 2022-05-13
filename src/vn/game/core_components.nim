import engines
import worlds
import arxmath
import entities
import game/library
import prelude
import events
import core/metrics
import noto
import glm
import nimgl/glfw

type
  TimeComponent* = ref object of LiveGameComponent
    mark*: float64


proc timeComponent*() : TimeComponent =
  result = new TimeComponent

method initialize(g: TimeComponent, world: LiveWorld) =
  g.name = "TimeComponent"

method update(g: TimeComponent, world: LiveWorld) =
  let curTime = glfWGetTime()
  if g.mark == 0.0:
    g.mark = curTime + 0.0166666666667

  let timeData = world[TimeData]
  while curTime > g.mark:
    timeData.ticks.inc
    world.addEvent(GameTickEvent(tick: timeData.ticks))
    g.mark += 0.0166666667


method onEvent(g: TimeComponent, world: LiveWorld, event: Event) =
  discard