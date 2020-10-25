import ax4/game/targeting_types
import ax4/game/effect_types
import worlds

type
   CardReward* = object
      card*: Taxon

   CharacterClass* = object
      requirements*: seq[GameCondition]
      cardRewards*: seq[CardReward]

