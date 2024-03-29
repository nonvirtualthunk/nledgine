import ax4/game/flags
import worlds
import engines
import ax4/game/ax_events
import tables
import ax4/game/characters
import ax4/game/movement
import hex
import sequtils
import ax4/game/turns
import ax4/game/enemies
import game/library
import noto
import ax4/game/effects
import ax4/game/effect_types
import ax4/game/pathfinder
import ax4/game/targeting
import options
import ax4/game/combat
import game/randomness
import patty
import sugar

type
   AIComponent* = ref object of GameComponent


method initialize*(g: AIComponent, world: World) =
   g.name = "FlagComponent"
   discard

proc think(world: World, actor: Entity) =
   withWorld(world):
      if actor.hasData(Monster):
         var r = randomizer(world)
         let monsterClassInfo = library(MonsterClass)[actor[Monster].monsterClass]
         var validActions: Table[string, MonsterAction]
         var totalWeight = 0.0
         for key, action in monsterClassInfo.actions:
            if isConditionMet(world, actor, action.conditions):
               fine &"Action {key} is valid possibility"
               validActions[key] = action
               totalWeight += action.weight

         var nextAction = none(string)
         var weight = r.nextFloat(totalWeight)
         fine &"Total weight: {totalWeight}, weight: {weight}"
         for key, action in validActions:
            if weight <= action.weight:
               nextAction = some(key)
               break
            else:
               weight -= action.weight

         world.eventStmts(MonsterActionChosenEvent(entity: actor, action: nextAction)):
            actor.modify(Monster.nextAction := nextAction)


         # todo: checking conditions
      else:
         warn &"Non monster encountered in ai decision making process: {actor}"

proc act(world: World, actor: Entity) =
   withWorld(world):
      # let pos = entity[Physical].position
      # let newPossibilities = toSeq(pos.neighbors)
      # let newPos = newPossibilities[world.currentTime.int mod 6]
      # discard moveCharacter(world, entity, newPos)

      if actor.hasData(Monster):
         let monsterClassInfo = library(MonsterClass)[actor[Monster].monsterClass]
         let actionKey = actor[Monster].nextAction
         if not actionKey.isSome:
            return

         let action = monsterClassInfo.actions[actionKey.get]
         # todo: checking conditions

         for monsterEffect in action.effects:
            let effect = monsterEffect.effect

            let possibleTargetsOpt = possibleEntityMatchesFromRestriction(world, actor, actor, monsterEffect.target.filters)
            var possibleTargets: seq[Entity]
            if possibleTargetsOpt.isNone:
               warn &"No possible targets for ai action"
            else:
               possibleTargets = possibleTargetsOpt.get

            case effect.kind:
            of GameEffectKind.Move:
               let possibleMoveTargets = possibleTargets

               if possibleMoveTargets.len > 0:
                  let sortedMoveTargets = sortByPreference(world, actor, possibleMoveTargets, monsterEffect.target)

                  let pf = createPathfinder(world, actor)
                  let target = sortedMoveTargets[0]
                  let targetPos = target[Physical].position
                  let possiblePath = pf.findPath(PathRequest(fromHex: actor[Physical].position, targetHexes: toSeq(targetPos.neighbors), pathPriority: PathPriority.Shortest))
                  if possiblePath.isSome:
                     let truncPath = possiblePath.get.subPath(effect.moveRange)
                     for hex in truncPath.hexes:
                        if not moveCharacter(world, actor, hex):
                           warn &"Could not move ai along expected path"
               else:
                  warn &"No move targets for ai"
            of GameEffectKind.SimpleAttack:
               let attack = effect.attack

               var possibleAttackTargets: seq[Entity]
               for ent in possibleTargets:
                  if isAttackValid(world, actor, attack, @[ent]):
                     possibleAttackTargets.add(ent)

               if possibleAttackTargets.len > 0:
                  let sortedAttackTargets = sortByPreference(world, actor, possibleAttackTargets, monsterEffect.target)

                  let numToAttack = match attack.target:
                     Single: 1
                     Multiple(num): num
                     _:
                        warn &"We only really support non-shape based monster attacks right now"
                        1

                  var targets: seq[Entity]
                  for i in 0 ..< min(numToAttack, sortedAttackTargets.len):
                     targets.add(sortedAttackTargets[i])

                  performAttack(world, actor, attack, targets)
               else:
                  info &"No attack targets yet"
            of GameEffectKind.ChangeFlag:
               let sortedTargets = sortByPreference(world, actor, possibleTargets, monsterEffect.target)
               if sortedTargets.len > 0:
                  let target = sortedTargets[0]
                  modifyFlag(world, target, effect.flag, effect.flagModifier)
            else:
               warn &"Unsupported monster effect"


      else:
         warn &"Non monster encountered in ai decision making process: {actor}"

method onEvent*(g: AIComponent, world: World, event: Event) =
   withWorld(world):
      matchType(event):
         extract(FactionTurnStartEvent, faction, state):
            if state == GameEventState.PostEvent:
               if not faction[Faction].playerControlled:
                  for entity in entitiesInFaction(world, faction):
                     if not entity[Character].dead:
                        act(world, entity)
                  for entity in entitiesInFaction(world, faction):
                     if not entity[Character].dead:
                        think(world, entity)
                  endTurn(world)
