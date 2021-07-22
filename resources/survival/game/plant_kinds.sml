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
        images: "survival/graphics/plants/tree.png"
        occupiesTile: true
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
}

