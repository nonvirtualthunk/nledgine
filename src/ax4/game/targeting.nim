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

import prelude

proc matchesRestriction*(view: WorldView, character: Entity, ent: Entity, res: SelectionRestriction): bool =
   withView(view):
      match res:
         NoRestriction: true
         Self: ent == character
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
               if not matchesRestriction(view, character, ent, subRes):
                  return false
            true

proc matchesRestriction*(view: WorldView, character: Entity, taxon: Taxon, res: SelectionRestriction): bool =
   withView(view):
      match res:
         NoRestriction: true
         TaxonChoices(choices): choices.contains(taxon)
         _: false

proc possibleEntityMatchesFromRestriction(view: WorldView, character: Entity, restrictions: SelectionRestriction): Option[seq[Entity]] =
   withView(view):
      match restrictions:
         Self: some(@[character])
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
               let subRes = possibleEntityMatchesFromRestriction(view, character, subRestriction)
               if subRes.isSome:
                  if res.isSome:
                     res.get.add(subRes.get)
                  else:
                     res = subRes
            res
         _: none(seq[Entity])

proc possibleTaxonMatchesFromRestriction(view: WorldView, character: Entity, restrictions: SelectionRestriction): Option[seq[Taxon]] =
   withView(view):
      match restrictions:
         TaxonChoices(choices): some(choices)
         AllRestrictions(restrictions):
            var res: Option[seq[Taxon]]
            for subRestriction in restrictions:
               let subRes = possibleTaxonMatchesFromRestriction(view, character, subRestriction)
               if subRes.isSome:
                  if res.isSome:
                     res.get.add(subRes.get)
                  else:
                     res = subRes
            res
         _: none(seq[Taxon])

proc possibleSelections*(view: WorldView, character: Entity, selector: Selector): seq[SelectionResult] =
   withView(view):
      case selector.kind:
      of SelectionKind.Character:
         for ent in view.entitiesWithData(Character):
            if matchesRestriction(view, character, ent, selector.restrictions):
               result.add(SelectedEntity(@[ent]))
      of SelectionKind.Taxon:
         for taxons in possibleTaxonMatchesFromRestriction(view, character, selector.restrictions):
            for taxon in taxons:
               if matchesRestriction(view, character, taxon, selector.restrictions):
                  result.add(SelectedTaxon(@[taxon]))
      of SelectionKind.Hex:
         for entities in possibleEntityMatchesFromRestriction(view, character, selector.restrictions):
            for entity in entities:
               if entity.hasData(Tile) and matchesRestriction(view, character, entity, selector.restrictions):
                  result.add(SelectedEntity(@[entity]))
      of SelectionKind.Card:
         for entities in possibleEntityMatchesFromRestriction(view, character, selector.restrictions):
            for entity in entities:
               if entity.hasData(Card) and matchesRestriction(view, character, entity, selector.restrictions):
                  result.add(SelectedEntity(@[entity]))
      of SelectionKind.CardType:
         for taxons in possibleTaxonMatchesFromRestriction(view, character, selector.restrictions):
            for taxon in taxons:
               if matchesRestriction(view, character, taxon, selector.restrictions):
                  result.add(SelectedTaxon(@[taxon]))
      of SelectionKind.CharactersInShape:
         warn &"possible selections unimplemented for kind: {selector.kind}"
      of SelectionKind.HexesInShape:
         warn &"possible selections unimplemented for kind: {selector.kind}"
      of SelectionKind.Path:
         warn &"possible selections unimplemented for kind: {selector.kind}"
