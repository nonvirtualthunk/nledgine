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

   Randomizer* = object
      rand: Rand
      style: RandomizationStyle

   RandomizationWorldData* = object
      style: RandomizationStyle
      seedOffset: int

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

proc randInt*(r: var Randomizer, i: int): int =
   r.rand.rand(i)

proc roll*(dp: DicePool, r: var Randomizer): DiceRoll =
   for i in 0 ..< dp.dice:
      result.rolls.add(r.randInt(dp.pips-1)+1)

proc total*(dr: DiceRoll): int =
   for roll in dr.rolls:
      result += roll

proc stdRoll*(r: var Randomizer): DiceRoll =
   dicePool(3, 6).roll(r)

proc nextFloat*(r: var Randomizer): float =
   r.rand.rand(0.0 .. 1.0)

proc nextFloat*(r: var Randomizer, max: float): float =
   r.rand.rand(0.0 .. max)

proc nextInt*(r: var Randomizer, max: int): int =
   r.rand.rand(0 ..< max)

proc minRoll*(d: DicePool): int = d.dice

proc maxRoll*(d: DicePool): int = d.dice * d.pips
