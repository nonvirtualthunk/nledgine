VitalsBar {
  type: Bar
  width: 200
  height: 30

  y: centered
  pixelScale: 2

  fill.image: ui/fancyBackgroundWhite.png
  frame.image: ui/minimalistBorder.png

  text {
    x: centered
    y: 11
    fontSize: 12
    font: "ChevyRayThicket.ttf"
  }
}

VitalsLabel {
  type: TextDisplay
  y: centered

  background.draw: false
  font: "ChevyRayThicket.ttf"
  fontSize: 20
  horizontalAlignment: left
}

VitalsWidget {
  x: 0
  y: 0
  width: 500
  height: 400
  background.draw: false

  children {
    HealthDisplay {
      type: Div
      height: 32

      children {
        HealthLabel: ${VitalsLabel} {
          text: "†GameConcepts.Health"
        }

        HealthBar: ${VitalsBar} {
          x: 3 right of HealthLabel

          fill.color: [0.75, 0.15, 0.2, 1.0]
          fill.edgeColor: [0.75, 0.15, 0.2, 1.0]

          currentValue: "%(player.health)"
          maxValue: "%(player.maxHealth)"
        }
      }
    }

    StaminaDisplay {
      type: Div
      height: 32
      y : 0 below HealthDisplay

      children {
        StaminaLabel : ${VitalsLabel} {
          text: "†GameConcepts.Stamina"
        }

        StaminaBar : ${VitalsBar} {
          x: 3 right of StaminaLabel

          fill.color: [0.1, 0.75, 0.2, 1.0]
          fill.edgeColor: [0.1, 0.75, 0.2, 1.0]

          currentValue: "%(player.stamina)"
          maxValue: "%(player.maxStamina)"
        }
      }
    }

    HungerDisplay {
      type: Div
      height: 32
      y : 0 below StaminaDisplay

      children {
        HungerLabel : ${VitalsLabel} {
          text: "†GameConcepts.Hunger"
        }

        HungerBar : ${VitalsBar} {
          x: 3 right of HungerLabel

          fill.color: [119, 52, 141, 255]
          fill.edgeColor: [119, 52, 141, 255]

          currentValue: "%(player.hunger)"
          maxValue: "%(player.maxHunger)"
        }
      }
    }

    HydrationDisplay {
      type: Div
      height: 32
      y : 0 below HungerDisplay

      children {
        HydrationLabel : ${VitalsLabel} {
          text: "†GameConcepts.Hydration"
        }

        HydrationBar : ${VitalsBar} {
          x: 3 right of HydrationLabel

          fill.color: [0.1, 0.15, 0.75, 1.0]
          fill.edgeColor: [0.1, 0.15, 0.75, 1.0]

          currentValue: "%(player.hydration)"
          maxValue: "%(player.maxHydration)"
        }
      }
    }

  }

}


MessageLog {
  type: Widget
  height: 200
  width: 400

  x: 0
  y: 0 from bottom
  padding: [3,3]

  background.draw: true
  background.image: "ui/fancyBackgroundWhite.png"
  background.color: [120, 120, 120, 200]
  background.pixelScale: 2

  children {
    MessageText {
      type: TextDisplay
      width: 100%
      x: 0
      y: 0 from bottom

      text: "%(messages)"
      fontSize: 12
      font: "ChevyRayThicket.ttf"
    }
  }
}

QuickSlots {
  type: ListWidget
  width: WrapContent
  height: WrapContent
  horizontal: true

  x: centered
  y: 0 from bottom

  listItemArchetype: hud.QuickSlotItem
  listItemBinding: "quickslots.items -> item"
  listItemGapSize: 0

  selectable: false
}

QuickSlotItem {
  type: Widget
  background.image: "ui/fancyBackgroundWhite.png"
  background.color: [120, 120, 120, 200]
  background.draw: true
  background.pixelScale: 2

  width: 88
  height: 88

  children {
    ItemImage {
      type: ImageDisplay
      x: centered
      y: centered
      width: 64
      height: 64
      scale: scaleToFit
      showing: "%(item.showing)"

      image: "%(item.icon)"
    }
    IndexText {
      type: TextDisplay
      x: 3 from right
      y: 3
      z: 10
      text: "%(item.index)"
      fontSize: 24
      font: "ChevyRayThicket.ttf"
    }
  }
}