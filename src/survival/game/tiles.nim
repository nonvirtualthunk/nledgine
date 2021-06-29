import game/randomness
import game/grids
import worlds
import game/library
import options
import survival/game/survival_core
import graphics/image_extras
import config
import config/config_helpers
import resources
import sets
import glm
import entities
import core
import noto

const RegionSize* {.intdefine.} = 512
const RegionHalfSize* = RegionSize div 2
const RegionLayers* = 3
const MainLayer* = 1

type

  TileKind* = object
    # identity
    taxon*: Taxon
    # additional cost to move into this tile, expressed in ticks
    moveCost* : Ticks
    # resources that this tile may have
    resources* : seq[ResourceYield]
    # images to display the tile
    images*: seq[ImageLike]
    # images to display the tile as a wall
    wallImages*: seq[ImageLike]

  TileLayer* = object
    # what kind of tile layer is this
    tileKind*: Taxon
    # what resources are currently available
    resources*: seq[GatherableResource]

  Tile* = object
    # individual layers of the floor on this tile, in z-order
    floorLayers*: seq[TileLayer]
    # individual layers of the wall on this tile, in z-order
    wallLayers*: seq[TileLayer]
    # individual layers of the ceiling on this tile, in z-order
    ceilingLayers*: seq[TileLayer]
    # entities currently in or on this tile
    entities*: seq[Entity]

  TileFlag* = distinct int

  Region* = object
    # all entities in the region
    entities*: HashSet[Entity]
    # entities in the region that move of their own accord and may take actions
    dynamicEntities*: HashSet[Entity]
    # all tiles in the region
    tiles : FiniteGrid3D[RegionSize, RegionSize, RegionLayers, Tile]
    # flags for tiles (occupied, opaque, fluid impermeable, etc)
#    tileFlags: FiniteGrid3D[RegionSize, RegionSize, RegionLayers, int8]

  RegionLayerView* = object
    region*: ref Region
    layer*: int


const Occupied          = TileFlag(0b1000000) # an entity / wall is physically occupying this tile
const Opaque            = TileFlag(0b0100000) # an entity / wall is blocking light through this tile
const FluidImpermeable  = TileFlag(0b0010000) # an entity / wall is preventing water from flowing through this tile
const AirImpermeable    = TileFlag(0b0001000) # an entity / wall is preventing air from flowing through this tile



proc readFromConfig*(cv: ConfigValue, tk: var TileKind) =
  cv["moveCost"].readInto(tk.moveCost)
  cv["resources"].readInto(tk.resources)
  cv["images"].readInto(tk.images)
  cv["wallImages"].readInto(tk.wallImages)



defineReflection(Region)


defineSimpleLibrary[TileKind]("survival/game/tile_kinds.sml", "TileKinds")
proc tileKind*(t : Taxon): ref TileKind = library(TileKind)[t]

proc layer*(r: Entity, view: LiveWorld, z: int): RegionLayerView = RegionLayerView(region: view.data(r, Region), layer: z)
proc tile*(r: RegionLayerView, x: int, y: int): var Tile = r.region.tiles[x + RegionHalfSize,y + RegionHalfSize,r.layer]
proc tile*(r: ref Region, x: int, y: int, z : int): var Tile = r.tiles[x + RegionHalfSize,y + RegionHalfSize,z]
proc tilePtr*(r: ref Region, x: int, y: int, z : int): ptr Tile = r.tiles.getPtr(x + RegionHalfSize,y + RegionHalfSize,z)
proc tilePtr*(r: RegionLayerView, x: int, y: int): ptr Tile = r.region.tiles.getPtr(x + RegionHalfSize,y + RegionHalfSize,r.layer)
proc tilePtr*(r: ref Region, v: Vec3i): ptr Tile = tilePtr(r, v.x, v.y, v.z)
template tile*(r: Entity, x: int, y: int, z : int): var Tile =
  when declared(injectedWorld):
    tile(injectedWorld.data(r, Region), x,y,z)
  else:
    tile(world.data(r, Region), x,y,z)

template tile*(r: Entity, v: Vec3i): var Tile =
  when declared(injectedWorld):
    tile(injectedWorld.data(r, Region), v.x,v.y,v.z)
  else:
    tile(world.data(r, Region), v.x,v.y,v.z)

