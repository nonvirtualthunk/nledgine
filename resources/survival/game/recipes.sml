Recipes {

  RoastedVegetable {
    name: "roasted vegetable"
    recipeTemplate: Roast
    ingredients {
      Ingredient {
        specifiers: Flags.Vegetable
      }
    }
    outputs: [{
      item: Items.RoastedVegetable
    }]
  }

  RoastedCarrot {
    name: "roasted carrot"
    specializationOf: Recipes.RoastedVegetable
    recipeTemplate: Roast
    ingredients {
      Ingredient {
        specifiers: Items.CarrotRoot
      }
    }
    outputs: [{
      item: Items.RoastedCarrot
    }]
  }

  CarvePlank {
    name: "carve plank"
    recipeTemplate: Carve
    ingredients {
      Ingredient : Items.Log
    }
    outputs: [Items.Plank|2, Items.Bark|1-2, Items.Twigs|70%]
    durabilityContribution: 0.5
    weightContribution: 0.5
  }

  CarvePoleFromBranch {
    name: "carve pole from branch"
    recipeTemplate: Carve
    ingredients {
      Ingredient : Items.Branch
    }
    outputs: [Items.WoodPole|1, Items.Bark|1, Items.Twigs]
  }

  CarvePoleFromPlank {
    name: "carve pole from plank"
    recipeTemplate: Carve
    ingredients {
      Ingredient : Items.Plank
    }
    outputs: [Items.WoodPole|2, Items.WoodShavings]
    durabilityContribution: 0.5
  }

  SmashStone {
    name: "smash stone"
    recipeTemplate: Smash
    ingredients {
      Ingredient: Items.Stone
    }
    outputs: [Items.StoneShards,Items.SharpStone|50%]
  }

  SmashBranch {
    name: "smash branch"
    recipeTemplate: Smash
    ingredients {
      Ingredient: Items.Branch
    }
    outputs: [Items.WoodPieces|1-2]
  }
}