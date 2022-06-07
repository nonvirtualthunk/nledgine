Creatures {
  Human {
    images: ["survival/graphics/creatures/player/down.png"]

    health {
      value: 24
      recoveryTime: 1 day
    }
    stamina {
      value: 14
      recoveryTime: 1 long action
    }
    hydration {
      value: 25
      lossTime: 15 per day
    }
    hunger {
      value: 35
      lossTime: 15 per day
    }
    sanity: 25

    visionRange: 20

    strength: 0
    dexterity: 0
    constitution: 0
    schedule: Diurnal
    weight: 5000

    occupiesTile: true

    canEat: [Flags.Vegetable, Flags.Root, Flags.Meat, Flags.Cooked, Flags.Water, Flags.Fruit]
    cannotEat: [Flags.Grass]

    baseMoveTime: 12 ticks

    innateActions {
      Gather: 1
    }

    innateAttacks {
      Punch: {
        damageType: Bludgeoning
        damageAmount: 2
        accuracy: 0.75
        duration: 1 short action
      }

      Kick: {
        damageType: Bludgeoning
        damageAmount: 3
        accuracy: 0.5
        duration: 1 short action
      }
    }
  }

  Rabbit {
    health {
      value: 4
      recoveryTime: 1 day
    }
    stamina {
      value: 10
      recoveryTime: 1 long action
    }
    hydration {
      value: 10
      lossTime: 5 per day
    }
    hunger {
      value: 12
      lossTime: 4 per day
    }
    sanity: 20

    strength: -2
    dexterity: 2
    constitution: -1
    baseMoveTime: 10 ticks
    schedule: Diurnal
    weight: 150

    occupiesTile: true

    visionRange: 8

    canEat: [Flags.Vegetable, Flags.Root, Flags.Water]
    cannotEat: [Flags.Meat, Flags.Cooked]

    images: ["survival/graphics/creatures/rabbit/rabbit.png"]
    actionImages {
      Move: "survival/graphics/creatures/rabbit/rabbit.png"
      Examine: "survival/graphics/creatures/rabbit/rabbit_examine.png"
    }

    priorities: {
      Eat: 6
      Flee: 30
      Defend: 2
      Explore: 3
      Examine: 4
      Home: 20
    }
    panicRange: 3

    innateActions {
      Gather: 1
      Dig: 1
    }
    innateAttacks {
      Bite {
        damageType: Bludgeoning
        damageAmount: 1
        accuracy: 0.5
        duration: 1 short action
      }
    }

    corpse: Items.RabbitCorpse
  }

  Spider {
    health {
      value: 6
    }
    corpse: Items.SpiderCorpse
    stamina {
      value: 10
      recoveryTime: 1 long action
    }
    hydration {
      value: 10
      lossTime: 5 per day
    }
    hunger {
      value: 12
      lossTime: 4 per day
    }
    sanity: 100

    strength: -1
    dexterity: 1
    constitution: -1
    baseMoveTime: 15 ticks
    schedule: Nocturnal
    weight: 300

    visionRange: 6

    canEat: [Flags.Meat, Flags.Water]
    cannotEat: [Flags.Vegetable, Flags.Cooked]

    images: ["survival/graphics/creatures/spider/spider.png"]
    actionImages {

    }

    priorities: {
      Eat: 6
      Defend: 15
      Attack: 8
      Explore: 3
      Examine: 4
      Home: 20
    }
    aggressionRange: 4

    innateActions {
      Gather: 1
    }
    innateAttacks {
      Bite {
        damageType: Piercing
        damageAmount: 2
        accuracy: 0.5
        duration: 1 short action
      }
    }
  }
}

Items {
  RabbitCorpse {
    description: "An ex-rabbit"
    weight: 400
    durability: 20
    transforms : [
      {
        recipeTemplate: Carve
        difficulty: 3
        outputs: [
          RawMeat
        ]
      }
    ]

    flags {
      Corpse: 1
    }

    image: "survival/graphics/creatures/rabbit/rabbit_dead.png"
    stackable: false
  }

  SpiderCorpse {
    description: "Still too many legs, less scuttling though"
    weight: 300
    durability: 15
    transforms: [{
      recipeTemplate: Carve
      difficulty: 2
      outputs: [ RawMeat, SpiderSilk ]
    }]

    flags {
      Corpse: 1
    }

    image: "survival/graphics/creatures/spider/spider_dead.png"
    stackable: false
  }
}