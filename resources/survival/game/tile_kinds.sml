TileKinds {

  RoughStone {
    moveCost : 5
    resources: [
      {
        resource: Items.Stone
        quantity: 2-3
        gatherMethod: Mine
        gatherTime: 2 long actions
        destructive: true
      }
    ]
    looseResources {
      Stone: 2%
      SharpStone: 0.5%
    }

    images: ["survival/graphics/tiles/rough_stone.png"]
    wallImages: ["survival/graphics/tiles/rough_stone_wall.png"]

    tileset {
      center: "survival/graphics/tiles/stone/center.png"
      upEdges: "survival/graphics/tiles/stone/up_edges.png"
      upCorners: "survival/graphics/tiles/stone/up_corners.png"
      ramp: ["#262b44", "#3a4446", "#5a6988", "#3a4446"]
      upRamp: ["#31784F", "#478F3C", "#6FA64C", "#85AD50"]
      layer: 3
      decor: [
        "survival/graphics/tiles/stone/decor_1.png",
        "survival/graphics/tiles/stone/decor_2.png",
        "survival/graphics/tiles/stone/decor_3.png",
        "survival/graphics/tiles/stone/decor_4.png"
      ]
    }
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
      Stone: 0.5%
    }

    images: ["survival/graphics/tiles/dirt.png"]

    tileset {
      center: "survival/graphics/tiles/dirt/center.png"
      downEdges: "survival/graphics/tiles/dirt/down_edges.png"
      ramp: ["#85523D", "#99623D", "#A17A43", "#a78049"]
      layer: 4
      decor: [
        "survival/graphics/tiles/dirt/decor_0.png",
        "survival/graphics/tiles/dirt/decor_1.png",
        "survival/graphics/tiles/dirt/decor_2.png",
        "survival/graphics/tiles/dirt/decor_3.png"
      ]
    }
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
      Stone: "0.2%"
    }

    images: ["survival/graphics/tiles/grass.png"]

    tileset {
      center: "survival/graphics/tiles/grass/center.png"
      downEdges: "survival/graphics/tiles/grass/down_edges.png"
      ramp: ["#31784F", "#478F3C", "#6FA64C", "#85AD50"]
      layer: 5
      decor: [
        "survival/graphics/tiles/grass/decor_0.png",
        "survival/graphics/tiles/grass/decor_1.png"
      ]
    }
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
    looseResources {
      Sand: "0.6%"
    }

    images: ["survival/graphics/tiles/sand.png"]

    tileset {
      center: "survival/graphics/tiles/sand/center.png"
      upEdges: "survival/graphics/tiles/sand/up_edges.png"
      upCorners: "survival/graphics/tiles/sand/up_corners.png"
      ramp: ["#a46d5b", "#daa07c", "#e8bf9b", "#daa07c"]
      upRamp: ["#31784F", "#478F3C", "#6FA64C", "#85AD50"]
      layer: 2
    }
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
    dropImages: ["survival/graphics/tiles/waterfall.png"]

    tileset {
      center: "survival/graphics/tiles/water/center.png"
      upEdges: "survival/graphics/tiles/water/up_edges.png"
      upCorners: "survival/graphics/tiles/water/up_corners.png"
      upRamp: ["#31784F", "#478F3C", "#6FA64C", "#85AD50"]
      layer: 1
      decor: ["survival/graphics/tiles/water/decor_0.png",
        "survival/graphics/tiles/water/decor_1.png"]
    }
  }

  Freshwater {
    moveCost: 10
    resources: [
      {
        resource: Items.FreshWater
        quantity: 10
        gatherMethods: [ [Scoop, 1] ]
        gatherTime: 1 short action
      }
    ]

    images: ["survival/graphics/tiles/water.png"]
    dropImages: ["survival/graphics/tiles/waterfall.png"]

    tileset {
      center: "survival/graphics/tiles/water/center.png"
      upEdges: "survival/graphics/tiles/water/up_edges.png"
      upCorners: "survival/graphics/tiles/water/up_corners.png"
      upRamp: ["#31784F", "#478F3C", "#6FA64C", "#85AD50"]
      layer: 1
      decor: ["survival/graphics/tiles/water/decor_0.png",
        "survival/graphics/tiles/water/decor_1.png"]
    }
  }

  # Self replenishing fresh water
  FreshwaterSource {
    moveCost: 10
    resources: [
      {
        resource: Items.FreshWater
        quantity: 10000
        gatherMethods: [ [Scoop, 1] ]
        gatherTime: 1 short action
      }
    ]

    images: ["survival/graphics/tiles/water.png"]
    dropImages: ["survival/graphics/tiles/waterfall.png"]

    tileset {
      center: "survival/graphics/tiles/water/center.png"
      upEdges: "survival/graphics/tiles/water/up_edges.png"
      downEdges: "survival/graphics/tiles/water/down_edges.png"
      upCorners: "survival/graphics/tiles/water/up_corners.png"
      upRamp: ["#31784F", "#478F3C", "#6FA64C", "#85AD50"]
      layer: 1
      decor: ["survival/graphics/tiles/water/decor_0.png",
        "survival/graphics/tiles/water/decor_1.png"]
    }
  }

  Void {
    moveCost: 1000

    images: [survival/graphics/tiles/void.png]

    tileset {
      center: "survival/graphics/tiles/void.png"
      layer: 0
    }
  }
}