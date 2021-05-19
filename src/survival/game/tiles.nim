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

const RegionSize = 256
const RegionHalfSize = 256 div 2
const RegionLayers = 3
const MainLayer = 1

type
  ResourceGatherMethod* = object
    # what action type triggers this gather method
    action*: Taxon
    # how difficult is it to successfully gather this way
    difficulty*: int
    # how good a tool is required to be able to gather at all
    minimumToolLevel*: int

  ResourceYield* = object
    # what resource is there
    resource*: Taxon
    # how much of it is present
    amountRange*: DiceExpression
    # how can it be gathered
    gatherMethods*: seq[ResourceGatherMethod]
    # is the tile destroyed when all resources are gathered
    destructive*: bool
    # how long it takes to regenerate 1 of this resource (in ticks)
    regenerateTime*: Option[Ticks]

  TileKind* = ref object
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
    resources*: seq[Taxon]

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
    # all tiles in the region
    tiles: FiniteGrid3D[RegionSize, RegionSize, RegionLayers, Entity]
    # flags for tiles (occupied, opaque, fluid impermeable, etc)
    tileFlags: FiniteGrid3D[RegionSize, RegionSize, RegionLayers, int8]

  RegionLayerView* = object
    region*: ref Region
    layer*: int
    view*: WorldView


const Occupied          = TileFlag(0b1000000) # an entity / wall is physically occupying this tile
const Opaque            = TileFlag(0b0100000) # an entity / wall is blocking light through this tile
const FluidImpermeable  = TileFlag(0b0010000) # an entity / wall is preventing water from flowing through this tile
const AirImpermeable    = TileFlag(0b0001000) # an entity / wall is preventing air from flowing through this tile

defineSimpleReadFromConfig(ResourceGatherMethod)
defineSimpleReadFromConfig(ResourceYield)

proc readFromConfig*(cv: ConfigValue, tk: var TileKind) =
  if tk == nil:
    tk = TileKind()
  cv["moveCost"].readInto(tk.moveCost)
  cv["resources"].readInto(tk.resources)
  cv["images"].readInto(tk.images)
  cv["wallImages"].readInto(tk.wallImages)

defineReflection(Tile)
defineReflection(Region)


defineSimpleLibrary[TileKind]("survival/game/tile_kinds.sml", "TileKinds")

proc layer*(r: Entity, view: WorldView, z: int): RegionLayerView = RegionLayerView(region: view.data(r, Region), layer: z, view: view)
proc tileEnt*(r: RegionLayerView, x: int, y: int): Entity = r.region.tiles[x + RegionHalfSize,y + RegionHalfSize,r.layer]
proc tile*(r: RegionLayerView, x: int, y: int): ref Tile = r.view.data(tileEnt(r,x,y), Tile)
proc setTile*(r: var Region, x,y,z: int, e: Entity) = r.tiles[x + RegionHalfSize, y + RegionHalfSize, z] = e


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

  method initialize(g: TestDrawComponent, world: World, curView: WorldView, display: DisplayWorld) =
    g.canvas = createSimpleCanvas("shaders/simple")
    
    let grassTaxon = taxon("TileKinds", "Grass")
    let dirtTaxon = taxon("TileKinds", "Dirt")
    let sandTaxon = taxon("TileKinds", "Sand")

    world.eventStmts(GameEvent()):
      world.attachData(RandomizationWorldData())

      g.regionEnt = world.createEntity()
      var region = Region()

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

          tileEnt.attachData(Tile(
            floorLayers: @[TileLayer(tileKind: kind)]
          ))
          region.setTile(x,y, MainLayer, tileEnt)
          
      g.regionEnt.attachData(region)


  method update(g: TestDrawComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
    var qb = QuadBuilder()
    
    let lib = library(TileKind)


    let rlayer = layer(g.regionEnt, world.view, MainLayer)
    for x in -20 .. 20:
      for y in -20 .. 20:
        let tent = tileEnt(rlayer, x, y)
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
     graphicsComponents: @[TestDrawComponent(), createCameraComponent(createPixelCamera(2))],
     clearColor: rgba(0.5f,0.5f,0.5f,1.0f)
  ))
