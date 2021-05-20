import tiles
import entities
import perlin
import worlds
import math
import algorithm
import tables



proc generateRegion*(world: World) : Region =
  withWorld(world):
    let noise = newNoise()

    let grass = taxon("TileKinds", "Grass")
    let dirt = taxon("TileKinds", "Dirt")
    let sand = taxon("TileKinds", "Sand")
    let stone = taxon("TileKinds", "RoughStone")
    let seawater = taxon("TileKinds", "Seawater")

    let underLayers = {
      grass : dirt,
      dirt : stone,
      sand : seawater
    }.toTable()

    for x in -RegionHalfSize ..< RegionHalfSize:
      for y in -RegionHalfSize ..< RegionHalfSize:
        # [0.0,1.0]
        let h = noise.pureSimplex(x.float * 0.033f, y.float * 0.033f)
        let h2 = noise.pureSimplex((x.float + 1000.0).float * 0.057f, (y.float + 1000.0).float * 0.057f)

        # 0.0 at center, 1.0 at cardinal edge, sqrt(2) at corner
        let d = if x == 0 and y == 0: 0.0f else: sqrt((x*x+y*y).float) / RegionHalfSize

        # inner half should always be above water, outer edge should always be under water
        # 1.5 - d * 2.0
        let ground = h < 1.75 - d * 2.0

        let tileKind = if not ground:
          seawater
        else:
          if h >= 1.65 - d * 2.0:
            sand
          elif h2 > d * 3.0:
            stone
          elif h2 > 0.25:
            grass
          else:
            dirt

        let tileEnt = world.createEntity()
        var layerKinds = @[tileKind]
        while underLayers.contains(layerKinds[^1]):
          layerKinds.add(underLayers[layerKinds[^1]])

        layerKinds.reverse()

        var tileLayers : seq[TileLayer]
        for layerKind in layerKinds:
          tileLayers.add(TileLayer(tileKind: layerKind))

        tileEnt.attachData(Tile(
          floorLayers: tileLayers
        ))
        result.setTile(x,y,MainLayer, tileEnt)





when isMainModule:
  import graphics/images
  import os
  import glm
  import game/library
  import graphics/image_extras
  import prelude

  let world = createWorld()
  withWorld(world):
    let regionEnt = world.createEntity()
    regionEnt.attachData(generateRegion(world))
    echo relTime(), " Generated, turning into image"

    let region = world.view.data(regionEnt, Region)

    let lib = library(TileKind)

    let imgOut = createImage(vec2i(RegionSize, RegionSize))

    let rlayer = regionEnt.layer(world, MainLayer)
    for x in -RegionHalfSize ..< RegionHalfSize:
      for y in -RegionHalfSize ..< RegionHalfSize:
        let tile = rlayer.tile(x,y)

        let tileInfo = lib[tile.floorLayers[^1].tileKind]
        let img = tileInfo.images[0].asImage
        imgOut[x + RegionHalfSize,y + RegionHalfSize] = img[0,0][]

    imgOut.writeToFile("/tmp/map.png")
    discard execShellCmd("open /tmp/map.png")