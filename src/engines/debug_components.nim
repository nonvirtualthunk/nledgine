import engines
import prelude
import noto
import reflect
import engines/event_types
import strutils

type
   BasicDebugComponent* = ref object of GameComponent
      updateCount: int
      lastPrint: UnitOfTime
      mostRecentEventStr: string

method initialize(g: BasicDebugComponent, world: World) =
   g.name = "BasicDebugComponent"

method update(g: BasicDebugComponent, world: World) =
   g.updateCount.inc
   let curTime = relTime()
   if curTime - g.lastPrint > seconds(2.0f):
      g.lastPrint = curTime
      let updatesPerSecond = (g.updateCount / 2)
      if updatesPerSecond < 59:
         info &"Updates / second (sub 60) : {updatesPerSecond}"
      else:
         fine &"Updates / second : {updatesPerSecond}"
      g.updateCount = 0

method onEvent(g: BasicDebugComponent, world: World, event: Event) =
   ifOfType(GameEvent, event):
      let eventStr = toString(event)
      if event.state == GameEventState.PreEvent:
         info("> " & eventStr)
         indentLogs()
      else:
         unindentLogs()

         let adjustedPrev = g.mostRecentEventStr.replace("PreEvent", "")
         let adjustedNew = eventStr.replace("PostEvent", "")

         if adjustedPrev != adjustedNew:
            info("< " & eventStr)

      g.mostRecentEventStr = eventStr
