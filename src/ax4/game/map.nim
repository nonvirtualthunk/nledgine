import worlds
import hex
import options
import glm
import game/library
import resources
import ax4/game/character_types
import prelude
import noto


type
   Tile* = object
      position*: AxialVec
      terrain*: Taxon
      vegetation*: seq[Taxon]

   Maps* = object
      activeMap*: Entity

   Map* = object
      tileEntities*: seq[Entity]
      dimensions*: Vec2i
      radius*: int
      center: AxialVec
      entryPoint*: AxialVec

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

proc tileAt*(map: ref Map, q, r: int): Option[Entity] =
   let index = (r + map.center.r) * map.dimensions.x + (q + map.center.q)
   if index >= 0 and map.tileEntities.len > index:
      let t = map.tileEntities[index]
      if not t.isSentinel:
         some(t)
      else:
         none(Entity)
   else:
      none(Entity)

proc tileAt*(map: ref Map, pos: AxialVec): Option[Entity] =
   map.tileAt(pos.q, pos.r)

proc utileAt*(map: ref Map, pos: AxialVec): Entity = map.tileAt(pos.q, pos.r).get(SentinelEntity)
proc utileAt*(map: ref Map, q, r: int): Entity = map.tileAt(q, r).get(SentinelEntity)

iterator tiles*(map: ref Map): Entity =
   for t in map.tileEntities:
      if not t.isSentinel:
         yield t

proc setTileAt*(map: var Map, pos: AxialVec, tileEntity: Entity) =
   let index = (pos.r + map.center.r) * map.dimensions.x + (pos.q + map.center.q)
   map.tileEntities[index] = tileEntity

proc createMap*(dimensions: Vec2i, radius: int): Map =
   Map(
      dimensions: dimensions,
      radius: radius,
      center: axialVec(dimensions.x div 2, dimensions.y div 2),
      tileEntities: newSeq[Entity](dimensions.x * dimensions.y)
   )

defineReflection(Tile)
defineReflection(Map)
defineReflection(Maps)

type MapView* = object
   view: WorldView
   map*: ref Map
   terrainInfo: Library[TerrainInfo]
   vegetationInfo: Library[VegetationInfo]

proc activeMap*(view: WorldView): ref Map =
   withView(view):
      view[Maps].activeMap[Map]

proc mapView*(view: WorldView): MapView =
   withView(view):
      MapView(
         view: view,
         map: view.activeMap,
         terrainInfo: library(TerrainInfo),
         vegetationInfo: library(VegetationInfo)
      )

proc terrainInfoAt*(map: MapView, hex: AxialVec): Option[ref TerrainInfo] =
   withView(map.view):
      let tileOpt = map.map.tileAt(hex.q, hex.r)
      if tileOpt.isSome:
         let tile = tileOpt.get
         some(map.terrainInfo[tile[Tile].terrain])
      else:
         none(ref TerrainInfo)


iterator vegetationInfoAt*(map: MapView, hex: AxialVec): ref VegetationInfo =
   withView(map.view):
      let tileOpt = map.map.tileAt(hex.q, hex.r)
      if tileOpt.isSome:
         let tile = tileOpt.get
         for vegType in tile[Tile].vegetation:
            yield map.vegetationInfo[vegType]

proc elevationAt*(map: MapView, hex: AxialVec): int =
   let infoOpt = map.terrainInfoAt(hex)
   if infoOpt.isSome:
      infoOpt.get.elevation
   else:
      0

proc totalCoverAt*(map: MapView, hex: AxialVec): int =
   for terrainInfo in map.terrainInfoAt(hex):
      result += terrainInfo.cover
   for vegInfo in map.vegetationInfoAt(hex):
      result += vegInfo.cover


proc entityAt*(view: WorldView, hex: AxialVec): Option[Entity] =
   withView(view):
      let activeMap = view[Maps].activeMap
      for entity in view.entitiesWithData(Physical):
         let physical = entity[Physical]
         if physical.position == hex:
            if physical.map == activeMap:
               return some(entity)
      none(Entity)

iterator entitiesAt*(view: WorldView, hex: AxialVec): Entity =
   withView(view):
      let activeMap = view[Maps].activeMap
      for entity in view.entitiesWithData(Physical):
         let physical = entity[Physical]
         if physical.position == hex and physical.map == activeMap:
            yield entity
