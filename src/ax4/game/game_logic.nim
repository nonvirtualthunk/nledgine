import ax4/game/character_types
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
import randomness
import game/library

proc createCharacter*(world: World, faction: Entity): Entity =
   withWorld(world):
      let character = world.createEntity()
      character.attachData(Physical())
      character.attachData(Allegiance(faction: faction))
      character.attachData(DeckOwner())
      character.attachData(ResourcePools(
         resources: {
            taxon("resource pools", "action points"): reduceable(3),
            taxon("resource pools", "stamina points"): reduceable(7)}.toTable))
      character.attachData(Character(health: reduceable(6)))
      character.attachData(Inventory())
      character.attachData(Flags())
      character.attachData(Vision())
      character.attachData(DebugData(name: "character"))
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
