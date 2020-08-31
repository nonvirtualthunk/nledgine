import patty
import worlds
import root_types
import hashes
import config
import strutils
import noto
import arxregex
import strutils
import sequtils
import rich_text
import graphics/image_extras
import prelude
import config/config_helpers

variantp SelectionShape:
   Hex
   Line(startDistance: int, length: int)

variantp SelectionRestriction:
   NoRestriction
   Self
   EffectSource
   Enemy
   Friendly
   InRange(minRange: int, maxRange: int)
   EntityChoices(entities: seq[Entity])
   TaxonChoices(taxons: seq[Taxon])
   InCardLocation(cardLocation: CardLocation)
   WithinMoveRange(movePoints: int)
   AllRestrictions(allRestrictions: seq[SelectionRestriction])

variantp SelectorKey:
   # Primary
   # Secondary
   Subject
   Object
   SubSelector(index: int, key: ref SelectorKey)

# conditions that must be met for something to occur or be allowed
# currently planned for use with monster AI, i.e. do one moveset when it can see an enemy, one moveset when it can't
# Also useful for conditional effects on cards, i.e. gain 1 stamina, if not at full health, gain 2 stamina
variantp GameCondition:
   AlwaysTrue
   CanSee(inViewCondition: SelectionRestriction)
   Near(nearCondition: SelectionRestriction, withinDistance: int)
   HasFlag(flag: Taxon, comparison: ComparisonKind, value: int)
   IsDamaged(truth: bool)

type TargetPreferenceKind* = enum
   Closest
   Furthest
   Weakest
   Strongest
   Random

type TargetPreference* = object
   kind*: TargetPreferenceKind
   filters*: SelectionRestriction

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
      restrictions*: SelectionRestriction
      case kind*: SelectionKind
      of SelectionKind.Character, SelectionKind.Taxon, SelectionKind.Hex, SelectionKind.Card, SelectionKind.CardType:
         count*: int
      of SelectionKind.CharactersInShape, SelectionKind.HexesInShape:
         shape*: SelectionShape
      of SelectionKind.Path:
         moveRange*: int
         desiredDistance*: int
         subjectSelector*: SelectorKey

proc `==`*(a, b: Selector): bool =
   if a.kind != b.kind or a.restrictions != b.restrictions:
      false
   else:
      case a.kind
      of SelectionKind.Character, SelectionKind.Taxon, SelectionKind.Hex, SelectionKind.Card, SelectionKind.CardType: a.count == b.count
      of SelectionKind.CharactersInShape, SelectionKind.HexesInShape: a.shape == b.shape
      of SelectionKind.Path: a.moveRange == b.moveRange and a.subjectSelector == b.subjectSelector


proc merge*(a, b: SelectionRestriction): SelectionRestriction {.gcsafe.}

proc `and`*(a, b: SelectionRestriction): SelectionRestriction {.gcsafe.} =
   merge(a, b)

proc add*(a: var SelectionRestriction, b: SelectionRestriction) =
   if a == NoRestriction():
      a = b
   elif b == NoRestriction():
      discard
   else:
      a = a and b



proc selfSelector*(): Selector =
   Selector(kind: SelectionKind.Character, count: 1, restrictions: Self())

proc enemySelector*(count: int, res: SelectionRestriction = NoRestriction()): Selector =
   Selector(kind: SelectionKind.Character, count: count, restrictions: Enemy() and res)

proc friendlySelector*(count: int): Selector =
   Selector(kind: SelectionKind.Character, count: count, restrictions: Friendly())

proc charactersInShapeSelector*(shape: SelectionShape): Selector =
   Selector(kind: SelectionKind.CharactersInShape, shape: shape)

proc pathSelector*(maxMoveRange: int, subjectSelector: SelectorKey, desiredDistance: int): Selector =
   Selector(kind: SelectionKind.Path, moveRange: maxMoveRange, subjectSelector: subjectSelector)

proc inRange*(sel: var Selector, minRange: int, maxRange: int = 1000): Selector =
   sel.restrictions.add(InRange(minRange, maxRange))
   sel

proc cardTypeSelector*(count: int, ofCardTypes: seq[Taxon]): Selector =
   Selector(kind: SelectionKind.CardType, count: count, restrictions: TaxonChoices(ofCardTypes))

proc selfCardSelector*(): Selector =
   Selector(kind: SelectionKind.Card, count: 1, restrictions: EffectSource())

proc withRestriction*(s: var Selector, sr: SelectionRestriction): Selector =
   s.restrictions.add(sr)
   s


proc readFromConfig*(cv: ConfigValue, s: var Selector) =
   if cv.isStr:
      let str = cv.asStr
      proc fromWordNumber(word: string, number: int, v: var Selector) =
         case word:
         of "self": v = selfSelector()
         of "enemy": v = enemySelector(number)
         of "friend", "friendly": v = friendlySelector(number)
         else: warn &"unsupported word/number based selector config: {word}, {number}"

      matcher(str):
         extractMatches(wordNumberPattern, word, number):
            fromWordNumber(word, number.parseInt, s)
         fromWordNumber(str, 1, s)
   else:
      warn &"unsupported selector configuration : {cv}"





