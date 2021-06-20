RecipeTemplates {

  Carve {
    description : Cut or carve into smaller pieces or different shapes
    icon: "survival/graphics/recipes/carve.png"
    selectedIcon: "survival/graphics/recipes/carve_selected.png"
    tools: {
      Blade {
        decription: ""
        requirement: {
          specifiers: [Actions.Cut, Actions.Chop]
        }
      }
    }
    ingredients {
      Ingredient {
        description: "what to cut or carve"
      }
    }

    foodContribution: 0.75
    flagContribution: {
      Wood: max
    }
    durabilityContribution: 0.75
    decayContribution: 0.75
    weightContribution: 0.75
  }

  Roast {
    description : Heat or cook with an open flame
    icon: "survival/graphics/recipes/roast.png"
    selectedIcon: "survival/graphics/recipes/roast_selected.png"
    tools: {
      CookingImplement {
        decription: "hold ingredients over the fire without burning yourself"
        requirement: {
          specifiers: [Flags.Pole, Flags.Tongs, Flags.CookingImplement]
        }
      }
    }
    locations: {
      Fire {
        description: "flame to cook your food"
        requirement: Flags.Fire 1
      }
    }
    ingredients {
      Ingredient {
        description: "what to roast over the fire"
      }
    }

    foodContribution: 1.34
    flagContribution: {
      Edible: 1.0
      Root: 1.0
      Vegetable: 1.0
      Meat: 1.0
    }
    durabilityContribution: 0.75
    decayContribution: 1.34
    weightContribution: 0.9
  }
}