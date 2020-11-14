import ax4/game/combat
import ax4/game/characters
import worlds
import ax4/game/flags
import ax4/game/ax_events
import ax4/game/resource_pools
import tables
import game/library
import ax4/game/effect_types
import sequtils
import options
import ax4/game/cards

type
   TurnData* = object
      turnNumber*: int
      someOtherNumber: int
      activeFaction*: Entity
      someThirdNumber: int

defineReflection(TurnData)

proc endCharacterTurn*(world: World, entity: Entity) =
   world.eventStmts(CharacterTurnEndEvent(entity: entity)):
      let flags = entity[Flags]
      let blockGain = flagValue(flags, "EndOfTurnBlockGain")
      gainBlock(world, entity, blockGain)
      for k, v in keyedFlagValues(flags, "EndOfTurnDamage"):
         dealDamage(world, entity, DamageExpressionResult(fixed: v, damageType: k))

      if entity.hasData(DeckOwner):
         cards.moveAllCardsBetweenLocations(world, entity, DeckKind.Combat, CardLocation.Hand, CardLocation.DiscardPile, shuffle = false)

      discard

proc startCharacterTurn*(world: World, entity: Entity) =
   world.eventStmts(CharacterTurnStartEvent(entity: entity)):
      let rpLib = library(ResourcePoolInfo)
      let rp = entity[ResourcePools]
      for rsrc, value in rp.resources:
         let rpInfo = rpLib[rsrc]
         recoverResource(world, entity, rsrc, rpInfo.recoveryAmount)

      if entity.hasData(DeckOwner):
         entity.modify(DeckOwner.cardsPlayedThisTurn := @[])
         cards.drawHand(world, entity, cards.activeDeckKind(world, entity))

proc endFactionTurn(world: World, faction: Entity) =
   world.eventStmts(FactionTurnEndEvent(entity: faction, faction: faction)):
      for entity in entitiesInFaction(world, faction):
         if entity.hasData(Character):
            endCharacterTurn(world, entity)


proc startFactionTurn(world: World, faction: Entity) =
   world.eventStmts(FactionTurnStartEvent(entity: faction, faction: faction)):
      for entity in entitiesInFaction(world, faction):
         if entity.hasData(Character):
            startCharacterTurn(world, entity)
      world.modifyWorld(TurnData.activeFaction := faction)

proc endTurn*(world: World) =
   withWorld(world):
      let td = world[TurnData]
      let endingFaction = td.activeFaction
      endFactionTurn(world, endingFaction)

      let allFactions = toSeq(world.entitiesWithData(Faction))
      let factionIndex = allFactions.find(endingFaction)

      let nextIndex = (factionIndex + 1) mod allFactions.len
      # we've looped back around, so advance the turn number
      if nextIndex == 0:
         world.eventStmts(FullTurnEndEvent(turnNumber: td.turnNumber)):
            world.modifyWorld(TurnData.turnNumber += 1)

      var exp = td
      let modifier = TurnDataType.turnNumber += 1
      modifier.apply(exp)

      startFactionTurn(world, allFactions[nextIndex])
