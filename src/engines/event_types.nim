import glm
import nimgl/glfw
import deques
import unicode
import worlds/taxonomy
import core_event_types

import key_codes

export core_event_types

type
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
    
  DebugCommandEvent* = ref object of InputEvent
    command*: string

  CameraChangedEvent* = ref object of Event





method isConsumed*(evt: Event): bool {.base.} = false
method isConsumed*(evt: UIEvent): bool = evt.consumed




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
eventToStr(DebugCommandEvent)
eventToStr(CameraChangedEvent)


proc consume*(evt: UIEvent) =
  evt.consumed = true

# matcher(...) but only applies when the value in question is a game event in the post event state
template postMatcher*(value: typed, stmts: untyped) =
  if value of GameEvent and value.GameEvent.state == GameEventState.PostEvent:
    block:
      let matchTarget {.inject.} = value
      stmts