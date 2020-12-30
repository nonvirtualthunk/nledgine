import worlds
import ax4/game/map
import hex
import options
import prelude
import perlin
import ax4/game/ax_events


proc createEmptyMap*(world: World, radius: int, defaultTerrain: Taxon): Entity =
   withWorld(world):
      var map = createMap(vec2i(50, 50), radius)
      for r in 0 ..< map.radius:
         for hex in hexRing(axialVec(0, 0), r):
            let tile = world.createEntity()
            tile.attachData(Tile(
               position: hex,
               terrain: defaultTerrain,
               vegetation: @[]
            ))
            map.setTileAt(hex, tile)

            if hex.asCartesian.y < map.entryPoint.asCartesian.y:
               map.entryPoint = hex

      result = world.createEntity()
      result.attachData(map)

proc createForestRoom*(world: World): Entity =
   withWorld(world):
      result = createEmptyMap(world, 8, taxon("terrains", "mist barrier"))
      let map = result[Map]

      let grass = taxon("vegetations", "grass")
      let forest = taxon("vegetations", "forest")

      let flatland = taxon("terrains", "flatland")
      let mountains = taxon("terrains", "mountains")
      let hills = taxon("terrains", "hills")

      let noise = newNoise()

      for r in 0 ..< map.radius-1:
         for hex in hexRing(axialVec(0, 0), r):
            let tile = map.utileAt(hex)

            let n = noise.pureSimplex(hex.asCartesian.x.float * 0.3, hex.asCartesian.y.float * 0.3)
            let openThreshold = 0.95-r.float/(map.radius.float-1.0)
            let grassN = noise.pureSimplex(hex.asCartesian.x.float * 0.4 + 119.35, hex.asCartesian.y.float * 0.4 - 1924.33)

            let intrusion = (noise.pureSimplex(hex.asCartesian.x.float * 0.3 + 221.4, hex.asCartesian.y.float * 0.3 - 333.03).abs * 2.0).int + 2

            if hex.asCartesian.x.abs <= 1 and hex.asCartesian.y.abs >= 3:
               tile.modify(Tile.terrain := flatland)
               tile.modify(Tile.vegetation := @[grass])
            elif r >= map.radius-intrusion:
               tile.modify(Tile.terrain := mountains)
               # tile.modify(Tile.vegetation := @[grass, forest])
            elif r >= map.radius-intrusion-1:
               tile.modify(Tile.terrain := hills)
               tile.modify(Tile.vegetation := @[grass, forest])
            elif n < openThreshold:
               tile.modify(Tile.terrain := flatland)
               if grassN < 0.7:
                  tile.modify(Tile.vegetation := @[grass])
            else:
               tile.modify(Tile.terrain := flatland)
               tile.modify(Tile.vegetation := @[grass, forest])




#  Ax4 main generation code
   #    let mapEnt = createEmptyMap(world, radius, flatland)
      #    var map = mapEnt[Map]
      #    for r in 0 ..< radius:
      #       for hex in hexRing(axialVec(0, 0), r):
      #          let tile = map.tileAt(hex).get

      #          let terrainKind =
      #             if r <= 7: flatland
      #             elif r <= 10: hills
      #             else: mountains

      #          var vegetation: seq[Taxon]

      #          let n = noise.pureSimplex(hex.asCartesian.x.float * 0.3, hex.asCartesian.y.float * 0.3)
      #          var terrainForestThreshold =
      #             if terrainKind == mountains: 0.7f
      #             elif terrainKind == hills: 0.6f
      #             else: 0.5f

      #          let grassy = hex.q > hex.r and r > 1
      #          if grassy:
      #             vegetation.add(grass)
      #          else:
      #             terrainForestThreshold += 0.175

      #          if n > terrainForestThreshold:
      #             vegetation.add(forest)

      #          tile.modify(Tile.terrain := terrainKind)
      #          tile.modify(Tile.vegetation := vegetation)
