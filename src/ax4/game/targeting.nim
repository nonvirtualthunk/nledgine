import targeting_types
export targeting_types


import ax4/game/characters
import worlds
import patty
import ax4/game/map
import hex
import ax4/game/cards
import options
import noto
import sequtils
import algorithm
import ax4/game/randomness
import patty
import ax4/game/flags
import prelude
import core

import prelude

proc matchesRestriction*(view: WorldView, character: Entity, effectSource: Entity, ent: Entity, res: SelectionRestriction): bool =
   withView(view):
      match res:
         NoRestriction: true
         Self: ent == character
         EffectSource: ent == effectSource
         Enemy: areEnemies(view, character, ent)
         Friendly: areFriends(view, character, ent)
         InRange(minRange, maxRange):
            let dist = if ent.hasData(Physical):
               ent[Physical].position.distance(character[Physical].position).int
            elif ent.hasData(Tile):
               ent[Tile].position.distance(character[Physical].position).int
            else:
               -1
            dist >= minRange and dist <= maxRange
         EntityChoices(entities): entities.contains(ent)
         TaxonChoices(_): false
         InCardLocation(targetLocation):
            if ent.hasData(Card):
               let targetDeck = activeDeckKind(view, character)
               let curLoc = deckLocation(view, character, ent)
               curLoc == some((targetDeck, targetLocation))
            else:
               false
         WithinMoveRange(movePoints):
            warn &"checking if something is within move range is pretty expensive, not yet implemented"
            true
         AllRestrictions(restrictions):
            for subRes in restrictions:
               if not matchesRestriction(view, character, effectSource, ent, subRes):
                  return false
            true

proc matchesRestriction*(view: WorldView, character: Entity, effectSource: Entity, taxon: Taxon, res: SelectionRestriction): bool =
   withView(view):
      match res:
         NoRestriction: true
         TaxonChoices(choices): choices.contains(taxon)
         _: false

proc matchesRestriction*(view: WorldView, character: Entity, effectSource: Entity, selRes: SelectionResult, res: SelectionRestriction): bool =
   match selRes:
      SelectedEntity(entities):
         for ent in entities:
            if not matchesRestriction(view, character, effectSource, ent, res): return false
      SelectedTaxon(taxons):
         for taxon in taxons:
            if not matchesRestriction(view, character, effectSource, taxon, res): return false
   true

proc possibleEntityMatchesFromRestriction*(view: WorldView, character: Entity, effectSource: Entity, restrictions: SelectionRestriction): Option[seq[Entity]] =
   withView(view):
      match restrictions:
         Self: some(@[character])
         EffectSource: some(@[effectSource])
         InRange(minRange, maxRange):
            var res: seq[Entity]
            let map = view[Map]
            let charPos = character[Physical].position
            for r in minRange .. maxRange:
               for pos in hexRing(charPos, r):
                  let t = map.tileAt(pos)
                  if t.isSome:
                     res.add(t.get)

            for ent in view.entitiesWithData(Physical):
               let dist = ent[Physical].position.distance(charPos).int
               if dist >= minRange and dist <= maxRange:
                  res.add(ent)
            some(res)
         EntityChoices(entities): some(entities)
         InCardLocation(targetLocation):
            some(cardsInLocation(view, character, targetLocation))
         WithinMoveRange(movePoints):
            warn &"we could implement a flood search for possible entities within move range, if desired"
            none(seq[Entity])
         AllRestrictions(restrictions):
            var res: Option[seq[Entity]]
            for subRestriction in restrictions:
               let subRes = possibleEntityMatchesFromRestriction(view, character, effectSource, subRestriction)
               if subRes.isSome:
                  if res.isSome:
                     res.get.add(subRes.get)
                  else:
                     res = subRes
            res
         _: none(seq[Entity])

proc possibleTaxonMatchesFromRestriction*(view: WorldView, character: Entity, effectSource: Entity, restrictions: SelectionRestriction): Option[seq[Taxon]] =
   withView(view):
      match restrictions:
         TaxonChoices(choices): some(choices)
         AllRestrictions(restrictions):
            var res: Option[seq[Taxon]]
            for subRestriction in restrictions:
               let subRes = possibleTaxonMatchesFromRestriction(view, character, effectSource, subRestriction)
               if subRes.isSome:
                  if res.isSome:
                     res.get.add(subRes.get)
                  else:
                     res = subRes
            res
         _: none(seq[Taxon])

