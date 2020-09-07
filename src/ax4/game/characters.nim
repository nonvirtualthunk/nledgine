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
import ax4/game/ax_events
import ax4/game/resource_pools
import ax4/game/flags

type
   Character* = object
      perks*: seq[Taxon]
      health*: Reduceable[int]
      sightRange*: int

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



proc faction*(view: WorldView, entity: Entity): Entity =
   view.data(entity, Allegiance).faction

proc factionData*(view: WorldView, entity: Entity): ref Faction =
   view.data(view.data(entity, Allegiance).faction, Faction)

proc isPlayerControlled*(view: WorldView, entity: Entity): bool =
   view.data(faction(view, entity), Faction).playerControlled

proc areEnemies*(view: WorldView, a, b: Entity): bool =
   faction(view, a) != faction(view, b)

proc areFriends*(view: WorldView, a, b: Entity): bool =
   not areEnemies(view, a, b)

iterator entitiesInFaction*(view: WorldView, faction: Entity): Entity =
   for ent in view.entitiesWithData(Allegiance):
      if view.data(ent, Allegiance).faction == faction:
         yield ent

iterator playerFactions*(view: WorldView): Entity =
   withView(view):
      for ent in view.entitiesWithData(Faction):
         if ent[Faction].playerControlled:
            yield ent
