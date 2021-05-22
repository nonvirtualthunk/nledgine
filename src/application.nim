import glm

import engines/engine
import graphics/color

type GameSetup* = object
    windowSize* : Vec2i
    fullscreen* : bool
    resizeable* : bool
    windowTitle* : string
    gameComponents* : seq[GameComponent]
    liveGameComponents* : seq[LiveGameComponent]
    graphicsComponents*: seq[GraphicsComponent]
    clearColor*: RGBA
    useLiveWorld*: bool