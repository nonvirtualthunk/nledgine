import tables
import worlds
import effect_types
import root_types

type
   Deck* = object
      cards* : Table[CardLocation, seq[Entity]]

   Card* = object
      effectGroups* : seq[EffectGroup]
      



defineReflection(Deck)
defineReflection(Card)