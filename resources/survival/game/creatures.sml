
HumanoidEquipmentSlots : [Hat, Cloak, Shirt, Gloves, Pants, Shoes, Helmet, BodyArmor, Greaves, Crown, Necklace, Brooch, Ring, Belt]

HumanoidBodyParts {
  RightHand {
    size: 2
  }
  LeftHand {
    size: 2
  }
  RightFoot {
    size: 2
  }
  LeftFoot {
    size: 2
  }
  LeftArm {
    size: 6
  }
  RightArm {
    size: 6
  }
  RightLeg {
    size: 10
  }
  LeftLeg {
    size: 10
  }
  Torso {
    size: 15
  }
  Neck {
    size: 3
  }
  Head {
    size: 4
  }
}


Creatures {
  Human {
    images: ["survival/graphics/creatures/player/down.png"]

    health {
      value: 24
      recoveryTime: 1 day
    }
    stamina {
      value: 22
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
        bodyParts: [RightHand, LeftHand]
      }

      Kick: {
        damageType: Bludgeoning
        damageAmount: 3
        accuracy: 0.5
        duration: 1 short action
        bodyParts: [LeftFoot, RightFoot]
      }
    }

    bodyParts : ${HumanoidBodyParts}

    equipmentSlots : ${HumanoidEquipmentSlots}
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
        bodyParts: [BodyParts.Head]
      }
    }

    corpse: Items.RabbitCorpse

    bodyParts {
      RightForePaw {
        size: 2
      }
      LeftForePaw {
        size: 2
      }
      RightHindPaw {
        size: 2
      }
      LeftHindPaw {
        size: 2
      }
      LeftForeLeg {
        size: 6
      }
      RightForeLeg {
        size: 6
      }
      LeftHindLeg {
        size: 8
      }
      RightHindLeg {
        size: 8
      }
      Torso {
        size: 15
      }
      Neck {
        size: 3
      }
      Head {
        size: 4
      }
    }
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
        bodyParts: [BodyParts.Head]
      }
    }

    LeftInsectLeg1 {
      size: 2
    }
    LeftInsectLeg2 {
      size: 2
    }
    LeftInsectLeg3 {
      size: 2
    }
    LeftInsectLeg4 {
      size: 2
    }
    RightInsectLeg1 {
      size: 2
    }
    RightInsectLeg2 {
      size: 2
    }
    RightInsectLeg3 {
      size: 2
    }
    RightInsectLeg4 {
      size: 2
    }
    Thorax {
      size: 16
    }
    Head {
      size: 4
    }
  }
}


Corpse {
  drawFullWhenCapsuled: true
  flags {
    Corpse: 1
  }
  stackable: false
}

Items {
  RabbitCorpse: ${Corpse} {
    description: "An ex-rabbit"
    weight: 400
    durability: 20
    transforms : [
      {
        recipeTemplate: Carve
        difficulty: 3
        outputs: [ RawMeat ]
      }
    ]


    image: "survival/graphics/creatures/rabbit/rabbit_dead.png"
  }

  SpiderCorpse: ${Corpse} {
    description: "Still too many legs, less scuttling now"
    weight: 300
    durability: 15
    transforms: [{
      recipeTemplate: Carve
      difficulty: 2
      outputs: [ RawInsectMeat, SpiderSilk ]
    }]

    image: "survival/graphics/creatures/spider/spider_dead.png"
  }
}