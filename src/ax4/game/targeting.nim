import patty
import worlds
import root_types
import hashes

variantp SelectionShape:
   Hex
   Line(startDistance : int, length : int)



variantp SelectionRestriction:
   Enemy
   Friendly
   InRange(minRange : int, maxRange : int)
   EntityChoices(entities : seq[Entity])
   TaxonChoices(taxons : seq[Taxon])
   InCardLocation(cardLocation : CardLocation)
   WithinMoveRange(movePoints : int)

variantp SelectorKey:
   Primary
   Secondary
   Subject
   Object
   SubSelector(index : int, key : ref SelectorKey)

proc hash*(k : SelectorKey) : Hash =
   var h : Hash = 0
   match k:
      Primary: h = 0.hash
      Secondary: h = 1.hash
      SubSelector(index, subKey):
         h = h !& index
         h = h !& hash(subKey[])
      Subject: h = 2.hash
      Object: h = 3.hash
   result = !$h

type

   # TargetSelectionKind* {.pure.} = enum
   #    Self
   #    Enemy
   #    Friendly
   #    TargetShape

   Selector* = object
      restrictions* : seq[SelectionRestriction]
      case kind* : SelectionKind
      of SelectionKind.Self: discard
      of SelectionKind.Character: 
         characterCount* : int
      of SelectionKind.Taxon: 
         options* : seq[Taxon]
      of SelectionKind.Hex: 
         hexCount* : int
      of SelectionKind.CharactersInShape,SelectionKind.HexesInShape: 
         shape* : SelectionShape
      of SelectionKind.Card: 
         cards* : seq[Entity]
      of SelectionKind.CardType: 
         cardTypes* : seq[Taxon]
      of SelectionKind.Path:
         moveRange* : int
         subjectSelector* : SelectorKey



proc `==`*(a,b : Selector) : bool =
   if a.kind != b.kind:
      false
   else:
      case a.kind
      of SelectionKind.Self: true
      of SelectionKind.Character: a.characterCount == b.characterCount
      of SelectionKind.Taxon: a.options == b.options
      of SelectionKind.Hex: a.hexCount == b.hexCount
      of SelectionKind.CharactersInShape,SelectionKind.HexesInShape: a.shape == b.shape
      of SelectionKind.Card: a.cards == b.cards
      of SelectionKind.CardType: a.cardTypes == b.cardTypes
      of SelectionKind.Path: a.moveRange == b.moveRange and a.subjectSelector == b.subjectSelector


proc selfSelector*() : Selector = 
   Selector(kind : SelectionKind.Self)

proc enemySelector*(count : int) : Selector =
   Selector(kind : SelectionKind.Character, characterCount : count, restrictions : @[Enemy()])

proc friendlySelector*(count : int) : Selector = 
   Selector(kind : SelectionKind.Character, characterCount : count, restrictions : @[Friendly()])

proc charactersInShapeSelector*(shape : SelectionShape) : Selector =
   Selector(kind : SelectionKind.CharactersInShape, shape : shape)

proc pathSelector*(maxMoveRange : int, subjectSelector : SelectorKey) : Selector =
   Selector(kind : SelectionKind.Path, moveRange : maxMoveRange, subjectSelector : subjectSelector)

proc inRange*(sel : var Selector, minRange : int, maxRange : int = 1000) : var Selector =
   sel.restrictions.add(InRange(minRange, maxRange))
   sel