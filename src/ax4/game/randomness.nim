import config
import arxregex
import strutils
import noto
import rich_text
import random

type
   DicePool* = object
      dice: int
      pips: int

   DiceRoll* = object
      rolls*: seq[int]

   RandomizationStyle* {.pure.} = enum
      Random
      Median
      High
      Low

   Randomizer* = object
      rand: Rand
      style: RandomizationStyle

   RandomizationWorldData* = object
      style*: RandomizationStyle
      seedOffset*: int

defineReflection(RandomizationWorldData)

proc randomizer*(w: World): Randomizer =
   let rwd = w[RandomizationWorldData]
   result = Randomizer(
      rand: initRand(1 + w.currentTime.int*1337 + rwd.seedOffset * 31),
      style: rwd.style
   )
   discard result.rand.rand(0.0 .. 1.0)

proc randomizer*(w: WorldView): Randomizer =
   let rwd = w[RandomizationWorldData]
   result = Randomizer(
      rand: initRand(1 + w.currentTime.int*1337 + rwd.seedOffset * 31),
      style: rwd.style
   )
   discard result.rand.rand(0.0 .. 1.0)


# returns a value between 0 ..< 1.0 exclusive
proc nextFloat*(r: var Randomizer): float =
   case r.style:
   of RandomizationStyle.Random:
      min(r.rand.rand(1.0f), 0.99999999999999f)
   of RandomizationStyle.Median:
      0.5f
   of RandomizationStyle.High:
      0.9999f
   of RandomizationStyle.Low:
      0.0f

# returns a value between 0 .. max inclusive
proc nextFloat*(r: var Randomizer, max: float): float =
   case r.style:
   of RandomizationStyle.Random:
      r.rand.rand(0.0 .. max)
   of RandomizationStyle.Median:
      max * 0.5f
   of RandomizationStyle.High:
      max
   of RandomizationStyle.Low:
      0.0f

# returns a value between 0 ..< max exclusive
proc nextInt*(r: var Randomizer, max: int): int =
   case r.style:
   of RandomizationStyle.Random:
      r.rand.rand(0 ..< max)
   of RandomizationStyle.Median:
      max div 2
   of RandomizationStyle.High:
      max(max-1, 0)
   of RandomizationStyle.Low:
      0


proc dicePool*(d: int, p: int): DicePool = DicePool(dice: d, pips: p)

const diceRegex = "([0-9]+)d([0-9]+)".re

proc readFromConfig*(cv: ConfigValue, dp: var DicePool) =
   if cv.isStr:
      let str = cv.asStr
      matcher(str):
         extractMatches(diceRegex, diceStr, pipsStr):
            dp.dice = diceStr.parseInt
            dp.pips = pipsStr.parseInt
         warn &"unexpected string value for dice pool: {str}"
   else:
      warn &"unexpected config value for dice pool: {cv}"

proc asRichText*(dp: DicePool): RichText =
   richText(&"{dp.dice}d{dp.pips}")

proc pickFrom*[T](r: var Randomizer, s: seq[T]): (int, T) =
   let index = r.nextInt(s.len)
   (index, s[index])

proc roll*(dp: DicePool, r: var Randomizer): DiceRoll =
   for i in 0 ..< dp.dice:
      result.rolls.add(r.nextInt(dp.pips)+1)

proc total*(dr: DiceRoll): int =
   for roll in dr.rolls:
      result += roll

proc stdRoll*(r: var Randomizer): DiceRoll =
   dicePool(3, 6).roll(r)

proc minRoll*(d: DicePool): int = d.dice

proc maxRoll*(d: DicePool): int = d.dice * d.pips
