import worlds
import hex
import options
import glm
import game/library
import resources


type
   Tile* = object
      position* : AxialVec
      terrain* : Taxon
      vegetation* : seq[Taxon]

   Map* = object
      tileEntities* : seq[Entity]
      dimensions* : Vec2i
      center : AxialVec

   TerrainInfo* = object
      fertility*: int
      cover*: int
      elevation*: int
      moveCost*: int

   VegetationInfo* = object
      layer*: int
      cover*: int
      moveCost*: int

defineSimpleReadFromConfig(TerrainInfo)
defineSimpleReadFromConfig(VegetationInfo)
defineSimpleLibrary[TerrainInfo]("ax4/game/terrains.sml", "Terrains")
defineSimpleLibrary[VegetationInfo]("ax4/game/vegetations.sml", "Vegetations")

proc tileAt*(map : ref Map, q,r : int) : Option[Entity] =
   let index = (r + map.center.r) * map.dimensions.x + (q + map.center.q)
   if index >= 0 and map.tileEntities.len > index:
      let t = map.tileEntities[index]
      if not t.isSentinel:
         some(t)
      else:
         none(Entity)
   else:
      none(Entity)

proc tileAt*(map : ref Map, pos : AxialVec) : Option[Entity] =
   map.tileAt(pos.q,pos.r)

iterator tiles*(map : ref Map) : Entity =
   for t in map.tileEntities:
      if not t.isSentinel:
         yield t

proc setTileAt*(map : var Map, pos : AxialVec, tileEntity : Entity) =
   let index = (pos.r + map.center.r) * map.dimensions.x + (pos.q + map.center.q)
   map.tileEntities[index] = tileEntity

proc createMap*(dimensions : Vec2i) : Map =
   Map(
      dimensions : dimensions,
      center : axialVec(dimensions.x div 2, dimensions.y div 2),
      tileEntities : newSeq[Entity](dimensions.x * dimensions.y)
   )

defineReflection(Tile)
defineReflection(Map)
