import engines
import prelude
import noto
import reflect
import engines/event_types
import strutils
import worlds/identity
import regex

type
  BasicDebugComponent* = ref object of GameComponent
    updateCount: int
    lastPrint: UnitOfTime
    mostRecentEventStr: string
    
  BasicLiveWorldDebugComponent* = ref object of LiveGameComponent
      updateCount: int
      lastPrint: UnitOfTime
      mostRecentEventStr: string
      worldInitSeen: bool
      eventPrintFilters: seq[(Event) -> bool]

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




const entityRegex = "@\\((\\d+)\\)".re

method initialize(g: BasicLiveWorldDebugComponent, world: LiveWorld) =
  g.name = "BasicLiveWorldDebugComponent"

method update(g: BasicLiveWorldDebugComponent, world: LiveWorld) =
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

method onEvent(g: BasicLiveWorldDebugComponent, world: LiveWorld, event: Event) =
  ifOfType(GameEvent, event):
    if not g.worldInitSeen and event of WorldInitializedEvent and event.state == GameEventState.PostEvent:
      info "World init seen: " & toString(event)
      g.worldInitSeen = true
    elif g.worldInitSeen:
      for filter in g.eventPrintFilters:
        if not filter(event):
          return
      var eventStr = toString(event)
      var entityReplacements : seq[string]
      var entities : seq[Entity]
      for m in findAll(eventStr, entityRegex):
        entityReplacements.add(eventStr[m.boundaries])
        entities.add(Entity(id: parseInt(m.group(0, eventStr)[0])))

      for i in 0 ..< entityReplacements.len:
        eventStr = eventStr.replace(entityReplacements[i], debugIdentifier(world, entities[i]))

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

proc ignoringEventType*[C](g: BasicLiveWorldDebugComponent, t: typedesc[C]) : BasicLiveWorldDebugComponent =
  g.eventPrintFilters.add(
    proc (evt : Event) : bool =
      result = not (evt of C)
  )
  g
