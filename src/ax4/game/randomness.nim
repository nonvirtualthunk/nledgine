import config
import arxregex
import strutils
import noto

type
   DicePool* = object
      dice: int
      pips: int


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
