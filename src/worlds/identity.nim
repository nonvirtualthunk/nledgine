import reflect
import worlds
import options
import taxonomy


type
  Identity* = object
    name*: Option[string]
    kind*: Taxon

defineReflection(Identity)