template tile*(t: Target): var Tile =
  case target.kind:
    of TargetKind.Tile, TargetKind.TileLayer:
      tile(world.data(t.region, Region), t.tilePos.x,t.tilePos.y,t.tilePos.z)
    of TargetKind.Entity:
      if t.entity.hasData(Physical):
        let phys = world.data(t.entity, Physical)
        let r = phys.region
        tile(world.data(r, Region), phys.position.x,phys.position.y,phys.position.z)
      else:
        err &"Attempting to extract tile from non-pyhsical entity target, returning sentinel"
        var r : Entity
        for region in world.entitiesWithData(Region):
          r = region
        tile(world.data(r, Region), 0,0,0)

proc layers*(t: var Tile, kind: TileLayerKind): var seq[TileLayer] =
  case kind:
    of TileLayerKind.Wall:
      return t.wallLayers
    of TileLayerKind.Floor:
      return t.floorLayers
    of TileLayerKind.Ceiling:
      return t.ceilingLayers


proc entitiesAt*(r: ref Region, v: Vec3i): seq[Entity] = tile(r, v.x, v.y, v.z).entities

proc regionFor*(world: LiveWorld, e: Entity): Entity =
  if e.hasData(Physical):
    return e[Physical].region
  else:
    err &"Attempting to determine region for non-physical entity {e}"

proc regionFor*(world: LiveWorld, t: Target): Entity =
  case t.kind:
    of TargetKind.Entity: regionFor(world, t.entity)
    of TargetKind.Tile, TargetKind.TileLayer: t.region

when isMainModule:


  import engines
  import prelude
  import graphics/cameras
  import graphics/camera_component
  import graphics/canvas
  import glm
  import graphics/color
  import main
  import application

  type
    TestDrawComponent = ref object of GraphicsComponent
      canvas: SimpleCanvas
      regionEnt: Entity
      drawn: bool

  method initialize(g: TestDrawComponent, world: LiveWorld, display: DisplayWorld) =
    g.canvas = createSimpleCanvas("shaders/simple")

    let grassTaxon = taxon("TileKinds", "Grass")
    let dirtTaxon = taxon("TileKinds", "Dirt")
    let sandTaxon = taxon("TileKinds", "Sand")

    world.eventStmts(GameEvent()):
      world.attachData(RandomizationWorldData())

      g.regionEnt = world.createEntity()
      let region = g.regionEnt.attachData(Region)

      var rand = randomizer(world)

      for x in -20 .. 20:
        for y in -20 .. 20:
          let tileEnt = world.createEntity()
          let kind = if x == -20 or x == 20 or y == -20 or y == 20:
            sandTaxon
          elif abs(x) >= 19 or abs(y) >= 19 or rand.nextInt(10) < 3:
            dirtTaxon
          else:
            grassTaxon

          region.tile(x,y, MainLayer).floorLayers = @[TileLayer(tileKind: kind)]


  method update(g: TestDrawComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
    var qb = QuadBuilder()

    let lib = library(TileKind)

    let rlayer = layer(g.regionEnt, world, MainLayer)
    for x in -20 .. 20:
      for y in -20 .. 20:
        let t = tile(rlayer, x, y)

        if t.floorLayers.nonEmpty:
          let tileInfo = lib[t.floorLayers[^1].tileKind]
          if not g.drawn:
            qb.dimensions = vec2f(24.0f,24.0f)
            qb.position = vec3f(x.float * 24.0f, y.float * 24.0f, 0.0f)
            qb.texture = tileInfo.images[0]
            qb.color = rgba(1.0f,1.0f,1.0f,1.0f)
            qb.drawTo(g.canvas)

    if not g.drawn:
      g.canvas.swap()
      g.drawn = true

    @[g.canvas.drawCommand(display)]


  main(GameSetup(
     windowSize: vec2i(1440, 1024),
     resizeable: false,
     windowTitle: "Tile Test",
     gameComponents: @[],
     liveGameComponents: @[],
     graphicsComponents: @[TestDrawComponent(), createCameraComponent(createPixelCamera(2))],
     clearColor: rgba(0.5f,0.5f,0.5f,1.0f),
     useLiveWorld: true
  ))
