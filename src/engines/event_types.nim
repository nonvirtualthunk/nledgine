import glm
import nimgl/glfw
import deques
import unicode

import key_codes

type
   Event* = ref object of RootRef

   GameEventState* = enum
      PreEvent
      PostEvent

   GameEvent* = ref object of Event
      state*: GameEventState

   EventBuffer* = ref object
      listenerCursors*: seq[int]
      discardedEvents*: int
      events*: Deque[Event]
      maximumSize*: int

   KeyModifiers* = object
      shift*: bool
      ctrl*: bool
      alt*: bool

   UIEvent* = ref object of Event
      consumed*: bool

   InputEvent* = ref object of UIEvent
      modifiers*: KeyModifiers

   MousePress* = ref object of InputEvent
      button*: MouseButton
      position*: Vec2f
      doublePress*: bool

   MouseRelease* = ref object of InputEvent
      button*: MouseButton
      position*: Vec2f

   MouseMove* = ref object of InputEvent
      position*: Vec2f
      delta*: Vec2f

   MouseDrag* = ref object of InputEvent
      button*: MouseButton
      position*: Vec2f
      delta*: Vec2f
      origin*: Vec2f

   KeyPress* = ref object of InputEvent
      key*: KeyCode
      repeat*: bool

   KeyRelease* = ref object of InputEvent
      key*: KeyCode

   RuneEnter* = ref object of InputEvent
      rune*: Rune

   QuitRequest* = ref object of InputEvent

   WindowFocusGained* = ref object of InputEvent
   WindowFocusLost* = ref object of InputEvent

   WorldInitializedEvent* = ref object of GameEvent
    time*: float


template eventToStr*(eventName: untyped) =
  method toString*(evt: `eventName`): string =
    result = eventName.astToStr
    result.add("(")
    result.add($(evt[]))
    result.add(")")


method isConsumed*(evt: Event): bool {.base.} = false
method isConsumed*(evt: UIEvent): bool = evt.consumed

proc createEventBuffer*(maximumSize: int = 1000): EventBuffer =
   EventBuffer(
      discardedEvents: 0,
      maximumSize: maximumSize
   )

proc addEvent*(buffer: EventBuffer, evt: Event) =
   buffer.events.addLast(evt)
   while buffer.events.len > buffer.maximumSize:
      buffer.events.popFirst()

method toString*(evt: Event): string {.base.} =
   return repr(evt)

method toString*(evt: GameEvent): string =
  return repr(evt)

eventToStr(KeyPress)
eventToStr(KeyRelease)
eventToStr(MousePress)
eventToStr(MouseRelease)
eventToStr(RuneEnter)
eventToStr(MouseDrag)
eventToStr(MouseMove)
eventToStr(WindowFocusGained)
eventToStr(WindowFocusLost)
eventToStr(WorldInitializedEvent)

proc consume*(evt: UIEvent) =
   evt.consumed = true

# matcher(...) but only applies when the value in question is a game event in the post event state
template postMatcher*(value: typed, stmts: untyped) =
  if value of GameEvent and value.GameEvent.state == GameEventState.PostEvent:
    block:
      let matchTarget {.inject.} = value
      stmts