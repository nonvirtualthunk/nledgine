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
import game/modifiers
import strutils
import noto
import root_types
import sequtils

import prelude
import arxregex
import windowingsystem/rich_text
import graphics/image_extras
import effect_display
import options
import ax4/game/ax_events
import ax4/game/cards
import ax4/game/effects
import worlds/identity

export effect_display
export root_types



proc cardInfoFor*(view: WorldView, character: Entity, arch: ref CardArchetype, activeEffectGroup: int): CardInfo =
  let effectGroup = arch.cardData.cardEffectGroups[activeEffectGroup]

  proc cge(allEffects: seq[SelectableEffects], active: bool = true): CharacterGameEffects =
    # var netEffects: seq[GameEffect]
    # for effects in allEffects:
    #   # for effect in effects:
    #   #   let extraCosts = expandCosts(view, character, effect)
    #   #   netEffects.add(extraCosts)
    #   netEffects.add(effects.effects)
    CharacterGameEffects(character: character, view: view, effects: allEffects, active: active)

  if arch.identity.name.isSome:
    result.name = arch.identity.name.get
  else:
    result.name = arch.identity.kind.displayName

  if effectGroup.name.isSome:
    result.name = effectGroup.name.get

  result.image = arch.cardData.image.resolve()

  var costs: seq[SelectableEffects] = effectGroup.costs
  for effects in effectGroup.effects:
    for effect in effects:
      costs.add(expandCosts(view, character, effect))

  for selCost in costs.mitems:
    var toRemove: seq[int]
    for i in 0 ..< selCost.effects.len:
      let cost = selCost.effects[i]
      if cost.kind == GameEffectKind.ChangeResource:
        if not result.mainCost.isSome:
          result.mainCost = some(cge(@[SelectableEffects(effects: @[cost])]))
          toRemove.add(i)
        elif not result.secondaryCost.isSome:
          result.secondaryCost = some(cge(@[SelectableEffects(effects: @[cost])]))
          toRemove.add(i)
    var decrementor = 0
    for toRemoveIndex in toRemove:
      selCost.effects.delete(toRemoveIndex - decrementor)
      decrementor.inc

  var remainingCosts = costs.filterIt(it.effects.nonEmpty)

  for i in 0 ..< arch.cardData.cardEffectGroups.len:
    let nonCosts = arch.cardData.cardEffectGroups[i].effects.filterIt(not it.isCost)
    var allRemainingEffects = remainingCosts
    allRemainingEffects.add(nonCosts)
    result.effects.add(cge(allRemainingEffects, i == activeEffectGroup))



proc cardInfoFor*(view: WorldView, character: Entity, card: Entity, activeEffectGroup: int): CardInfo =
  withView(view):
    let arch = new CardArchetype
    arch[] = CardArchetype(
      cardData: card[Card],
      identity: card[Identity],
    )
    cardInfoFor(view, character, arch, activeEffectGroup)
