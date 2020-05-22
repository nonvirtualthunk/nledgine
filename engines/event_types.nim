import glm
import nimgl/glfw

import key_codes

type
    MouseButton* {.pure.} = enum
        Left,
        Right,
        Middle,
        Other

type
    Event* = ref object of RootRef
    
    KeyModifiers* = object
        shift* : bool
        ctrl* : bool
        alt* : bool
    
    UIEvent* = ref object of Event
        consumed : bool
    
    InputEvent* = ref object of UIEvent
        modifiers* : KeyModifiers
    
    MousePress* = ref object of InputEvent
        position* : Vec2i

    MouseRelease* = ref object of InputEvent
        position* : Vec2i

    MouseMove* = ref object of InputEvent
        position* : Vec2i
        delta* : Vec2i

    MouseDrag* = ref object of InputEvent
        position* : Vec2i
        delta* : Vec2i

    KeyPress* = ref object of InputEvent
        key* : KeyCode

    KeyRelease* = ref object of InputEvent
        key* : KeyCode

    QuitRequest* = ref object of InputEvent


method toString*(evt : Event) : string {.base} =
    return $evt[]

method toString*(evt : KeyPress) : string =
    return $evt[]

method toString*(evt : KeyRelease) : string =
    return $evt[]

method toString*(evt : MousePress) : string =
    return $evt[]

method toString*(evt : MouseRelease) : string =
    return $evt[]