import ax4/game/flags
import worlds
import engines
import ax4/game/ax_events
import tables
import ax4/game/characters
import ax4/game/map
import ax4/game/scenarios
import noto



type
  ScenarioComponent* = ref object of GameComponent


method initialize*(g: ScenarioComponent, world: World) =
  g.name = "ScenarioComponent"
  discard

method update*(g: ScenarioComponent, world: World) =
  discard

method onEvent*(g: ScenarioComponent, world: World, event: Event) =
  withWorld(world):
    postMatcher(event):
      extract(DiedEvent):
        var survivingPlayers: seq[Entity]
        var survivingEnemyCharacters = 0
        for entity in entitiesInActiveMap(world):
          ifHasData(entity, Character, char):
            if not char.dead:
              if isPlayerControlled(world, entity): survivingPlayers.add(entity)
              else: survivingEnemyCharacters += 1

        info &"Surviving enemies: {survivingEnemyCharacters}, players: {survivingPlayers.len}"

        if survivingPlayers.len == 0:
          err &"YOU HAVE LOST, how did you manage that?"
        elif survivingEnemyCharacters == 0:
          info &"YOU HAVE WON! Now fight again"

          for char in survivingPlayers:
            let rewardClass = chooseAndUpdateFromXpDistributon(world, char)
            gainLevel(world, char, rewardClass)

          enterNextRoom(world)


