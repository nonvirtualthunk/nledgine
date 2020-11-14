import effect_types
import combat
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
import ax4/game/ax_events



# Resolves the effective attack for the given game effect, accounting for all modifiers
# (derived or otherwise) that are not dependent on the target of the attack being known.
proc effectiveAttack*(view: WorldView, character: Entity, effect: GameEffect): Option[Attack] =
   if effect.kind == GameEffectKind.Attack:
      let attack = resolveAttack(view, character, effect.attackSelector)
      if attack.isSome:
         var attack = attack.get
         attack.applyModifiers(effect.attackModifier)
         let extraModifiers = attackModifierFromFlags(view, character)
         attack.applyModifiers(extraModifiers)

         applyUntargetedDerivedAttackModifiers(view, character, attack)

         some(attack)
      else:
         attack
   elif effect.kind == GameEffectKind.SimpleAttack:
      var attack = effect.attack
      applyUntargetedDerivedAttackModifiers(view, character, attack)

      some(attack)
   else:
      warn &"Attempted to resolve effectiveAttack from non-attack effect: {effect}"
      none(Attack)

proc expandCosts*(view: WorldView, character: Entity, effect: GameEffect): seq[SelectableEffects] =
   case effect.kind:
   of GameEffectKind.Attack, GameEffectKind.SimpleAttack:
      # Derived attacks that do not have a weapon can't expand costs in a meaningful way
      if effect.kind == GameEffectKind.Attack and character.isSentinel:
         return @[]

      for attack in effectiveAttack(view, character, effect):
         let attackCosts = attackCosts(attack)
         for cost in attackCosts:
            result.add(SelectableEffects(effects: @[cost], isCost: true))
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
               Single: enemySelector(1, InRange(attack.minRange, attack.maxRange))
               Multiple(count): enemySelector(count, InRange(attack.minRange, attack.maxRange))
               Shape(shape): charactersInShapeSelector(shape)
            # if we've suppled a target selector here, add its restrictions together with the main attack ones
            if effects.targetSelector.isSome:
               sel.restrictions.add(effects.targetSelector.get.restrictions)
            setSelector(Object(), sel)
      of GameEffectKind.ChangeFlag, GameEffectKind.ChangeResource:
         setSelector(Object(), effects.targetSelector.get(selfSelector()))
      of GameEffectKind.Move:
         setSelector(Subject(), effects.subjectSelector.get(selfSelector()))
         setSelector(Object(), pathSelector(effect.moveRange, Subject(), effect.desiredDistance))
      of GameEffectKind.AddCard:
         setSelector(Subject(), effects.subjectSelector.get(selfSelector()))
         setSelector(Object(), cardTypeSelector(1, effect.cardChoices))
      of GameEffectKind.MoveCard:
         setSelector(Subject(), effects.subjectSelector.get(selfCardSelector()))
      of GameEffectKind.DrawCards:
         setSelector(Subject(), effects.targetSelector.get(selfSelector()))

   res



proc resolveEffect*(world: World, character: Entity, effectPlay: EffectPlay): bool =
   result = true

   withWorld(world):
      for effect in effectPlay.effects:
         case effect.kind:
         of GameEffectKind.Attack:
            let attack = effectiveAttack(world, character, effect)
            if attack.isSome:
               let attack = attack.get

               let targets = effectPlay.selected[Object()].selectedEntities
               combat.performAttack(world, character, attack, targets)
         of GameEffectKind.SimpleAttack:
            warn "Simple attack not implemented"
            discard
         of GameEffectKind.ChangeFlag:
            let flag = effect.flag
            let modifier = effect.flagModifier
            let targets = effectPlay.selected[Object()].selectedEntities

            for target in targets:
               flags.modifyFlag(world, target, flag, modifier)
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
         of GameEffectKind.AddCard:
            let selAdder = effectPlay.selected[Subject()].selectedEntities
            let selCardTypes = effectPlay.selected[Object()].selectedTaxons
            let cardLib = library(CardArchetype)
            for adder in selAdder:
               for cardType in selCardTypes:
                  let card = cardLib[cardType].createCard(world)
                  addCard(world, adder, card, effect.toDeck, effect.toLocation)
         of GameEffectKind.MoveCard:
            let sel = effectPlay.selected[Subject()].selectedEntities
            for card in sel:
               if card[Card].inDeck.isSome:
                  let deckOwner = card[Card].inDeck.get
                  let locs = deckLocation(world, deckOwner, card)
                  if locs.isSome:
                     let (deck, loc) = locs.get
                     moveCard(world, card, effect.moveToDeck.get(deck), effect.moveToLocation.get(loc))
                  else: warn &"MoveCard effect on card that is not in a location in deck :wat:"
               else: warn &"MoveCard effect on card that is not in a deck :shrug:"
         of GameEffectKind.DrawCards:
            let sel = effectPlay.selected[Subject()].selectedEntities
            for ent in sel:
               if ent.hasData(DeckOwner):
                  for i in 0 ..< effect.cardCount:
                     drawCard(world, ent, ent[DeckOwner].activeDeckKind)



