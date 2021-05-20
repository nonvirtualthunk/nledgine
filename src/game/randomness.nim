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

  DiceExpression* = object
    dicePools*: seq[DicePool]
    bonus*: int
    # multiplier relative to 1.0 so that the default value has appropriate behavior (no change)
    multiplier_rel_1: float

  DiceExpressionRoll* = object
    expression*: DiceExpression
    rolls*: seq[DiceRoll]

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


proc `$`*(dp: DicePool): string =
  &"{dp.dice}d{dp.pips}"


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




const diceExpressionRegex = "([0-9]+d[0-9]+)?\\s?(x[0-9]+)?\\s?(\\[+-]?[0-9]+)?".re
const rangeDiceExpressionRegex = "([0-9]+)\\s*\\-\\s*([0-9]+)".re

proc multiplier*(d : DiceExpression): float = d.multiplier_rel_1 + 1.0f
proc `multiplier=`*(d: var DiceExpression, f : float) = d.multiplier_rel_1 = f - 1.0f

proc readFromConfig*(cv: ConfigValue, dp: var DiceExpression) =
  if cv.isStr:
    let str = cv.asStr
    matcher(str):
      extractMatches(diceExpressionRegex, dicePoolStr, mulStr, bonusStr):
        if dicePoolStr != "":
          dp.dicePools = @[asConf(dicePoolStr).readInto(DicePool)]
        if bonusStr != "":
          dp.bonus = bonusStr.parseInt
        if mulStr != "":
          dp.multiplier = mulStr.parseFloat
        else:
          dp.multiplier = 1.0
      extractMatches(rangeDiceExpressionRegex, minStr, maxStr):
        let a = minStr.parseInt
        let b = maxStr.parseInt
        let minV = min(a,b)
        let maxV = max(a,b)

        dp = DiceExpression(dicePools: @[DicePool(dice: 1, pips: maxV - minV + 1)], bonus: minV - 1)
      warn &"unexpected string value for dice expression: {str}"
  elif cv.isNumber:
    dp = DiceExpression(bonus: cv.asFloat.int)
  else:
    warn &"unexpected config value for dice expression: {cv}"

proc `$`*(de: DiceExpression): string =
  for dp in de.dicePools:
    if result.len > 0:
      result.add("+")
    result.add($dp)

  if de.multiplier != 1.0:
    if result.len > 0: # don't add a multipler if there's nothing to multiply
      result.add(&"x{de.multiplier}")

  if de.bonus != 0:
    if result.len > 0:
      result.add(de.bonus.toSignedString)
    else:
      result.add($de.bonus)

  if result.len == 0:
    result = "0"

proc asRichText*(de: DiceExpression): RichText =
  for dp in de.dicePools:
    if not result.isEmpty:
      result.add(richText("+"))
    result.add(dp.asRichText())

  if de.multiplier != 1.0:
    if not result.isEmpty: # don't add a multipler if there's nothing to multiply
      result.add(richText(&"x{de.multiplier}"))

  if de.bonus != 0:
    if not result.isEmpty:
      result.add(richText(de.bonus.toSignedString))
    else:
      result.add(richText($de.bonus))

  if result.isEmpty:
    result = richText("0")

proc roll*(de: DiceExpression, r: var Randomizer): DiceExpressionRoll =
  for dp in de.dicePools:
    for i in 0 ..< dp.dice:
      result.rolls.add(dp.roll(r))

proc total*(dr: DiceExpressionRoll): int =
  for roll in dr.rolls:
    result += roll.total
  if dr.expression.multiplier != 1.0f:
    result = (result.float * dr.expression.multiplier).int
  result += dr.expression.bonus

proc rollInt*(de: DiceExpression, r: var Randomizer): int =
  roll(de, r).total

proc minRoll*(de: DiceExpression): int =
  for dp in de.dicePools:
    result += dp.minRoll
  if de.multiplier != 1.0f:
    result = (result.float * de.multiplier).int
  result += de.bonus

proc maxRoll*(de: DiceExpression): int =
  for dp in de.dicePools:
    result += dp.maxRoll
  if de.multiplier != 1.0f:
    result = (result.float * de.multiplier).int
  result += de.bonus