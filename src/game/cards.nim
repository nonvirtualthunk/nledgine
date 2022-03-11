import tables
import game_prelude
import strutils
import noto
import game/randomness


type

  CardLocation* = object
    cards*: seq[Entity]

  Deck* = object
    locations: Table[Taxon, CardLocation]

  CardCollection* = object
    cards*: seq[Entity]
    activeCards*: seq[Entity]


  CardMovedEvent* = ref object of GameEvent
    card*: Entity
    deck*: Entity
    fromLocation*: Option[Taxon]
    toLocation*: Taxon

  CardLocationShuffledEvent* = ref object of GameEvent
    deck*: Entity
    location*: Taxon

  DeckClearedEvent* = ref object of GameEvent
    deck*: Entity

  CardMovePosition* = enum
    Top
    Bottom
    Random
    Shuffle

addTaxonomyLoader(
  TaxonomyLoader(
    loadStaticTaxons: proc() : seq[ProtoTaxon] {.gcsafe.} =
      @[
        ProtoTaxon(namespace: "GameConcepts", name: "CardLocation", parents: @[]),
        ProtoTaxon(namespace: "CardLocations", name: "DrawPile", parents: @["GameConcepts.CardLocation"]),
        ProtoTaxon(namespace: "CardLocations", name: "DiscardPile", parents: @["GameConcepts.CardLocation"]),
        ProtoTaxon(namespace: "CardLocations", name: "Graveyard", parents: @["GameConcepts.CardLocation"]),
        ProtoTaxon(namespace: "CardLocations", name: "Exiled", parents: @["GameConcepts.CardLocation"]),
        ProtoTaxon(namespace: "CardLocations", name: "Hand", parents: @["GameConcepts.CardLocation"]),
        ProtoTaxon(namespace: "CardLocations", name: "Play", parents: @["GameConcepts.CardLocation"]),
      ]     
  )
)


eventToStr(CardMovedEvent)
eventToStr(CardLocationShuffledEvent)
eventToStr(DeckClearedEvent)

defineReflection(Deck)
defineReflection(CardCollection)

proc cardLocation*(d: ref Deck, area: Taxon) : CardLocation =
  d.locations.getOrDefault(area)

proc cardsIn*(d: ref Deck, location: Taxon) : seq[Entity] = cardLocation(d, location).cards
proc cardsIn*(world: LiveWorld, deck: Entity, location: Taxon) : seq[Entity] = cardsIn(deck[Deck], location)

proc hand*(d: ref Deck) : seq[Entity] = cardsIn(d, † CardLocations.Hand)
proc discardPile*(d: ref Deck): seq[Entity] = cardsIn(d, † CardLocations.DiscardPile)
proc graveyard*(d: ref Deck): seq[Entity] = cardsIn(d, † CardLocations.Graveyard)
proc exiled*(d: ref Deck): seq[Entity] = cardsIn(d, † CardLocations.Exiled)
proc drawPile*(d: ref Deck): seq[Entity] = cardsIn(d, † CardLocations.DrawPile)
proc inPlay*(d: ref Deck): seq[Entity] = cardsIn(d, † CardLocations.Play)

proc currentCardLocation*(d: ref Deck, card: Entity): Option[Taxon] =
  for l, cl in d.locations:
    if cl.cards.contains(card):
      return some(l)
  none(Taxon)

proc shuffle*(world: LiveWorld, deck: Entity, location: Taxon) =
  var r = randomizer(world)
  let d = deck[Deck]
  if d.locations.contains(location):
    world.eventStmts(CardLocationShuffledEvent(deck: deck, location: location)):
      var oldOrder = d.locations[location].cards
      var newOrder : seq[Entity]
      while oldOrder.nonEmpty:
        let i = r.nextInt(oldOrder.len)
        newOrder.add(oldOrder[i])
        oldOrder.del(i)
      d.locations[location].cards = newOrder


proc moveCardTo*(world: LiveWorld, deck: Entity, card: Entity, toLocation: Taxon, moveTo: CardMovePosition = CardMovePosition.Top) =
  let d = deck[Deck]
  if not d.locations.contains(toLocation):
    d.locations[toLocation] = CardLocation()
  let existingLocation = currentCardLocation(d, card)
  world.eventStmts(CardMovedEvent(card: card, deck: deck, fromLocation: existingLocation, toLocation: toLocation)):
    if existingLocation.isSome:
      d.locations[existingLocation.get].cards.deleteValue(card)
    case moveTo:
      of CardMovePosition.Top: d.locations[toLocation].cards.add(card)
      of CardMovePosition.Bottom: d.locations[toLocation].cards.insert(card, 0)
      of CardMovePosition.Random:
        var r : Randomizer = randomizer(world)
        d.locations[toLocation].cards.insert(card, r.nextInt(d.locations[toLocation].cards.len + 1))
      of CardMovePosition.Shuffle:
        d.locations[toLocation].cards.add(card)
        shuffle(world, deck, toLocation)

proc addCardTo*(world: LiveWorld, deck: Entity, card: Entity, toLocation: Taxon, moveTo: CardMovePosition = CardMovePosition.Top) =
  moveCardTo(world, deck, card, toLocation, moveTo)


proc moveAllCardsFrom*(world: LiveWorld, deck: Entity, fromLocation: Taxon, toLocation: Taxon, moveTo: CardMovePosition = CardMovePosition.Top) =
  let cards = cardsIn(world, deck, fromLocation)
  for card in cards:
    moveCardTo(world, deck, card, toLocation, moveTo)

proc clearDeck*(world: LiveWorld, deck: Entity) =
  world.eventStmts(DeckClearedEvent(deck: deck)):
    deck[Deck].locations.clear()


