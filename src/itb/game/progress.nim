import reflect
import worlds
import engines
import options
import board
import prelude
import game/grids
import times
import random
import glm
import core

import itb/game/characters


type
  Progress* = object
    activeBoard*: Option[Entity]
    completedLevels*: seq[int]
    turnCounter*: int
    playerTurn*: bool


  ProgressComponent* = ref object of GameComponent

  StartGameEvent* = ref object of GameEvent
  BoardEnteredEvent* = ref object of GameEvent

  StartTurnEvent* = ref object of GameEvent
  StartEntityTurnEvent* = ref object of StartGameEvent
    entity*: Entity
  EndTurnEvent* = ref object of GameEvent


defineReflection(Progress)


method toString*(evt: StartGameEvent): string =
   return &"StartGameEvent{$evt[]}"
method toString*(evt: StartTurnEvent): string =
   return &"StartTurnEvent{$evt[]}"
method toString*(evt: EndTurnEvent): string =
   return &"EndTurnEvent{$evt[]}"
method toString*(evt: BoardEnteredEvent): string =
   return &"BoardEnteredEvent{$evt[]}"


proc createBoard(world: World): Entity =
  withWorld(world):
    let boardEnt = world.createEntity()
    var board = Board()

    for i in 0 ..< BoardSize:
      for j in 0 ..< Boardsize:
        board.tiles[i,j] = Tile(
          position: vec2i(i,j),
          terrain: Grass,
          height: 1
        )


    var r = initRand(programStartTime.toTime.toUnix)
    var q = 0
    var pos = vec2i(0,BoardSize div 2)
    while true:
      if pos.x < 0 or pos.x >= BoardSize or pos.y < 0 or pos.y >= BoardSize:
        break

      board.tiles[pos.x, pos.y].terrain = Water
      pos += BoardCardinals[q]
      let rv = r.rand(10)
      if rv >= 7 and rv <= 7:
        q = (q + 3) mod 4
      elif rv >= 9 and rv <= 10:
        q = (q + 1) mod 4
      else:
        if q == 1: q = 0
        elif q == 3: q = 0


    for i in 0 ..< BoardSize:
      let rv = r.rand(2) + 1
      for j in 0 ..< rv:
        board.tiles[i, j].terrain = Stone

    boardEnt.attachData(board)


    let tobold = world.createEntity()
    tobold.attachData(
      Character(
        name: "tobold",
        health: reduceable(3),
        className: "swordsman",
        position: vec2i(3,3),
        moves: reduceable(4),
        playerCharacter: true,
        actions: @[ClubAside]
      )
    )


    let monster = world.createEntity()
    monster.attachData(
      Character(
        name: "jack skellington",
        health: reduceable(3),
        className: "skeleton",
        position: vec2i(5,3),
        moves: reduceable(3),
        playerCharacter: false
      )
    )

    boardEnt


method initialize*(g: ProgressComponent, world: World) =
   g.name = "ProgressComponent"
   world.attachData(Progress(playerTurn: true))
   world.addFullEvent(StartGameEvent())



method onEvent(g: ProgressComponent, world: World, event: Event) =
  withWorld(world):
    matcher(event):
      extract(StartGameEvent, state):
        if state == GameEventState.PreEvent:
          world.modifyWorld(Progress.activeBoard := some(createBoard(world)))
          world.modifyWorld(Progress.turnCounter := 0)
          world.addFullEvent(BoardEnteredEvent())

