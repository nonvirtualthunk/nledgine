import ax4/game/targeting_types
import ax4/game/effect_types
import worlds
import game/library
import options
import config
import config/config_helpers
import resources
import noto

type
   ClassCardReward* = object
      card*: Taxon

   CharacterClass* = object
      specializationOf*: Option[Taxon]
      requirements*: seq[GameCondition]
      cardRewards*: seq[ClassCardReward]


proc readFromConfig*(cv: ConfigValue, v: var CharacterClass) =
   cv["specializationOf"].readInto(v.specializationOf)
   for rc in cv["cardRewards"].asArr:
      if rc.isStr:
         v.cardRewards.add(ClassCardReward(card: taxon("CardTypes", rc.asStr)))
      else:
         warn &"Unknown config value for card reward: {rc}"

defineSimpleLibrary[CharacterClass]("ax4/game/classes.sml", "CharacterClasses")


when isMainModule:
   echo library(CharacterClass)[taxon("CharacterClasses", "Fighter")]
   echo library(CharacterClass)[taxon("CharacterClasses", "Barbarian")]
