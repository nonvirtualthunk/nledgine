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
    outputs: [Items.Plank|2, Items.Bark|2, Items.Twigs]
  }
}