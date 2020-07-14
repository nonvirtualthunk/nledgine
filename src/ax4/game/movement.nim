import worlds

import ax4/game/map
import hex
import options
import game/library
import noto
import ax4/game/characters
import ax4/game/ax_events


proc cost*(view: WorldView, a, b: Entity): float =
   withView(view):
      let tileEnt = b
      let tile = tileEnt[Tile]
      let terlib = library(TerrainInfo)
      let veglib = library(VegetationInfo)

      let terCost = terLib[tile.terrain].moveCost
      var vegCost = 0
      for veg in tile.vegetation:
         vegCost += vegLib[veg].moveCost
      result = (terCost + vegCost).float

proc cost*(view: WorldView, map: ref Map, a, b: AxialVec): float =
   let tileA = map.tileAt(a)
   let tileB = map.tileAt(b)
   if tileA.isSome and tileB.isSome:
      cost(view, tileA.get, tileB.get)
   else:
      warn &"Trying to calculate cost to/from non-present tile: {tileA}, {tileB}"
      100000.0f

proc moveCharacter*(world: World, character: Entity, toHex: Entity): bool {.discardable.} =
   withWorld(world):
      # let map = world.view[Map]
      # let cost = cost(world, map, character[Physical].position, toHex[Tile].position)
      # if cost <=
      let toPosition = toHex[Tile].position
      let fromPosition = character[Physical].position

      if fromPosition != toPosition:
         world.eventStmts(CharacterMoveEvent(entity: character, fromHex: fromPosition, toHex: toPosition)):
            character.modify(Physical.position := toPosition)
      true

