import config
import arxregex
import strutils
import noto
import rich_text
import random
import math

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

  DistributionKind* {.pure.} = enum
    Random
    Normal
    Constant

  Distribution*[T] = object
    # If set, consider this a conditional on fraction on whether to apply the distribution at all
    # i.e. 0.3 would be a 30% chance to resolve the distribution as normal, 70% chacne to resolve to 0
    chanceOf*: Option[float]
    case kind*: DistributionKind
    of DistributionKind.Random, DistributionKind.Normal:
      min*: T
      max*: T
    of DistributionKind.Constant:
      value*: T




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

proc constantDistribution*[T](t: T) : Distribution[T] =
  Distribution[T](kind: DistributionKind.Constant, value: t)

proc randomizer*(w: World): Randomizer =
  let rwd = w[RandomizationWorldData]
  result = Randomizer(
    rand: initRand(1 + w.currentTime.int*1337 + rwd.seedOffset * 31),
    style: rwd.style
  )
  discard result.rand.rand(0.0 .. 1.0)

proc randomizer*(w: World, style: RandomizationStyle): Randomizer =
  let rwd = w[RandomizationWorldData]
  result = Randomizer(
    rand: initRand(1 + w.currentTime.int*1337 + rwd.seedOffset * 31),
    style: style
  )
  discard result.rand.rand(0.0 .. 1.0)

proc randomizer*(w: LiveWorld, style: RandomizationStyle): Randomizer =
  let rwd = w[RandomizationWorldData]
  result = Randomizer(
    rand: initRand(1 + w.currentTime.int*1337 + rwd.seedOffset * 31),
    style: style
  )
  discard result.rand.rand(0.0 .. 1.0)


