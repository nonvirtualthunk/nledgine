TileKinds {

  RoughStone {
    moveCost : 5
    resources: [
      {
        resource: Items.Stone
        amountRange: 2-3
        gatherMethods: [
          {
            action: Mine
            difficulty: 5
            minimumToolLevel: 1
          }
        ]
      }
    ]

    images: ["survival/graphics/tiles/rough_stone.png"]
    wallImages: ["survival/graphics/tiles/rough_stone_wall.png"]
  }

  Dirt {
    moveCost : 0
    resources : [
      {
        resource: Soil
        amountRange: 3-5
        gatherMethods: [
          {
            action: Dig
            difficulty: 3
          }
        ],
        destructive: true
      },
      {
        resource: Worm
        amountRange: 0-1
        gatherMethods: [
          {
            action: Dig
            difficulty: 4
          }
        ]
        regenerateTime: 3 days
      }
    ]

    images: ["survival/graphics/tiles/dirt.png"]
  }

  Grass {
    moveCost : 2
    resources : [
      {
        resource: Blades of Grass
        amountRange: 2-3
        gatherMethods: [
          {
            action: Dig
            difficulty: 3
          }
          {
            action: Cut
            difficulty: 1
          }
          {
            action: Gather
            difficulty: 6
          }
        ]
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
        gatherMethods: [
          {
            action: Dig
            difficulty: 1
          }
          {
            action: Gather
            difficulty: 2
          }
        ]
        destructive: true
        regenerateTime: 10 days
      }
    ]

    images: ["survival/graphics/tiles/sand.png"]
  }
}