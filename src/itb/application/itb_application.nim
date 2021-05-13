import options

import main
import application
import glm
import engines
import worlds
import prelude
import graphics
import tables
import noto
import resources
import graphics/texture_block
import graphics/images
import perlin
import windowingsystem/windowingsystem_component
import game/library
import core
import game/library
import worlds/gamedebug
import strutils

import graphics/camera_component
import graphics/up_to_date_animation_component

import itb/game/progress
import itb/game/board
import itb/graphics/board_graphics
import itb/graphics/character_graphics
import itb/graphics/game_ui

type
   PrintComponent = ref object of GameComponent
      updateCount: int
      lastPrint: UnitOfTime
      mostRecentEventStr: string

   ITBApplication = object


method onEvent(g: PrintComponent, world: World, event: Event) =
   ifOfType(GameEvent, event):
      let eventStr = toString(event)
      if event.state == GameEventState.PreEvent:
         info("> " & eventStr)
         indentLogs()
      else:
         unindentLogs()

         let adjustedPrev = g.mostRecentEventStr.replace("PreEvent", "")
         let adjustedNew = eventStr.replace("PostEvent", "")

         if adjustedPrev != adjustedNew:
            info("< " & eventStr)

      g.mostRecentEventStr = eventStr

main(GameSetup(
  windowSize: vec2i(1680, 1200),
  resizeable: false,
  windowTitle: "With Doom We Come",
  gameComponents: @[
    (GameComponent)(PrintComponent()),
    ProgressComponent(),
  ],
  graphicsComponents: @[
    UpToDateAnimationComponent(),
    createCameraComponent(createPixelCamera(6, vec2f(-35.0f, -70.0f)).withMoveSpeed(300.0f)),
    BoardGraphicsComponent(),
    CharacterGraphicsComponent(),
    GameUIComponent(),
  ],
  clearColor: rgba(0.4f,0.4f,0.4f,1.0f),
))

