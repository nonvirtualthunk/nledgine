HandWidget {
  type: Widget
  border.width: 0

  width: 100%
  height: 100%

  showing: "%(active)"

  children {
    CardControlHints {
      type: Widget
      y: 0 from bottom
      z: 50
      width: 34
      height: wrap content
      ignoreMissingRelativePosition: true

      border.width: 1
      border.color: [200,200,200,255]
      showing: ["%(showHints)", "%(handShowing)", "%(showDetail)"]
      children {
        PlayHint {
          type: TextDisplay
          text: "[Enter] Play Card\n[←/→] Select Different Card"
          textColor: [200,200,200,255]
          border.width: 0
        }

        OptionHint {
          type: TextDisplay
          text: "[↑/↓] Select Alternate Option"
          textColor: [200,200,200,255]
          border.width: 0
          y: 0 below PlayHint
          showing: "%(card.hasMultipleOptions)"
        }
      }
    }

    CardDefinitionHints {
      type: ListWidget
      width: 20
      height: wrap content
      z: 50
      border.width: 1
      ignoreMissingRelativePosition: true

      showing: ["%(showDetail)", "%(handShowing)", "%(hasDefinitions)"]

      listItemArchetype: AsciiCardWidgets.CardDefinitionHint
      listItemBinding: "definitions -> definition"
      gapSize: 1
      selectable: false
    }
  }
}

CardWidget {
  type: Widget
  width: 34
  height: 34

  children {
    PrimaryCost {
      type: TextDisplay
      showing: "%(card.hasPrimaryCost)"
      text: "%(card.primaryCost)"
      x: 0 from right
      border.width: 0
    }

    SecondaryCost {
      type: TextDisplay
      showing: "%(card.hasSecondaryCost)"
      text: "%(card.secondaryCost)"
      x: 0
      border.width: 0
    }

    Name {
      type: TextDisplay
      width: -6
      x: centered
      y: 0
      text: "%(card.formattedName)"
      horizontalAlignment: Centered
      multiLine: true
      border.width: 0
    }

    Image {
      type: ImageDisplay
      showing: "%(card.hasImage)"
      y: 0 below Name
      x: Centered
      width: 32
      height: 16
      image: "%(card.image)"
      border.width: 1
    }

    TextOptions {
      type: ListWidget

      x: 0
      y: 1 below Image
      width: 100%
      height: expandToParent(2)
      border.width: 0

      listItemArchetype: AsciiCardWidgets.TextOption
      listItemBinding: "card.textOptions -> textOption"
      separatorArchetype : AsciiCardWidgets.TextOptionDivider
      gapSize: 1
      selectable: true
    }

    PrimaryStats {
      type: TextDisplay

      x: 0 from right
      y: 0 from bottom
      text: "%(card.primaryStats)"
      showing: "%(card.hasPrimaryStats)"
      border.width: 0
    }
  }
}

TextOption {
  type: TextDisplay
  width: 100%
  horizontalAlignment: centered
  multiLine: true
  text: "%(textOption)"
  border.width: 0
}

TextOptionDivider {
  type: TextDisplay
  x: centered
  text: "────────────────────────"
  horizontalAlignment: Centered
  border.width: 0
}

CardDefinitionHint {
  type: TextDisplay
  width: 100%
  multiLine: true
  text: "%(definition)"
  border.width: 0
}