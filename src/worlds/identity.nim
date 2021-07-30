import reflect
import worlds
import options
import taxonomy
import strutils

type
  Identity* = object
    name*: Option[string]
    kind*: Taxon

defineReflection(Identity)

proc debugIdentifier*(world: LiveWorld, entity: Entity) : string =
  if entity.hasData(Identity):
    let ID = entity[Identity]
    if ID.name.isSome:
      ID.kind.displayName.replace(" ","") & ":" & ID.name.get & "(" & $entity.id & ")"
    else:
      ID.kind.displayName.replace(" ","") & "(" & $entity.id & ")"
  else:
    "Entity(" & $entity.id & ")"