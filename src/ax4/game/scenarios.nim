import prelude
import worlds
import config
import resources
import game/library
import ax4/game/characters
import ax4/game/game_logic
import ax4/game/effects
import ax4/game/enemies
import ax4/game/items
import ax4/game/cards
import ax4/game/map
import ax4/game/rooms
import ax4/game/ax_events
import ax4/game/turns
import strutils
import game/randomness
import noto
import hex


type
  ScenarioKind* {.pure.} = enum
    Combat

  Scenario* = object
    case kind*: ScenarioKind
      of ScenarioKind.Combat:
        enemies*: seq[Taxon]



proc readFromConfig*(cv: ConfigValue, s: var Scenario) =
  case cv["kind"].asStr.toLowerAscii:
    of "combat":
      s = Scenario(
        kind: ScenarioKind.Combat,
        enemies: readIntoTaxons(cv["enemies"], "MonsterClasses")
      )
    else:
      warn &"Unknown kind for scenario: {cv}"


defineSimpleLibrary[Scenario]("ax4/game/scenarios.sml", "Scenarios")



proc findStartingLocation*(world: World, mapView: MapView): AxialVec =
  for r in 0 ..< 3:
    for hex in hexRing(mapView.map.entryPoint, r):
      let terrInfo = mapView.terrainInfoAt(hex)
      if terrInfo.isSome and terrInfo.get.moveCost == 1 and world.entityAt(hex).isNone:
        return hex
  axialVec(0, 0, 0)

proc findEnemyStartingLocation*(world: World, mapView: MapView): AxialVec =
  for r in 0 ..< 3:
    for hex in hexRing(axialVec(0,0), r):
      let terrInfo = mapView.terrainInfoAt(hex)
      if terrInfo.isSome and terrInfo.get.moveCost == 1 and world.entityAt(hex).isNone:
        return hex
  axialVec(0, 0, 0)

proc enterNextRoom*(world: World) =
  let room = createForestRoom(world)
  var r = randomizer(world)
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

    var possibleScenarios : seq[ref Scenario]
    for scenarioID, scenario in library(Scenario).values:
      possibleScenarios.add(scenario)
      
    let (_, scenario) = pickFrom(r, possibleScenarios)
    case scenario.kind:
      of ScenarioKind.Combat:
        for enemyType in scenario.enemies:
          let enemy = createMonster(world, enemyFaction, enemyType)
          placeCharacterInWorld(world, enemy, findEnemyStartingLocation(world, mapView))
    # let slime = createMonster(world, enemyFaction, taxon("monster classes", "green slime"))
    # slime.modify(Monster.xp += 40)
    # slime.attachData(DebugData(name: "slime"))
    # placeCharacterInWorld(world, slime, axialVec(1, 2, 0))
    #
    # let purpleSlime = createMonster(world, enemyFaction, taxon("monster classes", "purple slime"))
    # purpleSlime.attachData(DebugData(name: "purpleSlime"))
    # placeCharacterInWorld(world, purpleSlime, axialVec(2, 1, 0))




