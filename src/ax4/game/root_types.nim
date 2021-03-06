import patty
import worlds
import game/randomness
import config
import arxregex
import strutils
import noto

variantp SelectionResult:
   SelectedEntity(entities: seq[Entity])
   SelectedTaxon(taxons: seq[Taxon])

type SelectionKind* {.pure.} = enum
   Character
   Hex
   Taxon
   Card
   CardType
   CharactersInShape
   HexesInShape
   Path


type CardLocation* = enum
   Hand
   DrawPile
   DiscardPile
   ExpendPile
   ExhaustPile
   ConsumedPile

type DeckKind* {.pure.} = enum
   Combat


proc contains*(s: SelectionResult, e: Entity): bool =
   match s:
      SelectedEntity(entities): entities.contains(e)
      SelectedTaxon(_): false

proc selectedEntities*(s: SelectionResult): seq[Entity] =
   match s:
      SelectedEntity(entities): entities
      SelectedTaxon(_): @[]


proc selectedTaxons*(s: SelectionResult): seq[Taxon] =
   match s:
      SelectedEntity(_): @[]
      SelectedTaxon(taxons): taxons