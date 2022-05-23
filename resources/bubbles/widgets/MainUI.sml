LabeledBar {
  type: Div
  width: 180
  height: 32

  children {

    BarImageLabel {
      type: ImageDisplay
      background.draw: false
      width: 32
      height: 32
      scale: scaleToFit
    }

    Bar: {
      type: Bar
      x: 3 right of BarImageLabel
      width: ExpandToParent
      height: 29
      offsetInnerBar: false

      y: centered
      pixelScale: 2

      fill.image: ui/minimalistBorderWhite.png
      frame.image: ui/minimalistBorder.png

      text {
        x: centered
        y: centered
        fontSize: 16
        font: "ChevyRayThicket.ttf"
      }
    }
  }
}

LabeledNumber {
  type: Div
  width: WrapContent
  height: 35

  children {

    ImageLabel {
      type: ImageDisplay
      background.draw: false
      width: 32
      height: 32
      scale: scaleToFit
    }

    NumberDisplay: {
      type: TextDisplay
      x: 3 right of ImageLabel
      y: centered
      fontSize: 20
    }
  }
}


MainUI {
  type: Div
  width: 100%
  height: 100%

  children {
    PlayArea {
      type: Widget
      background.image: ui/woodBorderTransparent.png

      width: -400
      height: 100%
      x: 0
      y: 0 from bottom
    }
    InfoArea {
      x: 0 right of PlayArea
      y: 0
      width: ExpandToParent
      height: 100%
      children {
        BattleScreen {
          type: Widget
          background.image: ui/buttonBackground.png
          x: 0
          y: 0
          width: expandToParent
          height: 300
          padding: [5,5]

          children {
            EnemySection {
              type: Div
              showing: "%(enemy.showing)"
              width: 100%
              height: 100%

              children {
                EnemyName {
                  type: TextDisplay
                  text: "%(enemy.name)"
                  fontSize: 20
                  horizontalAlignment: center
                  width: 100%
                }
                EnemyImage {
                  type: ImageDisplay
                  image: "%(enemy.image)"
                  scale: scale(6)
                  x: centered
                  y: 0 below EnemyName
                }
                EnemyIntent {
                  type: Div
                  x: 0 from Right
                  y: 0 below EnemyName
                  width: WrapContent
                  height: WrapContent
                  children {
                    IntentDisplay: ${LabeledNumber} {
                      children.ImageLabel.image: "%(enemy.intentIcon)"
                      children.NumberDisplay.text: "%(enemy.intentText)"
                      children.NumberDisplay.textColor: "%(enemy.intentColor)"
                    }
                    IntentTimeDisplay: ${LabeledNumber} {
                      y: 0 below IntentDisplay
                      children.ImageLabel.image: "bubbles/images/icons/time.png"
                      children.NumberDisplay.text: "%(enemy.intentTime)"
                      children.NumberDisplay.textColor: [0.9,0.9,0.9,1.0]
                    }
                  }
                }
                EnemyHealthBar: ${LabeledBar} {
                  x: 0
                  y: 15 below EnemyImage
                  children.BarImageLabel.image: "bubbles/images/icons/health_2.png"
                  children.Bar {
                    currentValue: "%(enemy.health)"
                    maxValue: "%(enemy.maxHealth)"
                    fill.color: [0.75, 0.15, 0.2, 1.0]
                    fill.edgeColor: [0.75, 0.15, 0.2, 1.0]
                  }
                }
                EnemyBlock: ${LabeledNumber} {
                  x: 5 right of EnemyHealthBar
                  y: match EnemyHealthBar
                  showing: "%(enemy.blockShowing)"

                  children {
                    ImageLabel {
                      image: "bubbles/images/icons/block.png"
                    }
                    NumberDisplay {
                      text: "%(enemy.block)"
                      textColor: [0.2, 0.1, 0.75, 1.0]
                    }
                  }
                }
              }
            }
          }
        }
        CharacterScreen {
          type: Widget
          background.image: ui/buttonBackground.png
          x: 0
          y: 0 below BattleScreen
          width: expandToParent
          height: expandToParent
          padding: [5,5]

          children {
            PlayerName {
              type: TextDisplay
              text: "%(playerName)"
              fontSize: 20
              horizontalAlignment: center
              width: 100%
            }
            PlayerImage {
              type: ImageDisplay
              image: "%(playerImage)"
              scale: scale(6)
              x: centered
              y: 0 below PlayerName
            }
            ModifiersDisplay {
              type: ListWidget
              y: 15 below PlayerImage
              width: WrapContent
              height: WrapContent
              x: centered
              horizontal: true
              selectable: false

              listItemArchetype: MainUI.ModifierWidget
              listItemBinding: "playerModifiers -> modifier"
              gapSize: 0
            }
            MainStatsDisplay {
              type: Div
              y: 5 below ModifiersDisplay
              width: 100%
              height: WrapContent
              children {
                HealthBar: ${LabeledBar} {
                  children.BarImageLabel.image: "bubbles/images/icons/health_2.png"
                  children.Bar {
                    currentValue: "%(playerHealth)"
                    maxValue: "%(playerMaxHealth)"
                    fill.color: [0.75, 0.15, 0.2, 1.0]
                    fill.edgeColor: [0.75, 0.15, 0.2, 1.0]
                  }
                }
                PlayerBlock: ${LabeledNumber} {
                  x: 5 right of HealthBar
                  y: match HealthBar
                  showing: "%(playerBlockShowing)"

                  children {
                    ImageLabel {
                      image: "bubbles/images/icons/block.png"
                    }
                    NumberDisplay {
                      text: "%(playerBlock)"
                      textColor: [0.2, 0.1, 0.75, 1.0]
                    }
                  }
                }
              }
            }
            ActionBars {
              type: Div
              y: 15 below MainStatsDisplay
              width: 100%
              height: WrapContent
              children {
                ActionLabel {
                  type: TextDisplay
                  x: centered
                  text: "Actions"
                  fontSize: 20
                }
                ActionDivider {
                  type: Divider
                  y: 5 below ActionLabel
                  width: 100%
                  pixelScale: 2
                }
              }
            }
          }
        }
      }
    }
  }
}


ModifierWidget {
  type: Div
  children {
    ModifierImage {
      type: ImageDisplay
      image: "%(modifier.image)"
      width: 32
      height: 32
      scale: scaleToFit
      background.draw: false
    }
    ModifierText {
      type: TextDisplay
      text: "%(modifier.number)"
      fontSize: 12
      textColor: [255,255,255,255]
      background.draw: false
      x: -3 right of ModifierImage
      y: -8 below ModifierImage
    }
  }
}