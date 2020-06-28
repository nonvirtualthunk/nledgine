import resources
import graphics/image_extras
import worlds/taxonomy
import tables
import options
import game/library
import prelude


type
   TextureSet* = object
      primary*: ImageLike
      variants*: seq[ImageLike]
      variantChance*: float

   TilesetGraphicsInfo* = object
      replaces* : bool
      textures* : TextureSet

   VegetationGraphics* = object
      default*: TilesetGraphicsInfo
      byTerrainKind*: Table[Taxon, TilesetGraphicsInfo]

   TerrainGraphics* = object
      default*: TilesetGraphicsInfo

   MapGraphicsSettings* = object
      hexSize*: int
      baseScale* : int

defineSimpleReadFromConfig(MapGraphicsSettings)

proc mapGraphicsSettings*() : MapGraphicsSettings =
   config("ax4/graphics/map_graphics.sml").readInto(MapGraphicsSettings)

proc readFromConfig*(cv : ConfigValue, v : var TextureSet) =
   let basePath = cv["basePath"].asStr("")
   if cv.hasField("primary"):
      v.primary = imageLike(basePath & cv["primary"].asStr)
   if cv.hasField("variants"):
      v.variants = @[]
      for variantC in cv["variants"].asArr:
         v.variants.add(imageLike(basePath & variantC.asStr))
   cv["variantChance"].readInto(v.variantChance)

defineSimpleReadFromConfig(TilesetGraphicsInfo)

proc readFromConfig*(cv : ConfigValue, v : var VegetationGraphics) =
   for k,subConf in cv["graphics"]:
      let ginfo = subConf.readInto(TilesetGraphicsInfo)
      if k == "default":
         v.default = ginfo
      else:
         v.byTerrainKind[taxon("Terrains", k)] = ginfo

proc readFromConfig*(cv : ConfigValue, v : var TerrainGraphics) =
   cv["graphics"]["default"].readInto(v.default)


defineSimpleLibrary[VegetationGraphics]("ax4/game/vegetations.sml", "Vegetations")
defineSimpleLibrary[TerrainGraphics]("ax4/game/terrains.sml", "Terrains")

proc effectiveGraphicsInfoIntern(vg : VegetationGraphics, terrain : Taxon) : Option[TilesetGraphicsInfo] =
   if vg.byTerrainKind.contains(terrain):
      return some(vg.byTerrainKind[terrain])
   else:
      for parent in terrain.parents:
         let parentResult = effectiveGraphicsInfoIntern(vg, parent)
         if parentResult.isSome:
            return parentResult
      return none(TilesetGraphicsInfo)

proc effectiveGraphicsInfo*(vg : VegetationGraphics, terrain : Taxon) : TilesetGraphicsInfo =
   effectiveGraphicsInfoIntern(vg, terrain).get(vg.default)

proc pickBasedOn*(ts : TextureSet, i : int) : ImageLike =
   if ts.variants.isEmpty:
      ts.primary
   else:
      var variantChance = ts.variantChance
      if ts.primary.isEmpty:
         variantChance = 1.0

      let r = permute(i)
      if (r mod 1000) < (variantChance * 1000).int:
         ts.variants[permute(r) mod ts.variants.len]
      else:
         ts.primary
         
      