import patty
import worlds
import root_types
import hashes
import config
import strutils
import noto
import arxregex
import strutils

variantp SelectionShape:
   Hex
   Line(startDistance: int, length: int)

variantp SelectionRestriction:
   Enemy
   Friendly
   InRange(minRange: int, maxRange: int)
   EntityChoices(entities: seq[Entity])
   TaxonChoices(taxons: seq[Taxon])
   InCardLocation(cardLocation: CardLocation)
   WithinMoveRange(movePoints: int)

variantp SelectorKey:
   # Primary
   # Secondary
   Subject
   Object
   SubSelector(index: int, key: ref SelectorKey)

# conditions that must be met for something to occur or be allowed
# currently planned for use with monster AI, i.e. do one moveset when it can see an enemy, one moveset when it can't
variantp GameCondition:
   CanSee(inViewCondition: SelectionRestriction)
   Near(nearCondition: SelectionRestriction, withinDistance: int)

type TargetPreferenceKind* = enum
   Closest
   Furthest
   Weakest
   Strongest
   Random

type TargetPreference* = object
   kind*: TargetPreferenceKind
   filters*: seq[SelectionRestriction]

proc hash*(k: SelectorKey): Hash =
   var h: Hash = 0
   match k:
      # Primary: h = 0.hash
      # Secondary: h = 1.hash
      SubSelector(index, subKey):
         h = h !& index
         h = h !& hash(subKey[])
      Subject: h = 2.hash
      Object: h = 3.hash
   result = !$h

type
   Selector* = object
      restrictions*: seq[SelectionRestriction]
      case kind*: SelectionKind
      of SelectionKind.Self: discard
      of SelectionKind.Character:
         characterCount*: int
      of SelectionKind.Taxon:
         options*: seq[Taxon]
      of SelectionKind.Hex:
         hexCount*: int
      of SelectionKind.CharactersInShape, SelectionKind.HexesInShape:
         shape*: SelectionShape
      of SelectionKind.Card:
         cards*: seq[Entity]
      of SelectionKind.CardType:
         cardTypes*: seq[Taxon]
      of SelectionKind.Path:
         moveRange*: int
         desiredDistance*: int
         subjectSelector*: SelectorKey



proc `==`*(a, b: Selector): bool =
   if a.kind != b.kind:
      false
   else:
      case a.kind
      of SelectionKind.Self: true
      of SelectionKind.Character: a.characterCount == b.characterCount
      of SelectionKind.Taxon: a.options == b.options
      of SelectionKind.Hex: a.hexCount == b.hexCount
      of SelectionKind.CharactersInShape, SelectionKind.HexesInShape: a.shape == b.shape
      of SelectionKind.Card: a.cards == b.cards
      of SelectionKind.CardType: a.cardTypes == b.cardTypes
      of SelectionKind.Path: a.moveRange == b.moveRange and a.subjectSelector == b.subjectSelector




proc selfSelector*(): Selector =
   Selector(kind: SelectionKind.Self)

proc enemySelector*(count: int): Selector =
   Selector(kind: SelectionKind.Character, characterCount: count, restrictions: @[Enemy()])

proc friendlySelector*(count: int): Selector =
   Selector(kind: SelectionKind.Character, characterCount: count, restrictions: @[Friendly()])

proc charactersInShapeSelector*(shape: SelectionShape): Selector =
   Selector(kind: SelectionKind.CharactersInShape, shape: shape)

proc pathSelector*(maxMoveRange: int, subjectSelector: SelectorKey, desiredDistance: int): Selector =
   Selector(kind: SelectionKind.Path, moveRange: maxMoveRange, subjectSelector: subjectSelector)

proc inRange*(sel: var Selector, minRange: int, maxRange: int = 1000): var Selector =
   sel.restrictions.add(InRange(minRange, maxRange))
   sel





proc readFromConfig*(cv: ConfigValue, v: var TargetPreference) =
   if not cv.isStr:
      warn &"non string config value for target preference: {cv}"
      return
   let str = cv.asStr.toLowerAscii
   case str:
   of "closest": v = TargetPreference(kind: TargetPreferenceKind.Closest, filters: @[])
   of "closestenemy": v = TargetPreference(kind: TargetPreferenceKind.Closest, filters: @[Enemy()])
   of "weakest": v = TargetPreference(kind: TargetPreferenceKind.Weakest, filters: @[])
   of "weakestenemy": v = TargetPreference(kind: TargetPreferenceKind.Weakest, filters: @[Enemy()])
   of "strongest": v = TargetPreference(kind: TargetPreferenceKind.Strongest, filters: @[])
   of "strongestenemy": v = TargetPreference(kind: TargetPreferenceKind.Strongest, filters: @[Enemy()])
   of "furthest": v = TargetPreference(kind: TargetPreferenceKind.Furthest, filters: @[])
   of "furthestenemy": v = TargetPreference(kind: TargetPreferenceKind.Furthest, filters: @[Enemy()])
   of "random": v = TargetPreference(kind: TargetPreferenceKind.Random, filters: @[])
   of "randomenemy": v = TargetPreference(kind: TargetPreferenceKind.Random, filters: @[Enemy()])
   else: warn &"invalid target preference string: {str}"


const enemyRe = re"(?i)enemy"
const friendlyRe = re"(?i)friendly"
const inRangeRe = re"(?i)inRange\s?\((\d+),(\d+)\)"
const withinMoveRangeRe = re"(?i)withinMoveRange\s?\((\d+)\)"

proc readFromConfig*(cv: ConfigValue, v: var SelectionRestriction) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(enemyRe):
            v = Enemy()
         extractMatches(friendlyRe):
            v = Friendly()
         extractMatches(inRangeRe, minRange, maxRange):
            v = InRange(minRange.parseInt, maxRange.parseInt)
         extractMatches(withinMoveRangeRe, moveRange):
            v = WithinMoveRange(moveRange.parseInt)
         warn &"Unrecognized string represeentation of a selection restriction (not all implemented): {str}"
   else:
      warn &"Unrecognized config representation of a selection restriction: {cv}"

const canSeeRe = re"(?i)canSee\s?\((.+)\)"
const nearRe = re"(?i)near\s?\((.+)\s?,\s?(\d+)\)"

proc readFromConfig*(cv: ConfigValue, v: var GameCondition) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(canSeeRe, seeWhat):
            v = CanSee(readInto(asConf(seeWhat), SelectionRestriction))
         extractMatches(nearRe, nearWhat, dist):
            v = Near(readInto(asConf(nearWhat), SelectionRestriction), dist.parseInt)
         warn &"Unrecognized string represeentation of a game condition: {str}"
   else:
      warn &"Unrecognized config representation of a game condition: {cv}"
