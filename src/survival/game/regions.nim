import tiles
import entities
import perlin
import worlds
import math
import algorithm
import tables
import logic
import glm
import sets
import game/randomness
import game/library

proc generateRegion*(world: LiveWorld, regionEnt: Entity) =
  withWorld(world):
    let region = if regionEnt.hasData(Region):
      regionEnt.data(Region)
    else:
      world.attachData(regionEnt, Region)

    let noise = newNoise()
    var rand = randomizer(world)

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

    let tileLib = library(TileKind)

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

        var layerKinds = @[tileKind]
        while underLayers.contains(layerKinds[^1]):
          layerKinds.add(underLayers[layerKinds[^1]])

        layerKinds.reverse()

        var t = region.tilePtr(x,y,MainLayer)
        for layerKind in layerKinds:
          t.floorLayers.add(TileLayer(tileKind: layerKind, resources: createResourcesFromYields(world, tileLib[layerKind].resources, layerKind)))

        if tileKind == stone and h2 > d * 3.0 + 0.25:
          t.wallLayers.add(TileLayer(tileKind: stone))

        if tileKind == grass or tileKind == dirt:
          let forestNoise = noise.pureSimplex(x.float * 0.015f + 137.0f, y.float * 0.015f - 137.0f) * 0.5f +
                              noise.pureSimplex(x.float * 0.075f - 333.0f, y.float * 0.075f - 333.0f) * 0.5f -
                              (d * d)

          if forestNoise > 0.4f:
            createPlant(world, regionEnt, † Plants.OakTree, vec3i(x.int32,y.int32,MainLayer.int32))
          else:
            if rand.nextInt(100) == 0:
              createPlant(world, regionEnt, † Plants.Carrot, vec3i(x.int32, y.int32, MainLayer.int32))







when isMainModule:
  import graphics/images
  import os
  import glm
  import game/library
  import graphics/image_extras
  import prelude
  import graphics/color

  echo &"SIZE: {(sizeof(Region) + sizeof(TileLayer) * RegionSize*RegionSize*3) div (1024*1024)}"

  let world = createLiveWorld()
  withWorld(world):
    let regionEnt = world.createEntity()
    generateRegion(world, regionEnt)
    let region = regionEnt.data(Region)

    echo relTime(), " Generated, turning into image"

    let lib = library(TileKind)

    let imgOut = createImage(vec2i(RegionSize, RegionSize))

    let rlayer = regionEnt.layer(world, MainLayer)
    for x in -RegionHalfSize ..< RegionHalfSize:
      for y in -RegionHalfSize ..< RegionHalfSize:
        let tile = rlayer.tile(x,y)

        let tileInfo = lib[tile.floorLayers[^1].tileKind]
        let img = tileInfo.images[0].asImage

        if tile.entities.nonEmpty:
          imgOut[x + RegionHalfSize,y + RegionHalfSize] = rgba(0.05f,0.4f,0.15f,1.0f)
        else:
          imgOut[x + RegionHalfSize,y + RegionHalfSize] = img[0,0][]

    imgOut.writeToFile("/tmp/map.png")
    discard execShellCmd("open /tmp/map.png")