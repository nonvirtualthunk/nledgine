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
import strutils
import noto
import root_types
import sequtils

import prelude
import arxregex
import graphics/image_extras
import worlds/taxonomy
import options
import ax4/game/ax_events
import ax4/game/randomness

export root_types

type
   Card* = object
      cardEffectGroups*: seq[EffectGroup]
      xp*: Table[Taxon, int]
      image*: ImageLike
      locked*: bool
      inDeck*: Option[Entity]

   CardArchetype* = object
      cardData*: ref Card
      identity*: ref Identity

   CardInfo* = object
      name*: string
      mainCost*: Option[CharacterGameEffects]
      secondaryCost*: Option[CharacterGameEffects]
      image*: ImageLike
      effects*: seq[CharacterGameEffects]

   Deck* = object
      cards*: Table[CardLocation, seq[Entity]]

   DeckOwner* = object
      combatDeck*: Deck
      activeDeckKind*: DeckKind
      cardsPlayedThisTurn*: seq[Entity]

   CardMovedEvent* = ref object of AxEvent
      card*: Entity
      deckOwner*: Entity
      fromDeck*: DeckKind
      fromLocation*: CardLocation
      toDeck*: DeckKind
      toLocation*: CardLocation

   CardAddedEvent* = ref object of AxEvent
      card*: Entity
      deckOwner*: Entity
      toDeck*: DeckKind
      toLocation*: CardLocation

   CardRemovedEvent* = ref object of AxEvent
      card*: Entity
      deckOwner*: Entity
      fromDeck*: DeckKind
      fromLocation*: CardLocation

   HandDrawnEvent* = ref object of AxEvent
      deckOwner*: Entity
      deck*: DeckKind

   ShuffleEvent* = ref object of AxEvent
      deckOwner*: Entity
      deck*: DeckKind
      location*: CardLocation



defineReflection(DeckOwner)
defineReflection(Card)
defineNestedReflection(Deck)

method toString*(evt: CardAddedEvent, view: WorldView): string =
   return &"CardAdded({$evt[]})"
method toString*(evt: CardRemovedEvent, view: WorldView): string =
   return &"CardRemoved({$evt[]})"
method toString*(evt: CardMovedEvent, view: WorldView): string =
   return &"CardMoved({$evt[]})"
method toString*(evt: HandDrawnEvent, view: WorldView): string =
   return &"HandDrawn{$evt[]}"
method toString*(evt: ShuffleEvent, view: WorldView): string =
   return &"Shuffle{$evt[]}"


proc deck*(deckOwner: ref DeckOwner, kind: DeckKind): ptr Deck =
   case kind
   of DeckKind.Combat: deckOwner.combatDeck.addr

proc activeDeck*(deckOwner: ref DeckOwner): ptr Deck =
   deckOwner.deck(deckOwner.activeDeckKind)

proc activeDeck*(view: WorldView, deckOwner: Entity): ptr Deck =
   activeDeck(view.data(deckOwner, DeckOwner))

proc activeDeckKind*(view: WorldView, deckOwner: Entity): DeckKind =
   view.data(deckOwner, DeckOwner).activeDeckKind



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

proc removeCardFromCurrentLocation*(world: World, entity: Entity, card: Entity): Option[(DeckKind, CardLocation)] {.discardable.} =
   let locOpt = deckLocation(world, entity, card)
   if locOpt.isSome:
      let (deckKind, location) = locOpt.get
      removeCardFromLocation(world, entity, card, deckKind, location)
   else:
      warn &"cannot move card from current location, not in deck at all: {entity}, {card}"
   locOpt

# Unconditionally places the given card in the given location in this owner/deck
proc addCardToLocation(world: World, entity: Entity, card: Entity, deckKind: DeckKind, location: CardLocation) =
   withWorld(world):
      case deckKind:
      of DeckKind.Combat:
         modify(entity, nestedModification(DeckOwner.combatDeck, DeckType.cards.appendToKey(location, @[card])))


