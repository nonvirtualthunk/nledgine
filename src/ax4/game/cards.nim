import effect_types
import worlds
import game/library

import reflect
import resources
import worlds/taxonomy
import config
import config/config_helpers
import tables
import targeting
import modifiers
import strutils
import noto
import root_types

import prelude
import arxregex
import windowingsystem/rich_text
import graphics/image_extras
import worlds/taxonomy
import effect_display
import options
import ax4/game/ax_events

export effect_display
export root_types

type
   Card* = object
      cardEffectGroups*: seq[EffectGroup]
      xp*: Table[Taxon, int]
      image*: ImageLike

   CardArchetype* = object
      cardData*: ref Card
      identity*: ref Identity

   CardInfo* = object
      name*: string
      mainCost*: CharacterGameEffects
      secondaryCost*: CharacterGameEffects
      image*: ImageLike
      effects*: seq[CharacterGameEffects]

   Deck* = object
      cards*: Table[CardLocation, seq[Entity]]

   DeckKind* {.pure.} = enum
      Combat

   DeckOwner* = object
      combatDeck*: Deck
      activeDeckKind*: DeckKind

   CardMovedEvent* = ref object of AxEvent
      card*: Entity
      deckOwner*: Entity
      fromDeck*: DeckKind
      fromLocation*: CardLocation
      toDeck*: DeckKind
      toLocation*: CardLocation




defineReflection(DeckOwner)
defineReflection(Card)
defineNestedReflection(Deck)



proc activeDeck*(deckOwner: ref DeckOwner): ptr Deck =
   case deckOwner.activeDeckKind
   of DeckKind.Combat: deckOwner.combatDeck.addr

proc activeDeck*(view: WorldView, deckOwner: Entity): ptr Deck =
   activeDeck(view.data(deckOwner, DeckOwner))



proc createCard*(arch: CardArchetype, world: World): Entity =
   withWorld(world):
      let ent = world.createEntity()
      ent.attachData(arch.cardData[])
      ent.attachData(arch.identity[])
      ent

iterator decks*(owner: ref DeckOwner): (DeckKind, ptr Deck) =
   yield (DeckKind.Combat, owner.combatDeck.addr)

proc deckLocation*(view: WorldView, entity: Entity, card: Entity): Option[(DeckKind, CardLocation)] =
   withView(view):
      let deckOwner = entity[DeckOwner]
      for deckKind, deck in deckOwner.decks:
         for location, cards in deck.cards:
            if cards.contains(card):
               return some((deckKind, location))
      none((DeckKind, CardLocation))

# proc deckField(kind: DeckKind): Field[DeckOwner, Deck] =
#    case kind:
#    of DeckKind.Combat: DeckOwner.combatDeck

proc removeCardFromLocation*(world: World, entity: Entity, card: Entity, deckKind: DeckKind, location: CardLocation) =
   withWorld(world):
      case deckKind:
      of DeckKind.Combat:
         modify(entity, nestedModification(DeckOwner.combatDeck, DeckType.cards.removeFromKey(location, @[card])))

proc removeCardFromCurrentLocation*(world: World, entity: Entity, card: Entity) =
   let locOpt = deckLocation(world, entity, card)
   if locOpt.isSome:
      let (deckKind, location) = locOpt.get
      removeCardFromLocation(world, entity, card, deckKind, location)
   else:
      warn &"cannot move card from current location, not in deck at all: {entity}, {card}"

proc moveCardToLocation*(world: World, entity: Entity, card: Entity, deckKind: DeckKind, location: CardLocation) =
   withWorld(world):
      case deckKind:
      of DeckKind.Combat:
         modify(entity, nestedModification(DeckOwner.combatDeck, DeckType.cards.appendToKey(location, @[card])))

proc moveCard*(world: World, entity: Entity, card: Entity, fromDeckKind: DeckKind, fromLocation: CardLocation, deckKind: DeckKind, location: CardLocation) =
   world.eventStmts(CardMovedEvent(entity: entity, deckOwner: entity, card: card, toDeck: deckKind, toLocation: location, fromDeck: fromDeckKind, fromLocation: fromLocation)):
      removeCardFromLocation(world, entity, card, fromDeckKind, fromLocation)
      moveCardToLocation(world, entity, card, deckKind, location)


