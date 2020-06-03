import glm

import engines/engine

type GameSetup* = object
    windowSize* : Vec2i
    fullscreen* : bool
    resizeable* : bool
    windowTitle* : string
    gameComponents* : seq[GameComponent]
    graphicsComponents*: seq[GraphicsComponent]