proc toEffectPlayGroup*(view: WorldView, character: Entity, source: Entity, effectGroup: EffectGroup): EffectPlayGroup =
   for effects in effectGroup.effects:
      for effect in effects:
         if effect.kind == GameEffectKind.Attack or effect.kind == GameEffectKind.SimpleAttack:
            let attackOpt = effectiveAttack(view, character, effect)
            if attackOpt.isSome:
               for cost in attackCosts(attackOpt.get):
                  let costEffects = SelectableEffects(effects: @[cost], isCost: true)
                  result.plays.add(
                     EffectPlay(
                        isCost: true,
                        effects: costEffects,
                        selectors: selectionsForEffect(view, character, costEffects)
                     )
                  )
            else:
               warn &"converting to effect play group could not resolve attack: {effect}"
      result.plays.add(
         EffectPlay(
            isCost: effects.isCost,
            effects: effects,
            selectors: selectionsForEffect(view, character, effects)
         )
      )

   result.source = source






proc isEffectPlayable*(view: WorldView, character: Entity, source: Entity, effectPlay: EffectPlay): bool =
   withView(view):
      var possibleSelections: Table[SelectorKey, seq[SelectionResult]]
      for key, selector in effectPlay.selectors:
         possibleSelections[key] = targeting.possibleSelections(view, character, source, selector)

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
         of GameEffectKind.MoveCard:
            true
         of GameEffectKind.DrawCards:
            true


         if not subEffectPlayable:
            return false
      true



proc resolveSimpleEffect*(world: World, character: Entity, effect: GameEffect): bool =
   var play = EffectPlay(effects: SelectableEffects(effects: @[effect]))
   play.selectors = selectionsForEffect(world, character, play.effects)
   for selKey, sel in play.selectors:
      if sel.restrictions.containsSelfRestriction:
         play.selected[selKey] = SelectedEntity(@[character])
      else:
         warn &"Simple effect resolution can only use unambiguous selectors (i.e. ones with self restrictions)"
         return false
   resolveEffect(world, character, play)


proc playCard*(world: World, entity: Entity, card: Entity, effectPlays: EffectPlayGroup) =
   withWorld(world):
      world.eventStmts(CardPlayEvent(card: card, entity: entity)):
         moveCard(world, entity, card, CardLocation.DiscardPile)

         for class, xp in card[Card].xp:
            changeXpDistribution(world, entity, class, xp)

         for play in effectPlays.plays:
            if play.isCost:
               if isConditionMet(world, entity, play.effects.condition):
                  if not resolveEffect(world, entity, play):
                     warn &"effect play could not be properly resolved: {play}"

         for play in effectPlays.plays:
            if not play.isCost:
               if isConditionMet(world, entity, play.effects.condition):
                  if not resolveEffect(world, entity, play):
                     warn &"effect play could not be properly resolved: {play}"

         entity.modify(DeckOwner.cardsPlayedThisTurn.append(card))

proc playCard*(world: World, entity: Entity, card: Entity, effectGroupIndex: int, selectResolver: (SelectorKey, Selector) -> SelectionResult) =
   withWorld(world):
      let effectGroup = card[Card].cardEffectGroups[effectGroupIndex]
      var playGroup = toEffectPlayGroup(world, entity, card, effectGroup)
      for play in playGroup.plays.mitems:
         for key, selector in play.selectors:
            if not play.selected.contains(key):
               let selection = selectResolver(key, selector)
               play.selected[key] = selection
      playCard(world, entity, card, playGroup)
