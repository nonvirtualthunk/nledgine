import effect_types
import worlds
import game/library

import reflect
import resources
import worlds/taxonomy
import config
import config/config_helpers
import tables
import targeting_types
import modifiers
import strutils
import noto
import root_types
import sequtils

import prelude
import arxregex
import windowingsystem/rich_text
import graphics/image_extras
import worlds/taxonomy
import effect_display
import options
import ax4/game/ax_events
import ax4/game/cards

export effect_display
export root_types



proc cardInfoFor*(view: WorldView, character: Entity, arch: CardArchetype, activeEffectGroup: int): CardInfo =
   let effectGroup = arch.cardData.cardEffectGroups[activeEffectGroup]

   proc cge(allEffects: seq[SelectableEffects], active: bool = true): CharacterGameEffects =
      var netEffects: seq[GameEffect]
      for effects in allEffects:
         netEffects.add(effects.effects)
      CharacterGameEffects(character: character, view: view, effects: netEffects, active: active)

   if arch.identity.name.isSome:
      result.name = arch.identity.name.get
   else:
      result.name = arch.identity.kind.displayName

   if effectGroup.name.isSome:
      result.name = effectGroup.name.get

   result.image = arch.cardData.image

   if effectGroup.costs.len > 0:
      result.mainCost = cge(@[effectGroup.costs[0]])
   if effectGroup.costs.len > 1:
      result.secondaryCost = cge(@[effectGroup.costs[1]])

   for i in 0 ..< arch.cardData.cardEffectGroups.len:
      let nonCosts = arch.cardData.cardEffectGroups[i].effects.filterIt(not it.isCost)
      result.effects.add(cge(nonCosts, i == activeEffectGroup))



proc cardInfoFor*(view: WorldView, character: Entity, card: Entity, activeEffectGroup: int): CardInfo =
   withView(view):
      let arch = CardArchetype(
         cardData: card[Card],
         identity: card[Identity],
      )
      cardInfoFor(view, character, arch, activeEffectGroup)