# Move card from the given deck/location to a desired deck/location
proc moveCard*(world: World, entity: Entity, card: Entity, fromDeckKind: DeckKind, fromLocation: CardLocation, deckKind: DeckKind, location: CardLocation) =
   world.eventStmts(CardMovedEvent(entity: entity, deckOwner: entity, card: card, toDeck: deckKind, toLocation: location, fromDeck: fromDeckKind, fromLocation: fromLocation)):
      removeCardFromLocation(world, entity, card, fromDeckKind, fromLocation)
      addCardToLocation(world, entity, card, deckKind, location)

# Add a card not at all present in the deck owner to a deck/location within it
proc addCard*(world: World, entity: Entity, card: Entity, toDeck: DeckKind, toLocation: CardLocation) =
   withWorld(world):
      world.eventStmts(CardAddedEvent(entity: entity, deckOwner: entity, card: card, toDeck: toDeck, toLocation: toLocation)):
         card.modify(Card.inDeck := some(entity))
         addCardToLocation(world, entity, card, toDeck, toLocation)

# Move a card from its existing location in this deck owner to a different deck/location, no-op if already there
proc moveCardToLocation*(world: World, entity: Entity, card: Entity, deckKind: DeckKind, location: CardLocation) =
   let curDeckLoc = deckLocation(world, entity, card)
   if curDeckLoc.isSome:
      let (curDeck, curLoc) = curDeckLoc.get
      if curDeck != deckKind or curLoc != location:
         moveCard(world, entity, card, curDeck, curLoc, deckKind, location)
   else:
      warn &"Trying to move card {card} to location {location} in {deckKind} but it is not present on deck owner at all"

proc removeCard*(world: World, entity: Entity, card: Entity) =
   let locOpt = deckLocation(world, entity, card)
   if locOpt.isSome:
      let (deck, loc) = locOpt.get
      withWorld(world):
         world.eventStmts(CardRemovedEvent(entity: entity, deckOwner: entity, card: card, fromDeck: deck, fromLocation: loc)):
            card.modify(Card.inDeck := none(Entity))
            removeCardFromLocation(world, entity, card, deck, loc)

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

proc moveCard*(world: World, card: Entity, toDeck: DeckKind, location: CardLocation) =
   withView(world):
      let entity = card[Card].inDeck
      if entity.isSome:
         let entity = entity.get
         let locOpt = deckLocation(world, entity, card)
         if locOpt.isSome:
            let (fromDeckKind, fromLocation) = locOpt.get
            moveCard(world, entity, card, fromDeckKind, fromLocation, fromDeckKind, location)
         else:
            warn &"cannot move card from current location, not in deck at all: {entity}, {card}"
      else:
         warn &"cannot move card from current location, not in any deck: {entity}, {card}, -> {toDeck}, {location}"

proc cardsInLocation*(view: WorldView, entity: Entity, deckKind: DeckKind, location: CardLocation): seq[Entity] =
   let deck = view.data(entity, DeckOwner).deck(deckKind)
   deck.cards.getOrDefault(location)

proc cardsInLocation*(view: WorldView, entity: Entity, location: CardLocation): seq[Entity] =
   cardsInLocation(view, entity, activeDeckKind(view, entity), location)

proc shuffle*(world: World, entity: Entity, deck: DeckKind, location: CardLocation) =
   var r = randomizer(world)
   var cards = cardsInLocation(world, entity, deck, location)
   var newCards: seq[Entity]
   while cards.nonEmpty:
      let index = r.nextInt(cards.len)
      let card = cards[index]
      cards.del(index)
      newCards.add(card)
   world.eventStmts(ShuffleEvent(deckOwner: entity, entity: entity, deck: deck, location: location)):
      case deck:
      of DeckKind.Combat:
         modify(entity, nestedModification(DeckOwner.combatDeck, DeckType.cards.put(location, newCards)))


proc moveAllCardsBetweenLocations*(world: World, entity: Entity, deck: DeckKind, fromLocation: CardLocation, toLocation: CardLocation, shuffle: bool) =
   for card in cardsInLocation(world, entity, deck, fromLocation):
      moveCardToLocation(world, entity, card, deck, toLocation)
   if shuffle:
      shuffle(world, entity, deck, toLocation)


