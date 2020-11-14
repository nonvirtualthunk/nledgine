import worlds
import tables
import core
import hex
import ax4/game/effect_types
import game/library
import config
import resources
import ax4/game/ax_events
import ax4/game/resource_pools
import ax4/game/flags
import algorithm
import noto
import math
import patty
import ax4/game/randomness
import ax4/game/classes
import prelude
import ax4/game/enemies
import ax4/game/character_types
export character_types


proc faction*(view: WorldView, entity: Entity): Entity =
   view.data(entity, Allegiance).faction

proc factionData*(view: WorldView, entity: Entity): ref Faction =
   view.data(view.data(entity, Allegiance).faction, Faction)

proc isPlayerControlled*(view: WorldView, entity: Entity): bool =
   view.data(faction(view, entity), Faction).playerControlled

proc areEnemies*(view: WorldView, a, b: Entity): bool =
   faction(view, a) != faction(view, b)

proc areFriends*(view: WorldView, a, b: Entity): bool =
   not areEnemies(view, a, b)

iterator entitiesInFaction*(view: WorldView, faction: Entity): Entity =
   for ent in view.entitiesWithData(Allegiance):
      if view.data(ent, Allegiance).faction == faction:
         yield ent

iterator entitiesNotInFaction*(view: WorldView, faction: Entity): Entity =
   for ent in view.entitiesWithData(Allegiance):
      if view.data(ent, Allegiance).faction != faction:
         yield ent

iterator playerFactions*(view: WorldView): Entity =
   withView(view):
      for ent in view.entitiesWithData(Faction):
         if ent[Faction].playerControlled:
            yield ent

proc levelForXp*(xp: int): int =
   xp div 20

proc xpForLevel*(level: int): int =
   level * 20

proc gainLevel*(world: World, character: Entity, class: Taxon) =
   withWorld(world):
      let currentLevel = character[Character].levels.getOrDefault(class)
      world.eventStmts(ClassLevelUpEvent(entity: character, class: class, level: currentLevel+1)):
         var r = randomizer(world)
         character.modify(Character.levels.addToKey(class, 1))

         let classInfo = library(CharacterClass)[class]
         var possibleCardRewards = classInfo.cardRewards
         var chosenCardRewards: seq[CharacterReward]
         for i in 0 ..< 3:
            if possibleCardRewards.isEmpty:
               break
            let (index, cardReward) = r.pickFrom(possibleCardRewards)
            possibleCardRewards.del(index)
            chosenCardRewards.add(CardReward(cardReward.card))
         let choices = CharacterRewardChoice(options: chosenCardRewards)

         world.eventStmts(RewardGainEvent(entity: character, choices: choices)):
            character.modify(Character.pendingRewards.append(choices))




proc gainXp*(world: World, character: Entity, amount: int) =
   withWorld(world):
      var amountRemaining = amount
      var dist: seq[(Taxon, int)]
      var totalWeight = 0
      for class, weight in character[Character].xpDistribution:
         dist.add((class, weight))
         totalWeight += weight
      dist = dist.sortedByIt(it[1])
      if totalWeight == 0:
         info &"No weight when gaining xp for entity {character}, splitting evenly"
         for class in character[Character].xp.keys:
            dist.add((class, 1))
            totalWeight += 1


      world.eventStmts(XpGainEvent(entity: character, amount: amount)):
         for distTup in dist:
            let (class, weight) = distTup
            let fract = weight.float / totalWeight.float
            let amountForClass = (amount.float * fract).ceil.int.min(amountRemaining)
            amountRemaining -= amountForClass
            let startingXp = character[Character].xp.getOrDefault(class)
            let endingXp = startingXp + amountForClass
            let currentLevel = character[Character].levels.getOrDefault(class)
            if xpForLevel(currentLevel+1) <= endingXp:
               gainLevel(world, character, class)
            character.modify(Character.xp.addToKey(class, amountForClass))

         character.modify(Character.xpDistribution := initTable[Taxon, int]())


proc changeXpDistribution*(world: World, character: Entity, class: Taxon, amount: int) =
   withWorld(world):
      world.eventStmts(XpDistributionChangeEvent(entity: character, class: class, amount: amount)):
         character.modify(Character.xpDistribution.addToKey(class, amount))

proc killCharacter*(world: World, character: Entity) =
   world.eventStmts(DiedEvent(entity: character)):
      character.modify(Character.dead := true)
      character.modify(Physical.position := axialVec(1000, 1000))
   withWorld(world):
      if character.hasData(Monster):
         for enemy in entitiesNotInFaction(world, character[Allegiance].faction):
            gainXp(world, enemy, character[Monster].xp)
