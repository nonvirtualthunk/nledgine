import worlds
import tables
import core
import hex

type
   Character* = object
      perks* : seq[Taxon]

   Physical* = object
      position* : AxialVec
      offset* : CartVec


defineReflection(Character)
defineReflection(Physical)