import patty
import config
import worlds
import tables
import core
import hex
import graphics/color
import ax4/game/effect_types
import game/library
import config
import resources
import graphics/image_extras
import strutils
import noto
import ax4/game/targeting
import arxregex
import options
import ax4/game/ax_events


type
   MonsterEffect* = object
      effect*: GameEffect
      target*: TargetPreference

   MonsterAction* = object
      effects*: seq[MonsterEffect]
      conditions*: seq[GameCondition]
      weight*: float

   Monster* = object
      monsterClass*: Taxon
      lastAction*: string
      nextAction*: Option[string]

   MonsterClass* = object
      actions*: Table[string, MonsterAction]
      images*: seq[ImageLike]

   MonsterActionChosenEvent* = ref object of AxEvent
      action*: Option[string]

defineReflection(Monster)

method toString*(evt: MonsterActionChosenEvent): string =
   return &"MonsterActionChosen{$evt[]}"


# defineSimpleReadFromConfig(MonsterEffect)
proc readFromConfig*(cv: ConfigValue, m: var MonsterEffect) =
   readInto(cv["target"], m.target)
   readInto(cv["effect"], m.effect)

proc readFromConfig*(cv: ConfigValue, m: var MonsterAction) =
   readInto(cv["effects"], m.effects)
   readInto(cv["conditions"], m.conditions)
   readIntoOrElse(cv["weight"], m.weight, 1.0f)

defineSimpleReadFromConfig(MonsterClass)
defineSimpleLibrary[MonsterClass]("ax4/game/monsters.sml", "MonsterClasses")

when isMainModule:
   let lib = library(MonsterClass)

   let slime = lib["slime"]

   echo $slime