proc possibleSelections*(view: WorldView, character: Entity, effectSource: Entity, selector: Selector): seq[SelectionResult] =
   withView(view):
      case selector.kind:
      of SelectionKind.Character:
         for ent in view.entitiesWithData(Character):
            if matchesRestriction(view, character, effectSource, ent, selector.restrictions):
               result.add(SelectedEntity(@[ent]))
      of SelectionKind.Taxon:
         for taxons in possibleTaxonMatchesFromRestriction(view, character, effectSource, selector.restrictions):
            for taxon in taxons:
               if matchesRestriction(view, character, effectSource, taxon, selector.restrictions):
                  result.add(SelectedTaxon(@[taxon]))
      of SelectionKind.Hex:
         for entities in possibleEntityMatchesFromRestriction(view, character, effectSource, selector.restrictions):
            for entity in entities:
               if entity.hasData(Tile) and matchesRestriction(view, character, effectSource, entity, selector.restrictions):
                  result.add(SelectedEntity(@[entity]))
      of SelectionKind.Card:
         for entities in possibleEntityMatchesFromRestriction(view, character, effectSource, selector.restrictions):
            for entity in entities:
               if entity.hasData(Card) and matchesRestriction(view, character, effectSource, entity, selector.restrictions):
                  result.add(SelectedEntity(@[entity]))
      of SelectionKind.CardType:
         for taxons in possibleTaxonMatchesFromRestriction(view, character, effectSource, selector.restrictions):
            for taxon in taxons:
               if matchesRestriction(view, character, effectSource, taxon, selector.restrictions):
                  result.add(SelectedTaxon(@[taxon]))
      of SelectionKind.CharactersInShape:
         warn &"possible selections unimplemented for kind: {selector.kind}"
      of SelectionKind.HexesInShape:
         warn &"possible selections unimplemented for kind: {selector.kind}"
      of SelectionKind.Path:
         warn &"possible selections unimplemented for kind: {selector.kind}"


proc sortByPreference*(view: WorldView, character: Entity, entities: seq[Entity], preference: TargetPreference): seq[Entity] =
   withView(view):
      var entitiesWithSortValue: seq[(Entity, float)]
      case preference.kind:
      of TargetPreferenceKind.Random:
         var r = randomizer(view)
         for ent in entities:
            entitiesWithSortValue.add((ent, r.nextFloat))
      of TargetPreferenceKind.Closest, TargetPreferenceKind.Furthest:
         let startPos = character[Physical].position
         let mult = if preference.kind == TargetPreferenceKind.Closest: 1.0 else: -1.0
         for ent in entities:
            let dist = ent[Physical].position.distance(startPos).float
            entitiesWithSortValue.add((ent, dist * mult))
      else:
         warn &"Unsupported target preference : {preference.kind}"

      entitiesWithSortValue.sort((a, b) => cmp(a[1], b[1]))
      for tup in entitiesWithSortValue:
         result.add(tup[0])

proc isConditionMet*(view: WorldView, character: Entity, cond: GameCondition): bool =
   withView(view):
      match cond:
         AlwaysTrue:
            return true
         HasFlag(flag, comparison, referenceValue):
            let flagValue = flags.flagValue(view, character, flag)
            return comparison.isTrueFor(flagValue, referenceValue)
         IsDamaged(truth):
            let damaged = character[Character].health.currentValue < character[Character].health.maxValue
            return damaged == truth
         CanSee(restriction):
            let sightRange = character[Character].sightRange
            let charPos = character[Physical].position
            for ent in view.entitiesWithData(Character):
               let dist = ent[Physical].position.distance(charPos)
               if dist <= sightRange.float:
                  if matchesRestriction(view, character, character, ent, restriction):
                     return true
         Near(restriction, targetDist):
            let charPos = character[Physical].position
            for ent in view.entitiesWithData(Character):
               let dist = ent[Physical].position.distance(charPos).float
               if dist <= targetDist.float:
                  if matchesRestriction(view, character, character, ent, restriction):
                     return true
      false
