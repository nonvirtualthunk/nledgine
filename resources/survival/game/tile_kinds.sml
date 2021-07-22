TileKinds {

  RoughStone {
    moveCost : 5
    resources: [
      {
        resource: Items.Stone
        quantity: 2-3
        gatherMethod: Mine
        gatherTime: 2 long actions
      }
    ]
    looseResources {
      Stone: 6%
      SharpStone: 2%
    }

    images: ["survival/graphics/tiles/rough_stone.png"]
    wallImages: ["survival/graphics/tiles/rough_stone_wall.png"]
  }

  Dirt {
    moveCost : 0
    resources : [
      {
        resource: Worm
        quantity: 60% 1
        gatherMethods: [ [Dig, 1], [Gather, 3] ]
        gatherTime: 1 long action
        regenerateTime: 3 days
      }
      {
        resource: Items.Soil
        quantity: 3-5
        gatherMethods: [ [Dig, 1], [Gather, 3] ]
        gatherTime: 1 long action
        destructive: true
      },
    ]
    looseResources {
      Stone: 3%
    }

    images: ["survival/graphics/tiles/dirt.png"]
  }

  Grass {
    moveCost : 2
    resources : [
      {
        resource: Blades of Grass
        quantity: 2-3
        gatherMethods: [ [Actions.Cut,1], [Dig, 2], [Gather, 3] ]
        gatherTime: 1 short action
        destructive: true
        regenerateTime: 3 days
      }
    ]
    looseResources {
      Stone: 1%
    }

    images: ["survival/graphics/tiles/grass.png"]
  }

  Sand {
    moveCost: 4
    resources : [
      {
        resource: Items.Sand
        quantity: 4-5
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
        quantity: 10000
        gatherMethods: [ [Scoop, 1] ]
        gatherTime: 1 short action
      }
    ]

    images: ["survival/graphics/tiles/water.png"]
  }

  Void {
    moveCost: 1000

    images: [survival/icons/blank.png]
  }
}