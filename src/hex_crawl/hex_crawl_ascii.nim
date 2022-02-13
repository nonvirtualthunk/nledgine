import main
import application
import glm
import game/data
import graphics/ascii_renderer
import engines

main(GameSetup(
   windowSize: vec2i(1680, 1200),
   resizeable: false,
   windowTitle: "Hex Crawl",
   liveGameComponents: @[],
   graphicsComponents: @[AsciiCanvasComponent(), AsciiWindowingSystem()],
   useLiveWorld: true
))

