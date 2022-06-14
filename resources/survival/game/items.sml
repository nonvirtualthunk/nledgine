Items {
  BladesOfGrass {
    durability: 2
    stackable: true

    flags {
      Grass: 1
    }

    image: "survival/graphics/items/plants/blades_of_grass.png"
  }
  Stone {
    durability: 30
    flags {
      Stone: 1
      Hard: 3
      Sturdy: 3
      Material: 1
    }
    stackable: true

    image: "survival/graphics/items/material/stone.png"
  }

  StoneShards {
    durability: 5
    flags {
      Stone: 1
      Hard: 1
      Debris: 1
    }
    stackable: true

    image: "survival/graphics/items/material/stone_shards.png"
  }

  SharpStone {
    durability: 15
    flags {
      Stone: 1
      Hard: 3
      Sturdy: 3
      Material: 1
    }
    stackable: true

    actions {
      Cut: 1
    }

    image: "survival/graphics/items/tool/sharp_stone.png"

    recipe {
      name: "sharpen stone"
      recipeTemplate: Carve
      ingredients.Ingredient: Items.Stone
    }
  }

  Soil {
    durability: 30
    flags {
      Soil: 2
    }
    stackable: true

    image: "survival/graphics/items/material/soil.png"
  }
  Worm {
    durability: 7
    flags {
      Bait: 3
    }
    stackable: true

    image: "survival/graphics/items/animal/worm.png"
  }
  Sand {
    durability: 30
    flags {
      Powder: 1
    }
    stackable: true

    image: "survival/graphics/items/material/sand.png"
  }

  Twigs {
    durability: 10
    weight: 20-30
    fuel: 225
    flags {
      Tinder: 1
      Compostable: 1
    }

    image: "survival/graphics/items/plants/twigs.png"
    stackable: true
  }

  WoodPieces {
    durability: 10
    weight: 20-30
    fuel: 225
    flags {
      Tinder: 1
      Debris: 1
      Compostable: 1
    }

    image: "survival/graphics/items/material/wood_pieces.png"
    stackable: true
  }

  Bark {
    description: "The tough outer material of a tree"
    weight: 40-60
    fuel: 300
    durability: 12

    flags {
      Compostable: 1
    }

    image: "survival/graphics/items/plants/bark.png"
    stackable: true
  }

  Tannin {
    description: "Astringent chemical used in tanning leather and ink"
    weight: 30-40
    durability: 10
    flags {
      Tannin: 1
    }
    stackable: true
  }

  StrippedBark {
    description: "Thin strips of bark"
    weight: 20-30
    durability: 8
    fuel: 100
    flags {
      Cordage : 1
      Tinder: 2
    }

    image: "survival/graphics/items/plants/stripped_bark.png"
    stackable: true

    recipe {
      name: "strip bark"
      recipeTemplate: Carve
      ingredients.Ingredient: Items.Bark
      amount: 2
    }
  }

  SpiderSilk {
    description: "The webbing of a giant spider"
    weight: 5-10
    durability: 12
    flags {
      Cordage: 1
      AnimalProduct: 1
    }

    image: "survival/graphics/items/animal/spider_silk.png"
    stackable: true

  }

  Branch {
    description: "A branch of a tree, separated by force or chance"
    weight: 400-500
    fuel: 800
    durability: 20
    image: "survival/graphics/items/plants/branch.png"

    flags {
      Sturdy: 1
      Wood: 1
      Inflammable: 2
    }
    stackable: true
  }

  Log {
    description: "A section of the trunk of a tree"
    weight: 2000-2500
    fuel: 4000
    durability: 30

    flags {
      Wood: 1
      Sturdy: 1
      Inflammable: 1
    }

    image: "survival/graphics/items/plants/log.png"
    stackable: true
  }

  Plank {
    description: "A piece of wood cut into a more readily usable shape"
    weight: 700-800
    fuel: 1200
    durability: "+2"

    flags {
      Wood: 1
      Flat: 1
      Sturdy: 1
      Inflammable: 2
    }

    image: "survival/graphics/items/plants/plank.png"
    stackable: true
  }

  WoodPole {
    description: "A sturdy wooden pole useful for construction and toolmaking"
    weight: 300-400
    fuel: 550
    durability: "+2"

    flags {
      Wood: 1
      Pole: 2
      Sturdy: 1
      Inflammable: 2
    }

    image: "survival/graphics/items/material/wood_pole.png"
    stackable: true
  }


  Dowels {
    description: "Small cylindrical pieces of wood used to join pieces of wood or make simple hinges"
    weight: 50-75
    fuel: 200
    durability: 10
    flags {
      Wood: 1
      Fine: 1
      Tinder: 1
    }

    image: "survival/graphics/items/material/dowels.png"
    stackable: true

    recipe {
      name: "carve wooden dowels"
      recipeTemplate: Carve
      ingredients {
        Ingredient : Items.WoodPole
      }
    }
  }

  WoodStake {
    weight: 200-300
    fuel: 250
    durability: 15
    flags {
      Wood: 1
      Pole: 1
      Pointed: 1
      Sturdy: 1
      Inflammable: 2
    }

    image: "survival/graphics/items/material/wood_stake.png"
    stackable: true

    recipe {
      name: "carve wooden stake"
      recipeTemplate: Carve
      ingredients {
        Ingredient : Items.WoodPole
      }
    }
  }

  WoodShavings {
    weight: 20-30
    fuel: 150
    durability: 2
    flags {
      Compostable: 1
      Tinder: 2
    }

    image: "survival/graphics/items/material/wood_shavings.png"
    stackable: true
  }

  RottingVegetation {
    weight: 200-300
    decay: 2 days
    flags {
      Compostable: 1
    }

    image: "survival/graphics/items/plants/rotting_vegetation.png"
    stackable: true
  }

  SaltWater {
    flags {
      Liquid: 1
    }

    food {
      hunger: 1
      stamina: -2
      hydration: -4
      sanity: -2
    }

    stackable: true
  }

  FreshWater {
    flags {
      Liquid: 1
      Water: 1
    }

    food {
      hunger: 0
      stamina: 1
      hydration: 6
      sanity: 0
    }

    stackable: true
  }

  CarrotRoot {
    weight: 100
    durability: 10

    flags {
      Vegetable: 1
      Edible: 3
      Root: 1
    }

    food {
      hunger: 2-3
      stamina: 1-2
      hydration: 1
      sanity: 1
    }

    durability : 4
    decay: 7 days
    decaysInto: RottingVegetation
    image: "survival/graphics/items/plants/carrot_root.png"
    stackable: true
  }

  RawMeat {
    weight: 200
    durability: 15

    flags {
      Meat: 1
    }

    food {
      hunger: 4-5
      stamina: -1
      hydration: -1
      sanity: -4
    }

    decay: 2 days
    decaysInto: RottingVegetation
    image: "survival/graphics/items/animal/steak.png"
    stackable: true
  }

  RawInsectMeat {
    weight: 200
    durability: 10

    flags {
      Meat: 1
    }

    food {
      hunger: 2-3
      stamina: -2
      hydration: 1
      sanity: -6
    }

    decay: 2 days
    decaysInto: RottingVegetation
    image: "survival/graphics/items/animal/insect_meat.png"
  }

  RoastedMeat {
    flags {
      Edible: "+1"
      Cooked: "+1"
    }

    food {
      hunger: "+3"
      stamina: "+3"
      hydration: "-1"
      sanity: "+4"
    }

    decay: -1 days
    decaysInto: RottingVegetation
    image: "survival/graphics/items/animal/cooked_steak.png"
    stackable: true

    recipe {
      name: "roast meat"
      recipeTemplate: Roast
      ingredients {
        Ingredient : Flags.Meat
      }
      outputs: [Items.RoastedMeat]
      staminaContribution: Max
      sanityContribution: Max
    }
  }

  RoastedInsectMeat: ${Items.RoastedMeat} {
    image: "survival/graphics/items/animal/cooked_insect_meat.png"

    food {
      sanity: "-1"
    }

    recipe: {
      name: "roast insect meat"
      recipeTemplate: Roast
      specializationOf: Recipes.RoastedMeat
      ingredients {
        Ingredient: Items.RawInsectMeat
      }
      outputs: [Items.RoastedInsectMeat]
      staminaContribution: Max
      sanityContribution: Max
    }
  }

  Fiddleheads {
    weight: 20
    durability: 4

    flags {
      Vegetable: 1
      Edible: 1
    }

    food {
      hunger: 1
      sanity: -2
    }

    durability : 4
    decay: 2 days
    decaysInto: RottingVegetation
    image: "survival/graphics/items/plants/fiddlehead_2.png"
    stackable: true
  }

  RoastedVegetable {
    flags {
      Edible: "+1"
      Cooked: "+1"
    }

    food {
      hunger: "+1"
      stamina: "+1"
      hydration: "-1"
      sanity: "+1"
    }

    decay: -1 days
    decaysInto: RottingVegetation
    image: "survival/graphics/items/plants/roasted_vegetable.png"
    stackable: true
  }

  RoastedCarrot: ${Items.RoastedVegetable} {
    image: "survival/graphics/items/plants/roasted_carrot.png"

    recipe {
      name: "roast carrot"
      specializationOf: Recipes.RoastVegetable
      recipeTemplate: Roast
      ingredients.Ingredient : Items.CarrotRoot
      outputs: Items.RoastedCarrot
    }
  }

  RoastedFiddleheads: ${Items.RoastedVegetable} {
    image: "survival/graphics/items/plants/roasted_fiddleheads.png"
    weight: 20
    durability: 4

    food {
      hunger: "+1"
      sanity: "+3"
      stamina: "+0"
      hydration: "+0"
    }

    recipe {
      name: "roast fiddleheads"
      specializationOf: Recipes.RoastVegetable
      recipeTemplate: Roast
      ingredients.Ingredient: Items.Fiddleheads
      outputs: Items.RoastedFiddleheads
    }
  }



  CarrotSeed {
    weight: 10
    durability: 10
    flags {
      Seed: 1
    }

    seedOf: Carrot

    image: "survival/graphics/items/plants/seed.png"
    stackable: true
  }

  Leaves {
    weight: 10
    fuel: 150
    durability: 4
    flags: {
      Compostable : 1
      Tinder: 1
    }

    image: "survival/graphics/items/plants/leaf.png"
    stackable: true
  }

  Vines {
    weight: 50
    fuel: 300
    durability: 15
    flags: {
      Binding: 1
    }

    image: "survival/graphics/items/plants/vine.png"
    stackable: true
  }

  RedBerries {
    weight: 40
    durability: 5

    flags {
      Fruit: 1
      Edible: 3
    }

    food {
      hunger: 2
      stamina: 1
      hydration: 2
      sanity: 1
    }

    durability : 4
    decay: 3 days
    decaysInto: RottingVegetation
    image: "survival/graphics/items/plants/red_berries.png"
    stackable: true
  }

  FireDrill {
    weight: 500
    durability: 30
    flags {
      Wood: 1

    }
    actions {
      Ignite: 1
    }

    image: "survival/graphics/items/tool/fire_drill.png"

    recipe {
      name: "craft fire drill"
      recipeTemplate: Assemble
      ingredients {
        Base: {
          specifiers: [Flags.Flat, Flags.Wood, Flags.Inflammable]
          operator: AND
        }
        Attachment {
          specifiers: [Flags.Wood, Flags.Pointed, Flags.Sturdy]
          operator: AND
        }
      }
    }
  }

  StoneAxeHead {
    weight: 250
    durability: 20
    flags {
      AxeHead: 1
      Stone: 1
    }

    actions {
      Cut: 1
    }

    images: "survival/graphics/items/tool/axe_head.png"

    recipe {
      name: "carve stone axe head"
      recipeTemplate: Carve
      ingredients.Ingredient: [Flags.Stone, Flags.Material]
    }
  }

  StonePickaxeHead {
    weight: 250
    durability: 20
    flags {
      PickaxeHead: 1
      Stone: 1
    }

    actions {
      Cut: 1
    }

    images: "survival/graphics/items/tool/stone_pickaxe_head.png"

    recipe {
      name: "carve stone pickaxe head"
      recipeTemplate: Carve
      ingredients.Ingredient: [Flags.Stone, Flags.Material]
    }
  }

  StoneAxe {
    weight: 2000
    durability: 100
    flags {
      Tool: 1
      Weapon: 1
      Axe: 1
    }

    actions {
      Chop: 1
      Cut: 1
    }

    attack {
      kind: Slash
      damageType: Slashing
      damageAmount: 5
      accuracy: 0.8
      duration: 1 short action
    }

    image: "survival/graphics/items/tool/axe.png"

    recipe {
      name: "craft axe"
      recipeTemplate: Assemble
      ingredients {
        Base: {
          specifiers: [Flags.Pole, Flags.Sturdy]
          operator: AND
        }
        Attachment {
          specifiers: [Flags.Stone, Flags.AxeHead]
          operator: AND
        }
        Binding {
          specifiers: Flags.Binding
        }
      }
    }
  }

  StonePickaxe {
    weight: 2000
    durability: 100
    flags {
      Tool: 1
      Weapon: 1
      Pickaxe: 1
    }

    actions {
      Mine: 1
    }

    image: "survival/graphics/items/tool/pick.png"

    recipe {
      name: "craft pickaxe"
      recipeTemplate: Assemble
      ingredients {
        Base: {
          specifiers: [Flags.Pole, Flags.Sturdy]
          operator: AND
        }
        Attachment {
          specifiers: [Flags.Stone, Flags.PickaxeHead]
          operator: AND
        }
        Binding {
          specifiers: Flags.Binding
        }
      }
    }
  }

  RoughString {
    durability: "+2"
    flags {
      Binding: 1
    }

    image: "survival/graphics/items/material/string.png"

    recipe {
      name: "braid string"
      recipeTemplate: Combine
      ingredients {
        Ingredient: [
          {
            specifiers: Flags.Cordage
          },
          {
            specifiers: Flags.Cordage
          }
        ]
      }
    }

    stackable: true
  }

  SilkString {
    durability: "+5"
    flags {
      Binding: 2
    }
    image: "survival/graphics/items/material/silk_string.png"

    recipe {
      name: "braid string"
      recipeTemplate: Combine
      specializationOf: Recipes.RoughString
      ingredients {
        Ingredient: [
          Items.SpiderSilk,
          Items.SpiderSilk
        ]
      }
    }
  }

  Ash {
    weight: 40
    durability: 5
    flags {
      Ash: 1
    }

    image: "survival/graphics/items/material/ash.png"
    stackable: true
  }

  CrudeTorch {
    durability: "-5" // less durable than the sum of its parts

    image: "survival/graphics/items/lights/torch.png"

    light {
      brightness: 8
      lightColor: [255,180,100,255]
      fireLightSource: true
    }

    fire {
      fuelRemaining: 2500
      durabilityLossTime: 100
      consumedWhenFuelExhausted: true
      activeImages: "survival/graphics/items/lights/torch_lit.png"
    }

    recipe {
      name: "craft crude torch"
      recipeTemplate: Assemble
      ingredients {
        Base: {
          specifiers: [Flags.Pole, Flags.Inflammable]
          operator: AND
        }
        Attachment: Flags.Tinder
        Binding : Flags.Binding
      }
    }
  }

  StoneBowl {
    durability: "6"

    image: "survival/graphics/items/tool/bowl.png"

    flags {
      Bowl: 1
      Stone: 1
    }

    recipe {
      name: "carve bowl"
      recipeTemplate: Carve
      ingredients.Ingredient: Items.Stone
    }
  }

  MortarAndPestle {
    durability: "+5"

    image: "survival/graphics/items/tool/mortar_and_pestle_mine.png"

    recipe {
      name: "assemble mortar and pestle"
      recipeTemplate: Assemble
      ingredients {
        Base: Flags.Bowl
        Attachment {
          specifiers: [Flags.Hard, Flags.Sturdy]
        }
      }
    }

    actions {
      Grind: 1
    }
  }
}