proc readFromConfig*(cv: ConfigValue, v: var TargetPreference) =
   if not cv.isStr:
      warn &"non string config value for target preference: {cv}"
      return
   let str = cv.asStr.toLowerAscii
   case str:
   of "closest": v = TargetPreference(kind: TargetPreferenceKind.Closest, filters: NoRestriction())
   of "closestenemy": v = TargetPreference(kind: TargetPreferenceKind.Closest, filters: Enemy())
   of "weakest": v = TargetPreference(kind: TargetPreferenceKind.Weakest, filters: NoRestriction())
   of "weakestenemy": v = TargetPreference(kind: TargetPreferenceKind.Weakest, filters: Enemy())
   of "strongest": v = TargetPreference(kind: TargetPreferenceKind.Strongest, filters: NoRestriction())
   of "strongestenemy": v = TargetPreference(kind: TargetPreferenceKind.Strongest, filters: Enemy())
   of "furthest": v = TargetPreference(kind: TargetPreferenceKind.Furthest, filters: NoRestriction())
   of "furthestenemy": v = TargetPreference(kind: TargetPreferenceKind.Furthest, filters: Enemy())
   of "random": v = TargetPreference(kind: TargetPreferenceKind.Random, filters: NoRestriction())
   of "randomenemy": v = TargetPreference(kind: TargetPreferenceKind.Random, filters: Enemy())
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
   elif cv.isArr:
      var subRes: seq[SelectionRestriction]
      readInto(cv, subRes)
      v = AllRestrictions(subRes)
   else:
      warn &"Unrecognized config representation of a selection restriction: {cv}"

proc asSeq*(a: SelectionRestriction): seq[SelectionRestriction] =
   match a:
      AllRestrictions(res): res
      _: @[a]

proc merge*(a, b: SelectionRestriction): SelectionRestriction {.gcsafe.} =
   if a == NoRestriction():
      b
   elif b == NoRestriction():
      a
   else:
      var resSeq = a.asSeq
      resSeq.add(b.asSeq)
      AllRestrictions(resSeq)

const canSeeRe = re"(?i)canSee\s?\((.+)\)"
const nearRe = re"(?i)near\s?\((.+)\s?,\s?(\d+)\)"
const hasFlagRe = re"(?ix)hasFlag\((.+)\)"
const hasFlagValueRe = re"(?ix)hasFlagValue\((.+),([+-]?\d+)\)"
const noFlagValueRe = re"(?ix)noFlagValue\((.+)\)"
const isDamagedRe = re"(?ix)(?:is)?damaged"
const undamagedRe = re"undamaged"


proc readFromConfig*(cv: ConfigValue, v: var GameCondition) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(canSeeRe, seeWhat):
            v = CanSee(readInto(asConf(seeWhat), SelectionRestriction))
         extractMatches(nearRe, nearWhat, dist):
            v = Near(readInto(asConf(nearWhat), SelectionRestriction), dist.parseInt)
         extractMatches(hasFlagRe, flag):
            v = HasFlag(taxon("flags", flag), ComparisonKind.GreaterThan, 0)
         extractMatches(hasFlagValueRe, flag, value):
            v = HasFlag(taxon("flags", flag), ComparisonKind.GreaterThanOrEqualTo, value.parseInt)
         extractMatches(noFlagValueRe, flag):
            v = HasFlag(taxon("flags", flag), ComparisonKind.EqualTo, 0)
         extractMatches(isDamagedRe):
            v = IsDamaged(true)
         extractMatches(undamagedRe):
            v = IsDamaged(false)
         warn &"Unrecognized string represeentation of a game condition: {str}"
   else:
      warn &"Unrecognized config representation of a game condition: {cv}"

proc asRichText*(cond: GameCondition): RichText =
   match cond:
      AlwaysTrue: richText("true")
      HasFlag(flag, comparison, value):
         let (compWord, amountChange) = case comparison:
         of ComparisonKind.LessThan: ("less than", 0)
         of ComparisonKind.LessThanOrEqualTo: ("less than", 1)
         of ComparisonKind.GreaterThan: ("at least", 1)
         of ComparisonKind.GreaterThanOrEqualTo: ("at least", 0)
         of ComparisonKind.EqualTo: ("exactly", 0)
         of ComparisonKind.NotEqualTo: ("not exactly", 0)

         richText(&"has {compWord} {value + amountChange}") & richText(flag)
      IsDamaged(truth):
         if truth:
            richText("damaged")
         else:
            richText("undamaged")
      _: richText(&"unimplemented rich text for GameCondition {cond}")

proc asRichText*(s: SelectionShape): RichText =
   match s:
      Hex:
         result = richText(imageLike("ax4/images/ui/vertical_hex.png"))
      Line(startDist, length):
         for i in 1 ..< startDist + length:
            if i < startDist: result.add(richText(imageLike("ax4/images/ui/vertical_hex_dashed_outline.png")))
            else: result.add(richText(imageLike("ax4/images/ui/vertical_hex.png")))

proc containsSelfRestriction*(s: SelectionRestriction): bool =
   match s:
      Self: true
      AllRestrictions(subres): subres.anyIt(it.containsSelfRestriction())
      _: false
