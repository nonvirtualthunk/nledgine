import effect_types
import worlds

import reflect

type
   Card* = object
      effectGroups* : seq[EffectGroup]


defineReflection(Card)
