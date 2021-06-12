import engines
import world
import tiles


type
  TileComponent* = ref object of GameComponent



proc computeTileFlags(tile: ref Tile, tileLib: Library[TileKind]) : int8 =
  0

proc initializeFlags(world: World) =
  eventStmts(TileFlagsUpdatedEvent()):
    for x in -RegionHalfSize ..< RegionHalfSize:
      for y in -RegionHalfSize ..< RegionHalfSize:
        for z in 0 ..< RegionLayers:
          discard




method initialize(g: TileComponent, world: World) =
  discard

method update(g: TileComponent, world: World) =
  discard

method onEvent(g: TileComponent, world: World, event: Event) =
  matcher(event):
    extract(RegionInitializedEvent):
      discard
    extract(TileChangedEvent, tilePosition):
      discard