proc drawCard*(world: World, entity: Entity, deck: DeckKind) =
   var drawPile = cardsInLocation(world, entity, deck, CardLocation.DrawPile)
   if drawPile.isEmpty:
      moveAllCardsBetweenLocations(world, entity, deck, CardLocation.DiscardPile, CardLocation.DrawPile, shuffle = true)
      drawPile = cardsInLocation(world, entity, deck, CardLocation.DrawPile)
   if drawPile.nonEmpty:
      moveCardToLocation(world, entity, drawPile[drawPile.len - 1], deck, CardLocation.Hand)
   else:
      warn &"Could not draw any cards, no cards to draw"

proc drawHand*(world: World, entity: Entity, deck: DeckKind) =
   world.eventStmts(HandDrawnEvent(entity: entity, deckOwner: entity, deck: deck)):
      var cardsToDraw = 6

      let drawPile = cardsInLocation(world, entity, deck, CardLocation.DrawPile)
      let discardPile = cardsInLocation(world, entity, deck, CardLocation.DiscardPile)
      for card in (discardPile & drawPile):
         if cardsToDraw > 0 and card[Card].locked:
            cardsToDraw.dec
            moveCardToLocation(world, entity, card, deck, CardLocation.Hand)

      for i in 0 ..< cardsToDraw:
         drawCard(world, entity, deck)



# Loading and configuration


const xpPattern = re"(?i)([a-z]+)\s?->\s?([0-9]+)"

proc readFromConfig(cv: ConfigValue, v: var Card) =
   if cv["effects"].nonEmpty:
      let effects = cv["effects"].readInto(seq[GameEffect])
      v.cardEffectGroups = @[EffectGroup(effects: @[SelectableEffects(effects: effects)])]
      # if v.cardEffectGroups.isEmpty:
      #    v.cardEffectGroups.add(EffectGroup())
      # readInto(cv, v.cardEffectGroups[0])
      # info &"reading into effect group 0 : {v.cardEffectGroups[0]}"
   if cv["costs"].nonEmpty:
      let costs = cv["costs"].readInto(seq[GameEffect])
      let selEff = SelectableEffects(effects: costs, isCost: true)
      if v.cardEffectGroups.isEmpty:
         v.cardEffectGroups = @[EffectGroup(effects: @[selEff])]
      else:
         v.cardEffectGroups[v.cardEffectGroups.len - 1].effects.add(selEff)

   if cv["conditionalEffects"].nonEmpty:
      let condEffects = cv["conditionalEffects"]["effects"].readInto(seq[GameEffect])
      let cond = cv["conditionalEffects"]["condition"].readInto(GameCondition)
      let selEff = SelectableEffects(effects: condEffects, condition: cond)
      if v.cardEffectGroups.isEmpty:
         v.cardEffectGroups = @[EffectGroup(effects: @[selEff])]
      else:
         v.cardEffectGroups[v.cardEffectGroups.len - 1].effects.add(selEff)

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

   let confs = @["base_cards.sml"]
   for confPath in confs:
      let conf = resources.config("ax4/game/" & confPath)
      for k, v in conf["CardTypes"]:
         let cardTaxon = taxon("card types", k)
         var identity = readInto(v, Identity)
         identity.kind = cardTaxon
         let arch = CardArchetype(
            cardData: new Card,
            identity: new Identity
         )
         arch.cardData[] = readInto(v, Card)
         arch.identity[] = identity

         arch.cardData.image.preload()

         lib[cardTaxon] = arch


   lib



when isMainModule:
   let lib = library(CardArchetype)

   let cardArch = lib[taxon("card types", "move")]

   info &"Card arch: {cardArch.cardData[]}"

   let recklessSmash = lib[taxon("card types", "reckless smash")]
   info &"Reckless smash: {recklessSmash.cardData[]}"

   let firstCost = cardArch.cardData.cardEffectGroups[0].costs[0]
   echoAssert firstCost.effects[0].kind == GameEffectKind.ChangeResource
   echoAssert firstCost.effects[0].resource == taxon("resource pools", "actionPoints")

   noto.quit()
