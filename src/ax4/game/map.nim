import worlds
import hex
import options
import glm


type
    Tile* = object
        position* : AxialVec
        terrainKind* : Taxon
        vegetationKind* : Taxon

    Map* = object
        tileEntities* : seq[Entity]
        dimensions* : Vec2i
        center : AxialVec

proc tileAt*(map : ref Map, q,r : int) : Option[Entity] =
    let index = (r + map.center.r) * map.dimensions.x + (q + map.center.q)
    if map.tileEntities.len > index:
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
