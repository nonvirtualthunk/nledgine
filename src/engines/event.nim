import glm
import options
import patty
import ../worlds
import deques
import event_types
import sequtils
import sharedtables
import key_codes

var keyStateMap : SharedTable[int, bool] 
init(keyStateMap)

for kc in KeyCode:
    keyStateMap[kc.int] = false 

proc isKeyDown*(key : KeyCode) : bool =
    {.warning[ProveInit]: off.}
    result = keyStateMap.mget(key.int)

proc setKeyDown*(key : KeyCode, down : bool) =
    keyStateMap[key.int] = down

proc activeKeyModifiers*() : KeyModifiers =
    KeyModifiers(
        shift : isKeyDown(KeyCode.LeftShift) or isKeyDown(KeyCode.RightShift),
        ctrl : isKeyDown(KeyCode.LeftControl) or isKeyDown(KeyCode.RightControl) or isKeyDown(KeyCode.LeftSuper) or isKeyDown(KeyCode.RightSuper),
        alt : isKeyDown(KeyCode.LeftAlt) or isKeyDown(KeyCode.RightAlt)
    )

variantp EventSource:
    WorldSource(world : World)
    EventBufferSource(buffer : EventBuffer, index : int)

type
    EventBus* = object
        cursor : int
        source : EventSource

proc createEventBus*(buffer : EventBuffer) : EventBus =
    let index = buffer.listenerCursors.len
    buffer.listenerCursors.add(0)
    return EventBus(cursor : 0, source : EventBufferSource(buffer, index))

proc createEventBus*(world : World) : EventBus =
    return EventBus(cursor : 0, source : WorldSource(world))


proc addEvent*(bus : var EventBus, evt : Event) =
    match bus.source:
        WorldSource(world): 
            world.addEvent(evt)
        EventBufferSource(buffer, _):
            buffer.addEvent(evt)

proc pollEvent*(bus : var EventBus) : Option[Event] =
    match bus.source:
        WorldSource(world): 
            if world.view.events.len > bus.cursor:
                result = some(world.view.events[bus.cursor])
                bus.cursor.inc
            else:
                result = none(Event)
        EventBufferSource(buffer, index):
            bus.cursor = max(bus.cursor, buffer.discardedEvents)

            let effCursor = bus.cursor - buffer.discardedEvents
            if buffer.events.len > effCursor:
                result = some(buffer.events[effCursor])
                bus.cursor.inc
                buffer.listenerCursors[index] = bus.cursor
                let minCursor = buffer.listenerCursors[buffer.listenerCursors.minIndex()]
                while minCursor > buffer.discardedEvents:
                    buffer.events.popFirst()
                    buffer.discardedEvents.inc
            else:
                result = none(Event)


iterator newEvents*(bus : var EventBus) : Event =
    while true:
        let nextEvent = bus.pollEvent()
        if nextEvent.isSome:
            yield nextEvent.get()
        else:
            break

when isMainModule:
    import ../reflect

    proc printEvent(evt : Event) =
        ifOfType(evt, MousePress):
            echo "press: ", evt.position
        ifOfType(evt, MouseRelease):
            echo "release: ", evt.position

    var buf = createEventBuffer()

    var list = createEventBus(buf)

    assert list.pollEvent() == none(Event)
    buf.events.addLast(MousePress(position : vec2i(3,4)))

    let secondEvt = list.pollEvent()
    if secondEvt.isSome:
        printEvent(secondEvt.get)

    assert buf.events.len == 0

    buf.events.addLast(MousePress(position : vec2i(4,5)))
    buf.events.addLast(MouseRelease(position : vec2i(1,1)))

    var secondListener = createEventBus(buf)

    while true:
        let evt = list.pollEvent()
        if evt.isSome:
            printEvent(evt.get)
        else:
            break

    assert buf.events.len == 2

    while true:
        let evt = secondListener.pollEvent()
        if evt.isSome:
            printEvent(evt.get)
        else:
            break

    assert buf.events.len == 0
    
    assert not isKeyDown(KeyCode.LeftShift)
    setKeyDown(KeyCode.LeftShift, true)
    assert isKeyDown(KeyCode.LeftShift)