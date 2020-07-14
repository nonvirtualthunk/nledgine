import patty
import worlds
import sequtils

variantp SelectionResult:
   SelectedEntity(entities: seq[Entity])
   SelectedTaxon(taxons: seq[Taxon])

type SelectionKind* {.pure.} = enum
   Self
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
   ExhaustPile
   ConsumedPile


proc contains*(s: SelectionResult, e: Entity): bool =
   match s:
      SelectedEntity(entities): entities.contains(e)
      SelectedTaxon(_): false

proc selectedEntities*(s: SelectionResult): seq[Entity] =
   match s:
      SelectedEntity(entities): entities
      SelectedTaxon(_): @[]
