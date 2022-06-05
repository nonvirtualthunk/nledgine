Items {

  RabbitHole {
    isA: Burrow
    burrow {
      creatureKind: Creatures.Rabbit
      maxPopulation: 2
      spawnInterval: 2 day
    }
    images: survival/graphics/buildings/burrow.png
    resources : [{
      resource: Items.Soil
      quantity: 1
      gatherMethods: [Dig]
      gatherTime: 2 long action
      destructive: true
    }]
  }

  SpiderDen {
    isA: Burrow
    burrow {
      creatureKind: Creatures.Spider
      maxPopulation: 3
      spawnInterval: 1 day
    }
    images: survival/graphics/buildings/spider_den.png
    occupiesTile: true
    health: 20-25
    healthRecoveryTime: 0.25 day
    resources: [{
      resource: Items.SpiderSilk
      quantity: 2-3
      gatherMethods: [Chop]
      gatherTime: 1 long action
      destructive: true
      regenerateTime: 1 day
    }]
  }
}