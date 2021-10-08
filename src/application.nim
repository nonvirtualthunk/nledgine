import glm

import engines/engine
import graphics/color
import options
import sugar
import worlds


type WorldInitFunc* = proc (w: World) {.gcsafe.}
type LiveWorldInitFunc* = proc (world: LiveWorld) {.gcsafe.}

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
    worldInitFunc*: Option[WorldInitFunc]
    liveWorldInitFunc*: Option[LiveWorldInitFunc]