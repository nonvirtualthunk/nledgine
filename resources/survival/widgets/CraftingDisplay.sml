CraftingPanel {
  y: 0 below RecipeTemplateList

  height: ExpandToParent

  background.image: ui/minimalistBorderWhite.png
  background.color: [120, 120, 120, 200]
  background.pixelScale: 1
}

CraftingMenu {
  type: Widget

  x: centered
  y: centered
  width: 1200
  height: 700

  background.image: "ui/buttonBackground.png"
  background.draw: true
  background.pixelScale: 2

  children {
    RecipeTemplateList {
      type: ListWidget

      x: 0
      y: 0
      width: 100%
      height: WrapContent

      horizontal: true
      padding: [0,0]

      background.image: ui/minimalistBorderWhite.png
      background.color: [120,120,120,200]
      background.pixelScale: 1

      listItemArchetype: "CraftingDisplay.RecipeTemplateButton"
      listItemBinding: "CraftingMenu.recipeTemplates -> recipeTemplate"
      gapSize: 0
    }

    InventoryArea: ${CraftingPanel} {
      x: 0
      width: 33%

      children {
        SelectedSlotName {
          type: TextDisplay

          x: centered
          text: "Select %(CraftingMenu.selectedRecipeSlot.name)"

          fontSize: 20
        }
        SelectedSlotDescription {
          type: TextDisplay

          x: centered
          y: 0 below SelectedSlotName
          text: "%(CraftingMenu.selectedRecipeSlot.description)"

          fontSize: 12
        }
        CandidateDescription {
          type: TextDisplay

          x: 0
          y: 0 from bottom
          text: "%(CraftingMenu.selectedItem.name)"
        }
        CandidateList {
          type: ListWidget

          x: 0
          y: 0 below SelectedSlotDescription

          width: 100%
          height: expandTo CandidateDescription

          listItemArchetype: "Inventory.Item"
          listItemBinding: "CraftingMenu.candidateItems -> item"
        }
      }
    }

    IngredientArea: ${CraftingPanel} {
      x: 0 right of InventoryArea
      width: 33%

      children {
        RecipeTemplateLabel {
          type: TextDisplay

          x: centered
          y: 2

          text: "%(CraftingMenu.activeTemplate.name)"
          fontSize: 20
        }

        IngredientSlotList {
          type: ListWidget

          x: 0
          y: 15 below RecipeTemplateLabel
          width: 100%
          height: ExpandToParent

          background.draw: false

          listItemArchetype: "CraftingDisplay.IngredientSlot"
          listItemBinding: "CraftingMenu.recipeSlots -> recipeSlot"
          gapSize: 10
        }
      }
    }

    CraftingResultArea: ${CraftingPanel} {
      x: 0 right of IngredientArea
      width: ExpandToParent

      children {
        OptionsList {
          type: ListWidget
          x: 0
          y: 0
          width: 100%
          height: WrapContent

          horizontal: true

          background.draw: true
          background.drawEdges : [Bottom]
          background.drawCenter: false
          listItemArchetype: "CraftingDisplay.RecipeSelectButton"
          listItemBinding: "CraftingMenu.recipeOptions -> recipe"
        }
      }
    }
  }
}

RecipeTemplateButton {
  type: ImageDisplay

  width: 64
  height: 64

  background.draw: false

  conditionalImage : [
    {
      condition: "%(recipeTemplate.selected)"
      image: %(recipeTemplate.selectedIcon)
    },
    {
      image: "%(recipeTemplate.icon)"
    }
  ]

  scale: ScaleToFit
}


IngredientSlot {
  type: Widget

  width: 100%
  height: WrapContent
  padding: [3,3]

  background.draw: false

  children {
    IngredientImage {
      type: ImageDisplay

      x: centered
      y: 0
      width: 78
      height: 78

      image: "%(recipeSlot.icon)"
      scale: ScaleToFit
      drawImageAfterChildren: true

      background.image: "ui/buttonBackground.png"
      background.draw: true

      overlays: [
        {
          image : "survival/graphics/ui/active_ingredient_slot_overlay.png"
          pixelScale : 2
          color : [1.0,1.0,1.0,1.0]
          draw : %(recipeSlot.selected)
          drawCenter : true
          dimensionDelta: [1,1]
        },
      ]
    }

    IngredientName {
      type: TextDisplay

      x: centered
      y: 0 below IngredientImage

      text: "%(recipeSlot.name)"
      showing: "%(recipeSlot.showName)"
    }
  }
}

RecipeSelectButton {
  type: Widget
  x: 0
  y: 0

  width: WrapContent
  height: WrapContent

  children {
    Icon {
      type: ImageDisplay

      width: 64
      height: 64

      background.draw: false

      image: "%(recipe.icon)"
      scale: scaleToFit
    }
  }
}