proc randomizer*(w: LiveWorld, extraOffset : int = 0): Randomizer =
  let rwd = w[RandomizationWorldData]
  result = Randomizer(
    rand: initRand(1 + w.currentTime.int*1337 + rwd.seedOffset * 31 + extraOffset),
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
    0.9999999f
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

proc nextFloat*(r: var Randomizer, min: float, max: float): float =
  min + nextFloat(r, max - min)

## Returns a value in the range [0 ..< 1) following a normal distribution
proc nextFloatNormalDistribution*(r : var Randomizer): float =
  case r.style:
    of RandomizationStyle.Random:
      let u1 = r.nextFloat
      let u2 = r.nextFloat
      let z1 = sqrt(-2.0 * ln(u1)) * cos(2.0 * PI * u2)
      clamp(z1/6.0+0.5, 0.0, 0.9999999999999999)
    of RandomizationStyle.Median:
      0.5f
    of RandomizationStyle.High:
      0.9999999999f
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

# returns a value between min ..< max exclusive
proc nextInt*(r: var Randomizer, min, max: int): int =
  min + nextInt(r, max - min)

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





const diceExpressionRegex = "([0-9]+d[0-9]+)?\\s?(x[0-9]+)?\\s?([+-]?[0-9]+)?".re
const rangeDiceExpressionRegex = "\\s*([0-9]+)\\s*\\-\\s*([0-9]+)".re

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

const normalRangeExpression = "(?i)normal\\s?([0-9]+)\\s*\\-\\s*([0-9]+)".re
const constantExpression = "\\s*([\\d.]+)".re
const chanceOfExpression = "\\s*([\\d.]+)%(.*)".re

proc readFromConfig*[T](cv: ConfigValue, d: var Distribution[T]) =
  if cv.isStr:
    let str = cv.asStr
    matcher(str):
      extractMatches(chanceOfExpression, chancePercent, remainder):
        let chance = some(chancePercent.parseFloat / 100.0f)
        if remainder.isEmpty:
          d = Distribution[T](chanceOf: chance, kind: DistributionKind.Constant, value: 1.T)
        else:
          readFromConfig(asConf(remainder), d)
          d.chanceOf = chance
      extractMatches(rangeDiceExpressionRegex, minStr, maxStr):
        let a = asConf(minStr).readInto(T)
        let b = asConf(maxStr).readInto(T)
        let minV = min(a,b)
        let maxV = max(a,b)

        when T is int:
          # Add one since 1-2 really is generally specifying as inclusive
          d = Distribution[T](kind: DistributionKind.Random, min: minV, max: maxV+1)
        elif T is float:
          # Don't alter here, since for floats that doesn't make sense in the same way
          d = Distribution[T](kind: DistributionKind.Random, min: minV, max: maxV)
        else:
          warn &"non [int,float] types not supported for distributions yet"
      extractMatches(normalRangeExpression, minStr, maxStr):
        let a = asConf(minStr).readInto(T)
        let b = asConf(maxStr).readInto(T)
        let minV = min(a,b)
        let maxV = max(a,b)

        when T is int:
          # Add one since 1-2 really is generally specifying as inclusive
          d = Distribution[T](kind: DistributionKind.Normal, min: minV, max: maxV+1)
        elif T is float:
          # Don't alter here, since for floats that doesn't make sense in the same way
          d = Distribution[T](kind: DistributionKind.Normal, min: minV, max: maxV)
        else:
          warn &"non [int,float] types not supported for distributions yet"
      extractMatches(constantExpression, vstr):
        d = Distribution[T](kind: DistributionKind.Constant, value: asConf(vstr).readInto(T))
      warn &"unexpected string value for distribution: {str}"
  elif cv.isNumber:
    d = Distribution[T](kind: DistributionKind.Constant, value: cv.asFloat.T)
  else:
    warn &"unexpected config value for distribution: {cv}"

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
  result.expression = de

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

proc nextValue*[T](d: Distribution[T], r: var Randomizer) : T =
  if d.chanceOf.isSome and (r.style != RandomizationStyle.High or d.chanceOf.get <= 0.0):
    if r.nextFloat > d.chanceOf.get or (r.style == RandomizationStyle.Low and d.chanceOf.get < 1.0):
      return 0.T
  case d.kind:
    of DistributionKind.Constant:
      d.value
    of DistributionKind.Random:
      when T is int:
        nextInt(r, d.min, d.max)
      elif T is float:
        nextFloat(r, d.min, d.max)
      else:
        {.error: ("nextValue(...) called with unsupported type " & $T).}
    of DistributionKind.Normal:
      let f = nextFloatNormalDistribution(r)
      d.min + ((d.max - d.min).float * f).T

proc maxValue*[T](d: Distribution[T]): T =
  if d.chanceOf.isSome and d.chanceOf.get <= 0.0:
    0.T
  else:
    case d.kind:
      of DistributionKind.Constant:
        d.value
      of DistributionKind.Random:
        when T is int:
          d.max - 1
        else:
          d.max
      of DistributionKind.Normal:
        d.max

proc minValue*[T](d: Distribution[T]): T =
  if d.chanceOf.isSome and d.chanceOf.get < 1.0:
    0.T
  else:
    case d.kind:
      of DistributionKind.Constant:
        d.value
      of DistributionKind.Random:
        d.min
      of DistributionKind.Normal:
        d.min

proc asRichText*[T](d: Distribution[T]): RichText =
  let prefix = if d.chanceOf.isSome:
    $(d.chanceOf.get * 100.0).int & "% "
  else:
    ""

  case d.kind:
    of DistributionKind.Constant:
      if d.value == 1.T and prefix.nonEmpty:
        richText(prefix[0 ..< ^1])
      else:
        richText(prefix & $d.value)
    of DistributionKind.Random:
      richText(prefix & $d.min & " - " & $d.maxValue)
    of DistributionKind.Normal:
      richText(prefix & $d.min & " - " & $d.maxValue & " normal distribution")

proc displayString*[T](d: Distribution[T]): string =
  let prefix = if d.chanceOf.isSome:
    $(d.chanceOf.get * 100.0).int & "% "
  else:
    ""

  case d.kind:
    of DistributionKind.Constant:
      if d.value == 1.T and prefix.nonEmpty:
        prefix[0 ..< ^1]
      else:
        prefix & $d.value
    of DistributionKind.Random:
      prefix & $d.min & " - " & $d.maxValue
    of DistributionKind.Normal:
      prefix & $(((d.min + d.maxValue).float / 2.0).T) & " +-" & $(((d.maxValue - d.min).float / 6.0).T)

when isMainModule:
  echo readInto(asConf("normal 1-2"), Distribution[int])
  echo readInto(asConf("normal 1-2"), Distribution[float])

  echo readInto(asConf("30%"), Distribution[int])
  echo readInto(asConf("30%"), Distribution[float])

  echo readInto(asConf("30% 2-3"), Distribution[int])
  echo readInto(asConf("30% 2-3"), Distribution[float])

  let norm = readInto(asConf("normal 0-10"), Distribution[int])
  let w = createWorld()
  w.attachData(RandomizationWorldData())
  var r = randomizer(w)

  var buckets : seq[int]
  for i in 0 ..< 10:
    buckets.add(0)

  for i in 0 ..< 5000:
    buckets[norm.nextValue(r)].inc

  for i in 0 ..< 10:
    for j in 0 ..< buckets[i] div 20:
      write(stdout, '*')
    echo ""
