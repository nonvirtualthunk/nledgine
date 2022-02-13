import deques


type
    Event* = ref object of RootRef

    EventBuffer* = ref object
      listenerCursors*: seq[int]
      discardedEvents*: int
      events*: Deque[Event]
      maximumSize*: int

    GameEventState* = enum
      PreEvent
      PostEvent

    GameEvent* = ref object of Event
      state*: GameEventState


method toString*(evt: Event): string {.base.} =
  return repr(evt)

method eventTypeString*(evt: Event): string {.base.} =
  return "Unknown"

method toString*(evt: GameEvent): string =
  return repr(evt)


template eventToStr*(eventName: untyped) =
  method toString*(evt: `eventName`): string =
    result = eventName.astToStr
    result.add("(")
    result.add($(evt[]))
    result.add(")")

  method eventTypeString*(evt: `eventName`): string =
    result = eventName.astToStr

proc createEventBuffer*(maximumSize: int = 1000): EventBuffer =
  EventBuffer(
    discardedEvents: 0,
    maximumSize: maximumSize
  )

proc addEvent*(buffer: EventBuffer, evt: Event) =
  buffer.events.addLast(evt)
  while buffer.events.len > buffer.maximumSize:
    buffer.events.popFirst()
    buffer.discardedEvents.inc