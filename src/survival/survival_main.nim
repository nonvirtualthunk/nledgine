import main
import application
import glm
import engines
import worlds
import prelude
import tables
import noto
import graphics/camera_component
import resources
import graphics/texture_block
import graphics/images
import windowingsystem/windowingsystem_component
import windowingsystem/windowing_system_core
import game/library
import core
import worlds/gamedebug
import strutils
import graphics/cameras
import game/grids
import graphics/canvas
import engines/debug_components
import survival/game/regions
import graphics/up_to_date_animation_component
import survival/game/entities
import survival/game/events
import survival/game/tiles
import reflect
import sets
import survival/display/world_graphics
import survival/display/player_control
import survival/display/survival_debug
import survival/game/common_game_components
import survival/game/tile_component
import survival/game/vision
import survival/game/survival_core
import survival/game/logic
import survival/game/ai_component
import game/shadowcasting
import worlds/taxonomy
import graphics/color

type
  InitializationComponent = ref object of LiveGameComponent

  InitializationGraphicsComponent = ref object of GraphicsComponent


proc initializationComponent() : InitializationComponent =
  result = new InitializationComponent
  result.initializePriority = 10000

method initialize(g: InitializationComponent, world: LiveWorld) =
  g.name = "InitializationComponent"
  world.eventStmts(WorldInitializedEvent(time: relTime().inSeconds)):
    let regionEnt = world.createEntity()
    let region = regionEnt.attachData(Region)
    generateRegion(world, regionEnt)

    skipToTimeOfDay(world, regionEnt, DayNight.Day, 0.7)


    let water = † TileKinds.Seawater
    let voidTile = † TileKinds.Void

    var pos = vec3i(0,0,MainLayer)

    let countSlice = if GenerateIslandRegion:
      RegionHalfSize-1 .. 0
    else:
      0 .. RegionHalfSize - 1

    for y in upOrDownIter(countSlice):
      let tile = region.tile(0,y,MainLayer)
      if tile.floorLayers.len > 0 and tile.floorLayers[^1].tileKind != water and tile.floorLayers[^1].tileKind != voidTile and tile.wallLayers.isEmpty:
        pos = vec3i(0.int32,y.int32,MainLayer.int32)
        break

    let axe = createItem(world, regionEnt, † Items.StoneAxe)

    let player = createCreature(world, regionEnt, † Creatures.Human)
    player.attachData(Player(
      quickSlots: [player, axe, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity, SentinelEntity],
      vision: new ShadowGrid[64]
    ))
    equipItemTo(world, player, axe, † BodyParts.RightHand)
    player[Inventory].maximumWeight = 500
    player[Identity].name = some("Tobold")

    let fireDrill = createItem(world, regionEnt, † Items.FireDrill)

    moveEntityToInventory(world, axe, player)
    moveEntityToInventory(world, createItem(world, regionEnt, † Items.Log), player)
    moveEntityToInventory(world, createItem(world, regionEnt, † Items.CarrotRoot), player)
    moveEntityToInventory(world, createItem(world, regionEnt, † Items.WoodPole), player)
    moveEntityToInventory(world, createItem(world, regionEnt, † Items.StrippedBark), player)
    moveEntityToInventory(world, createItem(world, regionEnt, † Items.StrippedBark), player)
    moveEntityToInventory(world, createItem(world, regionEnt, † Items.Stone), player)
    moveEntityToInventory(world, createItem(world, regionEnt, † Items.LeatherPants), player)
    moveEntityToInventory(world, fireDrill, player)

    placeEntity(world, player, pos)

    # tilePtr(regionEnt[Region], player[Physical].position + vec3i(5,-5,0)).wallLayers = @[TileLayer(tileKind: library(TileKind).libTaxon(† TileKinds.RoughStone), resources : @[GatherableResource(resource: † Items.Stone, quantity: reduceable(3.int16), source: † TileKinds.RoughStone)])]

    # tilePtr(regionEnt[Region], vec3i(-7,-7,MainLayer)).wallLayers = @[TileLayer(tileKind: † TileKinds.RoughStone, resources : @[GatherableResource(resource: † Items.Stone, quantity: reduceable(3.int16), source: † TileKinds.RoughStone)])]
    player[Creature].stamina.value.reduceBy(10)
    player[Creature].sanity.value.reduceBy(10)

    let playerPos = player[Physical].position

    let fireLog = createItem(world, regionEnt, † Items.Log)
    placeEntity(world, fireLog, playerPos + vec3i(1,0,0), true)
    ignite(world, player, fireDrill, some(entityTarget(fireLog)))

    regionEnt[Region].entities.incl(player)

    regionEnt[Region].initialized = true
    world.addFullEvent(RegionInitializedEvent(region: regionEnt))

    let burrow = createItem(world, regionEnt, † Items.RabbitHole)
    for dy in 4 ..< 10:
      if passable(world, regionEnt, playerPos + vec3i(0,dy,0)):
        placeEntity(world, burrow, playerPos + vec3i(0,dy,0))
        break
    spawnCreatureFromBurrow(world, burrow)

    let spiderDen = createItem(world, regionEnt, † Items.SpiderDen)
    for dy in 4 ..< 10:
      if passable(world, regionEnt, playerPos + vec3i(-4,dy,0)):
        placeEntity(world, spiderDen, playerPos + vec3i(-4,dy,0))
        break
    spawnCreatureFromBurrow(world, spiderDen)

    createPlant(world, regionEnt, † Plants.Carrot, burrow[Physical].position + vec3i(3,0,0), PlantCreationParameters(growthStage: some(† GrowthStages.Flowering)))

    world[TimeData].initialized()


proc initializationGraphicsComponent() : InitializationGraphicsComponent =
  result = new InitializationGraphicsComponent
  result.initializePriority = 10000

method initialize(g: InitializationGraphicsComponent, display: DisplayWorld) =
  let cam = createPixelCamera(3).withMoveSpeed(0.0f).withEye(vec3f(0.0f,10000.0f,0.0f))
  display.attachData(CameraData(camera: cam))



main(GameSetup(
  windowSize: vec2i(1800, 1200),
  resizeable: false,
  windowTitle: "Survival",
  clearColor: rgba(0.0,0.0,0.0,1.0),
  liveGameComponents: @[
    BasicLiveWorldDebugComponent().ignoringEventType(WorldAdvancedEvent),
    initializationComponent(),
    CreatureComponent(),
    PhysicalComponent(),
    BurrowComponent(),
    FireComponent(),
    VisionComponent(),
    LightingComponent(),
    tileComponent(),
    AIComponent(),
  ],
  graphicsComponents: @[
    createWindowingSystemComponent("survival/widgets/"),
    WorldGraphicsComponent(),
    DynamicEntityGraphicsComponent(),
    PlayerControlComponent(),
    initializationGraphicsComponent(),
    SurvivalDebugComponent()
  ]
))

