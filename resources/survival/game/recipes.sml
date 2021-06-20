Recipes {

  RoastedVegetable {
    name: "roasted vegetable"
    recipeTemplate: Roast
    ingredients {
      Ingredient {
        requirement: Flags.Vegetable
      }
    }
    outputs: [{
      item: Items.RoastedVegetable
    }]
  }

  RoastedCarrot {
    name: "roasted carrot"
    recipeTemplate: Roast
    ingredients {
      Ingredient {
        requirement: Items.CarrotRoot
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
      Ingredient {
        requirement: Items.Log
      }
    }
    outputs: [{
      item: Items.Plank
    }]
  }
}