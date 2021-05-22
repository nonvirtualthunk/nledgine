PlantKinds {
  OakTree {
    health : 50-60
    healthRecoveryTime: 1 day
    growthStages: {
      Seedling: 0
      Sapling: 1 season
      Mature: 1 year
    }
    lifespan: 5 years
    imagesByGrowthStage: {
      Seedling : "survival/graphics/plants/seedling.png"
      Sapling : "survival/graphics/plants/sapling.png"
      Mature : "survival/graphics/plants/tree.png"
    }
    resourcesByGrowthStage: {
      Sapling: [
        {
          resource: Twigs
          amountRange: 1
          gatherMethods: [
            {
              action: Cut
              difficulty: 0
            },
            {
              action: Gather
              difficulty: 4
            }
          ],
          regenerateTime: 1 day
        },
        {
          resource: Bark
          amountRange: 1
          gatherMethods: [
            {
              action: Cut
              difficulty: 2
            },
            {
              action: Gather
              difficulty: 4
            }
          ],
          regenerateTime: 2 day
        },
        {
          resource: Branch
          amountRange: 1
          gatherMethods: [
            {
              action: Cut
              difficulty: 2
            },
            {
              action: Gather
              difficulty: 4
            }
          ]
          destructive: true
        }
      ]
      Mature: [
        {
          resource: Twigs
          amountRange: 2-4
          gatherMethods: [
            {
              action: Cut
              difficulty: 0
            },
            {
              action: Gather
              difficulty: 4
            }
          ]
          regenerateTime: 1 day
        },
        {
          resource: Bark
          amountRange: 2-4
          gatherMethods: [
            {
              action: Cut
              difficulty: 2
            },
            {
              action: Gather
              difficulty: 4
            }
          ]
          regenerateTime: 2 day
        },
        {
          resource: Branch
          amountRange: 2-3
          gatherMethods: [
            {
              action: Cut
              difficulty: 2
            },
            {
              action: Gather
              difficulty: 6
            }
          ]
        },
        {
          resource: Log
          amountRange: 2-3
          gatherMethods: [
            {
              action: Cut
              difficulty: 4
              minimumToolLevel: 1
            },
          ]
          destructive: true
        }
      ]
    }
  }
}