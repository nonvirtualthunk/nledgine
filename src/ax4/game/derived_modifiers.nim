import ax4/game/effect_types
import worlds
import ax4/game/cards
import worlds/taxonomy
import patty
import options
import ax4/game/flags
import math

proc tmpDTD*(): DataType[DeckOwner] =
   DeckOwner.getDataType()

proc derivedModifierDelta*[T](view: WorldView, character: Entity, target: Option[Entity], modifier: DerivedModifier[T]): int =
   withView(view):
      let entity = case modifier.entity:
         of DerivedModifierEntity.Self:
            character
         of DerivedModifierEntity.Target:
            target.get(SentinelEntity)

      if entity == SentinelEntity:
         return 0

      let rawValue = match modifier.source:
         Flag(flag):
            flagValue(view, entity, flag)
         CardPlays(cardType):
            var counter = 0
            # this view.hasData incantation is necessary because of generic type resolution problems
            # see https://github.com/nim-lang/Nim/issues/8677
            if view.hasData(entity, DeckOwner.getDataType()):
               for card in view.data(entity, DeckOwner).cardsPlayedThisTurn:
                  if cardType.isNone or card[Identity].kind.isA(cardType.get):
                     counter.inc
            counter
         Fixed(amount):
            amount


      return rawValue * modifier.multiplier + sgn(rawValue) * modifier.adder
