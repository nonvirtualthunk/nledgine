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
import ax4/game/cards
import game/library
import ax4/game/characters

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


proc selectionsForEffect*(view: WorldView, character: Entity, effects: SelectableEffects): OrderedTable[SelectorKey, Selector] =
   var res: OrderedTable[SelectorKey, Selector]
   proc setSelector(key: SelectorKey, sel: Selector) =
      if res.hasKey(key):
         if res[key] != sel:
            warn &"differing values provided for selectors within selectableEffects, was {res[key]}, would be {sel}"
      else:
         res[key] = sel

   for effect in effects.effects:
      case effect.kind:
      of GameEffectKind.Attack, GameEffectKind.SimpleAttack:
         for attack in effectiveAttack(view, character, effect):
            var sel = match attack.target:
               Single: enemySelector(1)
               Multiple(count): enemySelector(count)
               Shape(shape): charactersInShapeSelector(shape)
            # if we've suppled a target selector here, add its restrictions together with the main attack ones
            if effects.targetSelector.isSome:
               sel.restrictions.add(effects.targetSelector.get.restrictions)
            setSelector(Object(), sel)
      of GameEffectKind.ChangeFlag, GameEffectKind.ChangeResource:
         setSelector(Subject(), effects.targetSelector.get(selfSelector()))
      of GameEffectKind.Move:
         setSelector(Subject(), effects.subjectSelector.get(selfSelector()))
         setSelector(Object(), pathSelector(effect.moveRange, Subject(), effect.desiredDistance))
      of GameEffectKind.AddCard:
         setSelector(Subject(), effects.subjectSelector.get(selfSelector()))
         setSelector(Object(), cardTypeSelector(1, effect.cardChoices))

   res



proc resolveEffect*(world: World, character: Entity, effectPlay: EffectPlay): bool =
   result = true

   withWorld(world):
      for effect in effectPlay.effects:
         case effect.kind:
         of GameEffectKind.Attack:
            warn "Attack not implemented"
            let attack = effectiveAttack(world, character, effect)
            if attack.isSome:
               let attack = attack.get

               let targets = effectPlay.selected[Object()]
               # do attack
         of GameEffectKind.SimpleAttack:
            warn "Simple attack not implemented"
            discard
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
            let targets = effectPlay.selected[Subject()].selectedEntities
            for target in targets:
               changeResource(world, target, rsrc, modifier)
         of GameEffectKind.AddCard:
            let selAdder = effectPlay.selected[Subject()].selectedEntities
            let selCardTypes = effectPlay.selected[Object()].selectedTaxons
            let cardLib = library(CardArchetype)
            for adder in selAdder:
               for cardType in selCardTypes:
                  let card = cardLib[cardType].createCard(world)
                  addCard(world, adder, card, effect.toDeck, effect.toLocation)


proc toEffectPlayGroup*(view: WorldView, character: Entity, source: Entity, effectGroup: EffectGroup): EffectPlayGroup =
   for effects in effectGroup.effects:
      result.plays.add(
         EffectPlay(
            isCost: effects.isCost,
            effects: effects,
            selectors: selectionsForEffect(view, character, effects)
         )
      )

   result.source = source






proc isEffectPlayable*(view: WorldView, character: Entity, effectPlay: EffectPlay): bool =
   withView(view):
      var possibleSelections: Table[SelectorKey, seq[SelectionResult]]
      for key, selector in effectPlay.selectors:
         possibleSelections[key] = possibleSelections(view, character, selector)

      for effect in effectPlay.effects:
         let subEffectPlayable = case effect.kind:
         of GameEffectKind.Attack:
            for sel in possibleSelections[Object()]:
               if sel.selectedEntities.nonEmpty:
                  return true
            false
         of GameEffectKind.SimpleAttack:
            for sel in possibleSelections[Object()]:
               if sel.selectedEntities.nonEmpty:
                  return true
            false
         of GameEffectKind.ChangeFlag:
            true
         of GameEffectKind.Move:
            true
         of GameEffectKind.ChangeResource:
            let rsrc = effect.resource
            let modifier = effect.resourceModifier
            case modifier.operation:
            of ModifierOperation.Sub, ModifierOperation.Reduce:
               let cur = character[ResourcePools].currentResourceValue(rsrc)
               cur >= modifier.value
            else:
               true
         of GameEffectKind.AddCard:
            true


         if not subEffectPlayable:
            return false
      true


