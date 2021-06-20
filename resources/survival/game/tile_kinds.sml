TileKinds {

  RoughStone {
    moveCost : 5
    resources: [
      {
        resource: Items.Stone
        amountRange: 2-3
        gatherMethod: Mine
        gatherTime: 2 long actions
      }
    ]

    images: ["survival/graphics/tiles/rough_stone.png"]
    wallImages: ["survival/graphics/tiles/rough_stone_wall.png"]
  }

  Dirt {
    moveCost : 0
    resources : [
      {
        resource: Worm
        amountRange: 0-1
        gatherMethods: [ [Dig, 1], [Gather, 3] ]
        gatherTime: 1 long action
        regenerateTime: 3 days
      }
      {
        resource: Items.Soil
        amountRange: 3-5
        gatherMethods: [ [Dig, 1], [Gather, 3] ]
        gatherTime: 1 long action
        destructive: true
      },
    ]

    images: ["survival/graphics/tiles/dirt.png"]
  }

  Grass {
    moveCost : 2
    resources : [
      {
        resource: Blades of Grass
        amountRange: 2-3
        gatherMethods: [ [Actions.Cut,1], [Dig, 2], [Gather, 3] ]
        gatherTime: 1 short action
        destructive: true
        regenerateTime: 3 days
      }
    ]

    images: ["survival/graphics/tiles/grass.png"]
  }

  Sand {
    moveCost: 4
    resources : [
      {
        resource: Items.Sand
        amountRange: 4-5
        gatherMethods: [ [Dig, 1], [Gather, 2] ]
        gatherTime: 1 long action
        destructive: true
        regenerateTime: 10 days
      }
    ]

    images: ["survival/graphics/tiles/sand.png"]
  }

  Seawater {
    moveCost: 10
    resources: [
      {
        resource: Items.SaltWater
        amountRange: 10000
        gatherMethods: [ [Scoop, 1] ]
        gatherTime: 1 short action
      }
    ]

    images: ["survival/graphics/tiles/water.png"]
  }
}