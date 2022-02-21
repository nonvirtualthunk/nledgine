import main
import application
import glm
import game/data
import graphics/ascii_renderer
import engines
import game/game_components
import display/encounter_ui

main(GameSetup(
   windowSize: vec2i(1680, 1200),
   resizeable: false,
   windowTitle: "Hex Crawl",
   liveGameComponents: @[(LiveGameComponent)CaptainComponent()],
   graphicsComponents: @[AsciiCanvasComponent(), AsciiWindowingSystemComponent(), EncounterUI()],
   useLiveWorld: true
))