proc moveCard*(world: World, entity: Entity, card: Entity, deckKind: DeckKind, location: CardLocation) =
   let locOpt = deckLocation(world, entity, card)
   if locOpt.isSome:
      let (fromDeckKind, fromLocation) = locOpt.get
      moveCard(world, entity, card, fromDeckKind, fromLocation, deckKind, location)
   else:
      warn &"cannot move card from current location, not in deck at all: {entity}, {card}"

proc moveCard*(world: World, entity: Entity, card: Entity, location: CardLocation) =
   let locOpt = deckLocation(world, entity, card)
   if locOpt.isSome:
      let (fromDeckKind, fromLocation) = locOpt.get
      moveCard(world, entity, card, fromDeckKind, fromLocation, fromDeckKind, location)
   else:
      warn &"cannot move card from current location, not in deck at all: {entity}, {card}"



# Loading and configuration


const xpPattern = re"(?i)([a-z]+)\s?->\s?([0-9]+)"

proc readFromConfig(cv: ConfigValue, v: var Card) =
   readInto(cv["cardEffectGroups"], v.cardEffectGroups)
   readInto(cv["image"], v.image)
   let xpConf = cv["xp"]
   if xpConf.isStr:
      matcher(xpConf.asStr):
         extractMatches(xpPattern, keyStr, valueStr):
            let t = findTaxon(keyStr)
            if t == UnknownThing:
               warn &"could not find skill {keyStr}"
            v.xp[findTaxon(keyStr)] = valueStr.parseInt()
         warn &"XP string {xpConf.asStr} did not match expected pattern of \"SkillName -> 123\""
   elif xpConf.isObj:
      for subK, subV in xpConf:
         let t = findTaxon(subK)
         if t == UnknownThing:
            warn &"could not find skill {subK}"
         v.xp[findTaxon(subK)] = subV.asInt

defineLibrary[CardArchetype]:
   var lib = new Library[CardArchetype]
   lib.defaultNamespace = "card types"

   let confs = @["BaseCards.sml"]
   for confPath in confs:
      let conf = resources.config("ax4/game/" & confPath)
      for k, v in conf["Cards"]:
         let cardTaxon = taxon("card types", k)
         var identity = readInto(v, Identity)
         identity.kind = cardTaxon
         let arch = CardArchetype(
            cardData: new Card,
            identity: new Identity
         )
         arch.cardData[] = readInto(v, Card)
         arch.identity[] = identity

         lib[cardTaxon] = arch


   lib


proc cardInfoFor*(view: WorldView, character: Entity, arch: CardArchetype, activeEffectGroup: int): CardInfo =
   let effectGroup = arch.cardData.cardEffectGroups[activeEffectGroup]

   proc cge(effects: seq[GameEffect], active: bool = true): CharacterGameEffects =
      CharacterGameEffects(character: character, view: view, effects: effects, active: active)

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
      result.effects.add(cge(arch.cardData.cardEffectGroups[i].effects, i == activeEffectGroup))



proc cardInfoFor*(view: WorldView, character: Entity, card: Entity, activeEffectGroup: int): CardInfo =
   withView(view):
      let arch = CardArchetype(
         cardData: card[Card],
         identity: card[Identity],
      )
      cardInfoFor(view, character, arch, activeEffectGroup)

when isMainModule:
   let lib = library(CardArchetype)

   let cardArch = lib[taxon("card types", "move")]

   let firstCost = cardArch.cardData.cardEffectGroups[0].costs[0]
   echoAssert firstCost.kind == GameEffectKind.ChangeResource
   echoAssert firstCost.target == selfSelector()
   echoAssert firstCost.resource == taxon("resource pools", "actionPoints")
   echoAssert firstCost.resourceModifier == modifiers.reduce(1)
