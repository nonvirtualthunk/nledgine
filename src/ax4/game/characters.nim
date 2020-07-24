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

type
   Character* = object
      perks*: seq[Taxon]
      health*: Reduceable[int]


   Physical* = object
      position*: AxialVec
      offset*: CartVec

   Allegiance* = object
      faction*: Entity

   Faction* = object
      playerControlled*: bool
      color*: RGBA



defineReflection(Character)
defineReflection(Physical)
defineReflection(Allegiance)
defineReflection(Faction)
defineReflection(Monster)



proc faction*(view: WorldView, entity: Entity): Entity =
   view.data(entity, Allegiance).faction

proc factionData*(view: WorldView, entity: Entity): ref Faction =
   view.data(view.data(entity, Allegiance).faction, Faction)

proc isPlayerControlled*(view: WorldView, entity: Entity): bool =
   view.data(faction(view, entity), Faction).playerControlled

