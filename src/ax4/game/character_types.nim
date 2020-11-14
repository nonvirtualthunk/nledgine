import worlds
import tables
import core
import hex
import graphics/color
import graphics/image_extras
import math
import patty

variantp CharacterReward:
   CardReward(cards: Taxon)


type
   CharacterRewardChoice* = object
      options*: seq[CharacterReward]

   Character* = object
      perks*: seq[Taxon]
      health*: Reduceable[int]
      sightRange*: int
      dead*: bool
      # The idea here is that playing cards of a particular kind shifts the balance of where you gain xp, but they
      # don't give xp themselves.
      xpDistribution*: Table[Taxon, int]
      xp*: Table[Taxon, int]
      levels*: Table[Taxon, int]
      pendingRewards*: seq[CharacterRewardChoice]

   Physical* = object
      position*: AxialVec
      offset*: CartVec

   Combat* = object
      blockAmount*: int

   Allegiance* = object
      faction*: Entity

   Faction* = object
      playerControlled*: bool
      color*: RGBA


defineReflection(Character)
defineReflection(Physical)
defineReflection(Allegiance)
defineReflection(Faction)
defineReflection(Combat)
