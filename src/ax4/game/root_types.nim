import patty
import worlds
import randomness
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

type DiceExpression* = object
   dice*: DicePool
   fixed*: int


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

proc roll*(d: DiceExpression, r: var Randomizer): int =
   d.dice.roll(r).total + d.fixed

const simpleDiceExprRegex = re"([0-9]+)d([0-9]+)\s?([+-][0-9]+)?"
const simpleFixedDiceExprRegex = re"([+-]?[0-9]+)"

proc readFromConfig*(cv: ConfigValue, d: var DiceExpression) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(simpleDiceExprRegex, dice, pips, bonusStr):
            d.dice = dicePool(dice.parseInt, pips.parseInt)
            if bonusStr != "":
               d.fixed = bonusStr.parseInt
         extractMatches(simpleFixedDiceExprRegex, bonusStr):
            d.fixed = bonusStr.parseInt
         warn &"Unexpected string format for dice expression: {str}"
   else:
      warn &"unexpected config for dice expression: {cv}"
