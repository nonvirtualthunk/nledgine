
CardBattleWidget {
  x: 0
  y: 0
  border.width: 0
  width: 100%
  height: 100%

  children {
    TopBar {
      type: Widget
      x: 0
      y: 0
      width: 100%
      height: WrapContent
      border.width: 0

      children {
        EndTurnButton {
          type: TextDisplay
          text: "[E]nd Turn"
          x: 0 from right
          y: 0
        }
      }
    }

    BoardWidget {
      type: Widget

      x: 0
      y: 5

      width: 100%
      height: 75%

      children {
        ColumnContainer {
          type: Widget
          border.width: 0
          width: WrapContent
          height: WrapContent
          x: centered
        }
      }

    }

  }
}

ColumnWidget {
  type: Widget
  border.width: 0
  height: WrapContent
  width: 25

  children {
    Block {
      type: TextDisplay
      width: 100%
      text: "◘ %(column.blockAmount)"
      horizontalAlignment: centered
      showing: "%(column.hasBlock)"
      textColor: [58,141,187,255]
      border.width: 0
    }
    Characters {
      type: ListWidget

      y: 0 below Block
      width: 100%
      height: WrapContent

      listItemArchetype: CardBattleUI.CharacterWidget
      listItemBinding: "column.characters -> character"
      gapSize: 0
      selectable: false

      border.width: 0
    }
  }
}

CharacterWidget {
  type: Widget

  width: 100%
  height: WrapContent

  children {
    Name {
      type: TextDisplay

      text: "%(character.activatedIndicator)%(character.name)"
      width: 100%
      multiLine: true
      border.width: 0
      horizontalAlignment: Centered
    }
    Health {
      type: TextDisplay
      y: 1

      width: 100%

      text: "%(character.health) / %(character.maxHealth)"
      textColor: [212, 64, 53, 255]
      border.width: 0
      horizontalAlignment: Centered
    }
    Intent{
      type: TextDisplay
      y: 0 below Health
      border.width: 0

      width: 100%
      horizontalAlignment: Centered
      text: "%(character.intent)"
      showing: "%(character.hasIntent)"
    }
  }
}

