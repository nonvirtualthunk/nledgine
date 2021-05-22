import ax4/game/character_types
import ax4/game/characters
import ax4/game/items
import ax4/game/cards
import ax4/game/resource_pools
import ax4/game/vision
import worlds/gamedebug
import ax4/game/enemies
import game/flags
import worlds
import core
import tables
import hex
import ax4/game/ax_events
import game/randomness
import game/library
import ax4/game/classes
import ax4/game/map
import noto
import ax4/game/rooms
import options
import ax4/game/turns
import ax4/game/enemies

proc createCharacter*(world: World, characterClass: Taxon, faction: Entity): Entity =
   let cardLibrary = library(CardArchetype)
   let moveCardArch = cardLibrary[taxon("card types", "move")]
   var startingCards = @[moveCardArch.createCard(world), moveCardArch.createCard(world), moveCardArch.createCard(world)]
   var startingEquipment: seq[Entity]

   let classData = library(CharacterClass)[characterClass]
   for startingCard in classData.startingCards:
      startingCards.add(cardLibrary[startingCard].createCard(world))

   for startingItem in classData.startingEquipment:
      startingEquipment.add(createItem(world, startingItem))


   let startingDeck = Deck(cards: {CardLocation.DrawPile: startingCards}.toTable)


   withWorld(world):
      let character = world.createEntity()
      character.attachData(Physical())
      character.attachData(Allegiance(faction: faction))
      character.attachData(DeckOwner(combatDeck: startingDeck))
      character.attachData(ResourcePools(
         resources: {
            taxon("resource pools", "action points"): reduceable(3),
            taxon("resource pools", "stamina points"): reduceable(7)}.toTable))
      character.attachData(Character(health: reduceable(10), sightRange: 7))
      character.attachData(Inventory())
      character.attachData(Flags())
      character.attachData(Vision())
      character.attachData(DebugData(name: "character"))

      for item in startingEquipment:
         equipItem(world, character, item)

      character

proc createMonster*(world: World, faction: Entity, monsterClassTaxon: Taxon): Entity =
   withWorld(world):
      var randomizer = randomizer(world)
      let monster = world.createEntity()
      let monsterClass = library(MonsterClass)[monsterClassTaxon]
      monster.attachData(Physical())
      monster.attachData(Allegiance(faction: faction))
      monster.attachData(Monster(monsterClass: monsterClassTaxon, xp: monsterClass.xp))
      monster.attachData(Character(health: reduceable(monsterClass.health.roll(randomizer))))
      monster.attachData(ResourcePools(resources: {taxon("resource pools", "action points"): reduceable(2), taxon("resource pools", "stamina points"): reduceable(3)}.toTable))
      monster.attachData(Flags())
      monster.attachData(Vision())
      monster.attachData(DebugData())
      monster

proc placeCharacterInWorld*(world: World, entity: Entity, location: AxialVec) =
   world.eventStmts(EntityEnteredWorldEvent(entity: entity)):
      entity.modify(Physical.position := location)
      entity.modify(Physical.map := world[Maps].activeMap)


proc findStartingLocation*(world: World, mapView: MapView): AxialVec =
   for r in 0 ..< 3:
      for hex in hexRing(mapView.map.entryPoint, r):
         let terrInfo = mapView.terrainInfoAt(hex)
         if terrInfo.isSome and terrInfo.get.moveCost == 1 and world.entityAt(hex).isNone:
            return hex
   axialVec(0, 0, 0)

proc enterNextRoom*(world: World) =
   let room = createForestRoom(world)
   world.eventStmts(RoomEnteredEvent(room: room)):
      world.modify(WorldEntity, MapsType.activeMap := room)
      let mapView = world.mapView()
      info &"Room: {room} : {world[Maps].activeMap}"

      for faction in playerFactions(world):
         for entity in entitiesInFaction(world, faction):
            if entity.hasData(Physical):
               world.eventStmts(EntityEnteredWorldEvent(entity: entity)):
                  entity.modify(Physical.map := room)
                  entity.modify(Physical.position := findStartingLocation(world, mapView))

               if entity.hasData(DeckOwner):
                  moveAllCardsBetweenLocations(world, entity, DeckKind.Combat, CardLocation.DiscardPile, CardLocation.DrawPile, false)
                  moveAllCardsBetweenLocations(world, entity, DeckKind.Combat, CardLocation.ExpendPile, CardLocation.DrawPile, false)
                  moveAllCardsBetweenLocations(world, entity, DeckKind.Combat, CardLocation.ExhaustPile, CardLocation.DrawPile, true)

               startCharacterTurn(world, entity)

      var enemyFaction: Entity
      for faction in enemyFactions(world):
         enemyFaction = faction

      let slime = createMonster(world, enemyFaction, taxon("monster classes", "green slime"))
      slime.modify(Monster.xp += 40)
      slime.attachData(DebugData(name: "slime"))
      placeCharacterInWorld(world, slime, axialVec(1, 2, 0))

      let purpleSlime = createMonster(world, enemyFaction, taxon("monster classes", "purple slime"))
      purpleSlime.attachData(DebugData(name: "purpleSlime"))
      placeCharacterInWorld(world, purpleSlime, axialVec(2, 1, 0))




