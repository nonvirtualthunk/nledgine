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
import options
import noto
import survival_core
import prelude

const GenerateIslandRegion* = false
const GenerateAbyssRegion* = true


proc generateRegion*(world: LiveWorld, regionEnt: Entity) =
  withWorld(world):
    let region = if regionEnt.hasData(Region):
      regionEnt.data(Region)
    else:
      world.attachData(regionEnt, Region)

    let noise = newNoise()
    var rand = randomizer(world)

    region.lengthOfDay = 12000.Ticks
    region.globalShadowLength = 16

    let tileLib = library(TileKind)

    let grass = tileLib.libTaxon(† TileKinds.Grass)
    let dirt = tileLib.libTaxon(† TileKinds.Dirt)
    let sand = tileLib.libTaxon(† TileKinds.Sand)
    let stone = tileLib.libTaxon(† TileKinds.RoughStone)
    let seawater = tileLib.libTaxon(† TileKinds.Seawater)
    let voidTile = tileLib.libTaxon(† TileKinds.Void)

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

        let (tileKind, wall) = if GenerateIslandRegion:
          # inner half should always be water, outer edge should always be under water
          # 1.5 - d * 2.0
          let ground = h < 1.75 - d * 2.0

          if not ground:
            (seawater, false)
          else:
            if h >= 1.65 - d * 2.0:
              (sand, false)
            elif h2 > d * 3.0:
              (stone, h2 > d * 3.0 + 0.25)
            elif h2 > 0.25:
              (grass, false)
            else:
              (dirt, false)
        elif GenerateAbyssRegion:
          const voidFract = 0.1

          # inner 10% is void, next ~10% is water, then land, last 20% is stone
          if d < voidFract:
            (voidTile, false)
          else:
            # renormalize to [0.0,1.0]
            let d = (d - voidFract) / (1.0 - voidFract)
            if h + d * 5.0 < 1.25:
              (seawater, false)
            elif h + d * 5.0 < 1.5:
              (sand, false)
            elif d + h * 0.25 > 0.9:
              (stone, d + h * 0.25 > 0.95)
            else:
              # here is the middle land
              if h2 > 0.85:
                (stone, h2 > 0.9)
              elif h2 > 0.25:
                (grass, false)
              else:
                (dirt, false)
        else:
          warn &"Must set region generation"
          (dirt, false)

        if tileKind != voidTile:
          let mainLayerInfo = tileLib[tileKind]
          var layerKinds = @[tileKind]
          while underLayers.contains(layerKinds[^1]):
            layerKinds.add(underLayers[layerKinds[^1]])

          layerKinds.reverse()

          var t = region.tilePtr(x,y,MainLayer)
          for layerKind in layerKinds:
            t.floorLayers.add(TileLayer(tileKind: layerKind, resources: createResourcesFromYields(world, tileLib[layerKind].resources, layerKind)))

          if wall:
            t.wallLayers.add(TileLayer(tileKind: tileKind))

          if tileKind == grass or tileKind == dirt:
            let forestNoise = noise.pureSimplex(x.float * 0.015f + 137.0f, y.float * 0.015f - 137.0f) * 0.5f +
                                noise.pureSimplex(x.float * 0.075f - 333.0f, y.float * 0.075f - 333.0f) * 0.5f -
                                (d * d)

            if forestNoise > 0.4f:
              createPlant(world, regionEnt, † Plants.OakTree, vec3i(x.int32,y.int32,MainLayer.int32))
            else:
              if rand.nextInt(100) == 0:
                createPlant(world, regionEnt, † Plants.Carrot, vec3i(x.int32, y.int32, MainLayer.int32))

          if t.wallLayers.isEmpty:
            for resource, dist in mainLayerInfo.looseResources:
              for i in 0 ..< dist.nextValue(rand):
                let item = createItem(world, regionEnt, resource)
                placeItem(world, none(Entity), item, vec3i(x.int32, y.int32, MainLayer.int32), true)







when isMainModule:
  import graphics/images
  import os
  import glm
  import game/library
  import graphics/images
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