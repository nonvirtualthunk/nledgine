import effect_types
import attacks
import options
import worlds
import tables
import targeting
import prelude
import patty
import noto
import flags as base_flags
import ax4/game/flags
import ax4/game/modifiers
import ax4/game/movement
import ax4/game/root_types
import ax4/game/map
import ax4/game/resource_pools

proc effectiveAttack*(view: WorldView, character: Entity, effect: GameEffect): Option[Attack] =
   if effect.kind == GameEffectKind.Attack:
      let attack = resolveAttack(view, character, effect.attackSelector)
      if attack.isSome:
         var attack = attack.get
         attack.applyModifiers(effect.attackModifier)
         some(attack)
      else:
         attack
   elif effect.kind == GameEffectKind.SimpleAttack:
      some(effect.attack)
   else:
      warn &"Attempted to resolve effectiveAttack from non-attack effect: {effect}"
      none(Attack)

proc expandCosts*(view: WorldView, character: Entity, effect: GameEffect): seq[GameEffect] =
   case effect.kind:
   of GameEffectKind.Attack, GameEffectKind.SimpleAttack:
      for attack in effectiveAttack(view, character, effect):
         result = attackCosts(attack)
   else:
      discard


proc selectionsForEffect*(view: WorldView, character: Entity, effect: GameEffect): OrderedTable[SelectorKey, Selector] =
   case effect.kind:
   of GameEffectKind.Attack, GameEffectKind.SimpleAttack:
      for attack in effectiveAttack(view, character, effect):
         result[Object()] = match attack.target:
            Single: enemySelector(1)
            Multiple(count): enemySelector(count)
            Shape(shape): charactersInShapeSelector(shape)
   of GameEffectKind.ChangeFlag, GameEffectKind.ChangeResource:
      result[Object()] = effect.target
   of GameEffectKind.Move:
      result[Subject()] = effect.target
      result[Object()] = pathSelector(effect.moveRange, Subject(), effect.desiredDistance)




proc resolveEffect*(world: World, character: Entity, effectPlay: EffectPlay): bool =
   result = true

   withWorld(world):
      let effect = effectPlay.effect
      case effect.kind:
      of GameEffectKind.Attack:
         let attack = effectiveAttack(world, character, effect)
         if attack.isSome:
            let attack = attack.get

            let targets = effectPlay.selected[Object()]
            # do attack
      of GameEffectKind.ChangeFlag:
         let flag = effect.flag
         let modifier = effect.flagModifier

         let flags = character.data(Flags)
         var curValue = flags.flags.getOrDefault(flag)
         modifier.apply(curValue)
         character.modify(Flags.flags.put(flag, curValue))
      of GameEffectKind.Move:
         let selMover = effectPlay.selected[Subject()].selectedEntities
         let selPath = effectPlay.selected[Object()].selectedEntities

         if selMover.len != 1:
            warn &"Move effect with != 1 subject : {selMover}"
            return false
         let mover = selMover[0]
         for step in selPath:
            if not step.hasData(Tile):
               warn &"Path plotted through non-Tile entity"
               return false
            movement.moveCharacter(world, mover, step)
      of GameEffectKind.ChangeResource:
         let rsrc = effect.resource
         let modifier = effect.resourceModifier
         let targets = effectPlay.selected[Object()].selectedEntities
         for target in targets:
            changeResource(world, target, rsrc, modifier)


proc toEffectPlayGroup*(view: WorldView, character: Entity, source: Entity, effectGroup: EffectGroup): EffectPlayGroup =
   for cost in effectGroup.costs:
      result.plays.add(EffectPlay(isCost: true, effect: cost, selectors: selectionsForEffect(view, character, cost)))
   for effect in effectGroup.effects:
      result.plays.add(EffectPlay(isCost: false, effect: effect, selectors: selectionsForEffect(view, character, effect)))
   result.source = source
