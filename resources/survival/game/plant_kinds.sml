Plants {
  OakTree {
    health : 50-60
    healthRecoveryTime: 1 day
    growthStages: {
      Seedling: {
        startAge: 0
        images: "survival/graphics/plants/seedling.png"
      },
      Sapling {
        startAge: 1 season
        images: "survival/graphics/plants/sapling.png"
        resources: [
          {
            resource: Leaves
            quantity: 1
            gatherMethods: [ [Chop,1], [Actions.Cut,1], [Gather,2] ]
            gatherTime: 0.5 short action
            regenerateTime: 2 day
          },
          {
            resource: Twigs
            quantity: 1
            gatherMethods: [ [Chop,1], [Actions.Cut,1], [Gather,2] ]
            gatherTime: 0.5 short action
            regenerateTime: 2 day
          },
          {
            resource: Bark
            quantity: 1
            gatherMethods: [ [Chop,1], [Actions.Cut,2], [Gather,3] ]
            gatherTime: 2 short actions
            regenerateTime: 3 day
          },
          {
            resource: Branch
            quantity: 1
            gatherMethods: [ [Actions.Cut,2], [Chop,1], [Gather,4] ]
            gatherTime: 2 short actions
            destructive: true
          }
        ]
      },
      Mature: {
        startAge: 1 year
        images: "survival/graphics/plants/tree_2.png"
        occupiesTile: true
        blocksLight: true
        resources: [
          {
            resource: Leaves
            quantity: 2-4
            gatherMethods: [ [Actions.Cut,1], [Chop,1], [Gather,2] ]
            gatherTime: 0.5 short action
            regenerateTime: 2 day
          },
          {
            resource: Twigs
            quantity: 2-3
            gatherMethods: [ [Actions.Cut,1], [Chop,1], [Gather,2] ]
            gatherTime: 0.5 short action
            regenerateTime: 2 day
          },
          {
            resource: Bark
            quantity: 2-3
            gatherMethods: [ [Chop,1], [Actions.Cut,2], [Gather,3] ]
            gatherTime: 2 short actions
            regenerateTime: 4 day
          },
          {
            resource: Branch
            quantity: 1-2
            gatherMethods: [ [Chop,1], [Actions.Cut,2], [Gather,3] ]
            gatherTime: 1 long action
            regenerateTime: 10 day
          },
          {
            resource: Log
            quantity: 1-2
            gatherMethods: [ [Chop, 1] ]
            gatherTime: 2 long actions
            destructive: true
          }
        ]
      }
    }
    lifespan: 5 years
  }

  Carrot {
    health : 2-5
    healthRecoveryTime: 1 day
    growthStages: {
      Seedling: {
        startAge: 0
        images: "survival/graphics/plants/carrot/seedling.png"
      }
      VegetativeGrowth: {
        startAge: 5 day
        images: "survival/graphics/plants/carrot/vegetative.png"
        resources: [
          {
            resource: CarrotRoot
            quantity: 1
            gatherMethods: [ [Dig,1], [Gather,2] ]
            gatherTime: 1 short action
            destructive: true
          },
          {
            resource: Leaves
            quantity: 1
            gatheredOnDestruction: true
          },
        ]
      }
      Flowering: {
        startAge: 1 season
        images: "survival/graphics/plants/carrot/flowering.png"
        resources: [
          {
            resource: CarrotRoot
            quantity: 2
            gatherMethods: [ [Dig,1], [Gather,2] ]
            gatherTime: 1 short action
            destructive: true
          },
          {
            resource: Leaves
            quantity: 1
            gatheredOnDestruction: true
          },
          {
            resource: CarrotSeed
            quantity: 2-3
            gatheredOnDestruction: true
          },
        ]
      }
      Senescence: {
        startAge: 1.5 season
        images: "survival/graphics/plants/carrot/senescence.png"
        resources: [
          {
            resource: CarrotRoot
            quantity: 2
            gatherMethods: [ [Dig,1], [Gather,2] ]
            gatherTime: 1 short action
            destructive: true
          },
          {
            resource: Leaves
            quantity: 1
            gatheredOnDestruction: true
          },
        ]
      }
    }
    lifespan: 2 seasons
  }

  Fern {
    health : 1-3
    healthRecoveryTime: 1 day
    growthStages: {
      Sprout: {
        startAge: 0
        images: "survival/graphics/plants/fern/sprout.png"
        resources: [
          {
            resource: Fiddleheads
            quantity: 1
            gatherMethods: [ [Gather, 2], [Cut, 1] ]
            gatherTime: 1 short action
            destructive: true
          }
        ]
      }
      Mature: {
        startAge: 5 day
        images: "survival/graphics/plants/fern/mature.png"
        resources: [
          {
            resource: Leaves
            quantity: 1
            gatherMethods: [ [Cut,1], [Gather,2] ]
            gatherTime: 1 short action
            destructive: true
          }
        ]
      }
    }
    lifespan: 1 years
  }


  RedBerryBush {
    health : 2-5
    healthRecoveryTime: 1 day
    growthStages: {
      Seedling: {
        startAge: 0
        images: "survival/graphics/plants/berry_bush/bushling_3.png"
      }
      VegetativeGrowth: {
        startAge: 0.5 seasons
        images: "survival/graphics/plants/berry_bush/bush_3.png"
        resources: [
          {
            resource: Vines
            quantity: 1
            gatherMethods: [ [Cut,1], [Chop,1], [Gather,3] ]
            gatherTime: 1 short action
            destructive: true
          },
          {
            resource: Leaves
            quantity: 1
            gatheredOnDestruction: true
          },
        ]
      }
      Flowering: {
        startAge: 1 season
        images: "survival/graphics/plants/berry_bush/bush_3.png"
        resources: [
          {
            resource: RedBerries
            quantity: 2
            gatherMethods: [ [Gather,1] ]
            gatherTime: 1 short action
            regenerateTime: 3 days
            image: "survival/graphics/plants/berry_bush/bush_3_red_berries.png"
          },
          {
            resource: Vines
            quantity: 1
            destructive: true
            gatherMethods: [ [Cut, 1], [Chop, 1], [Gather,3] ]
          },
          {
            resource: Leaves
            quantity: 2
            gatheredOnDestruction: true
          },
        ]
      }
    }
    lifespan: 6 years
  }
}

