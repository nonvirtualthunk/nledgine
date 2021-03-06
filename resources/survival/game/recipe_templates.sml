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
        requirement: "!Flags.Roasted"
      }
    }

    foodContribution: 1.34
    flagContribution: {
      Edible: 1.0
      Vegetable: 1.0
      Meat: 1.0
    }
    durabilityContribution: 0.75
    decayContribution: 1.34
    weightContribution: 0.9

    addFlags {
      Roasted: 1
    }
  }

  Assemble {
    description: Assemble multiple pieces into a more useful whole
    icon: "survival/graphics/recipes/assemble.png"
    selectedIcon: "survival/graphics/recipes/assemble_selected.png"

    ingredients {
      Base {
        description: "Base piece to attach to"
      }
      Binding {
        description: "Something to attach the two pieces together"
        requirement: Flags.Binding
        optional: true
      }
      Attachment {
        description: "What to attach to the base"
      }
    }
  }

  Combine {
    # Braid stripped bark into string
    # Braid string into rope
    # Weave string into cloth
    #
    description: Meld multiple items together into a stronger whole
    icon: "survival/graphics/recipes/braid.png"
    selectedIcon: "survival/graphics/recipes/braid_selected.png"

    ingredients {
      Ingredient {
        description: "what to combine"
        count: 2
        distinct: true
      }
    }
  }
}