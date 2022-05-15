import main
import application
import glm
import windowingsystem/windowingsystem_component
import windowingsystem/windowingsystem
import worlds
import options
import prelude
import engines
import arxmath
import graphics/color
import resources


type UIInit = ref object of GraphicsComponent

method initialize(g: UIInit, world: LiveWorld, display: DisplayWorld) =
  let ws = display[WindowingSystem]
  ws.desktop.background.draw = bindable(false)
  let w = ws.desktop.createChild("MainUI", "MainUI")
  w.bindValue("enemyName", "GOBLIN")
  w.bindValue("enemyImage", image("bubbles/images/enemies/goblin.png"))
  w.bindValue("enemyHealth", 5)
  w.bindValue("enemyMaxHealth", 10)
  w.bindValue("enemyBlock", 4)
  w.bindValue("enemyBlockShowing", true)
  w.bindValue("enemyIntentIcon", image("bubbles/images/icons/attack.png"))
  w.bindValue("enemyIntentText", "3")
  w.bindValue("enemyIntentColor", rgba(0.75, 0.15, 0.2, 1.0))
  w.bindValue("enemyIntentTime", 5)


  w.bindValue("playerHealth", 8)
  w.bindValue("playerBlock", 2)
  w.bindValue("playerBlockShowing", true)
  w.bindValue("playerMaxHealth", 11)
  w.bindValue("playerName", "PLAYER")
  w.bindValue("playerImage", image("bubbles/images/player.png"))


main(GameSetup(
  windowSize: vec2i(1200, 1200),
  resizeable: false,
  windowTitle: "Bubbles",
  clearColor: rgba(0.35,0.35,0.35,1.0),
  liveGameComponents: @[],
  graphicsComponents: @[
    createWindowingSystemComponent("bubbles/widgets/"),
    UIInit()
  ],
  useLiveWorld: true,
))