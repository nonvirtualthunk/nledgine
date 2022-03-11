
EncounterWidget {
  type: Widget

  x: 0
  y: 0
  width: expandToParent(30)
  height: expandToParent(15)
  border.width: 0

  children {
    EncounterImage {
      type: ImageDisplay

      x: 0
      y: 0

      width: 48
      height: 32

      image: "%(encounter.image)"
    }

    TextArea {
      type: Widget
      x: -1 right of EncounterImage
      width: expandToParent
      height: expandToParent

      children {
        EncounterText {
          type: TextDisplay

          x: 0
          y: 0
          width: 100%
          text: "%(encounter.text)"
          multiLine: true

          border.width: 0
        }

        EffectText {
          type: TextDisplay
          x: 0
          y: 1 below EncounterText
          width: 100%
          text: "%(encounter.effectText)"
          multiLine: true
          horizontalAlignment: Centered

          border.width: 0
        }

        PromptList {
          type: ListWidget

          x: 0
          y: 0 from bottom
          width: 100%
          height: wrapContent
          border.width: 0

          listItemArchetype: EncounterUI.PromptChoice
          listItemBinding: "encounter.prompts -> prompt"
          gapSize: 0
          selectable: true
        }
      }
    }
  }
}

PromptChoice {
  type: Widget
  width: 100%
  height: wrap content
  border.width: 0

  children {
    Selector {
      type: TextDisplay

      text: "%(prompt.id))"
      textColor: "%(prompt.selectColor)"
      border.color: "%(prompt.selectColor)"
      horizontalAlignment: left
      multiLine: true
      width: 4
    }
    Content {
      type: Widget

      x: -1 right of Selector
      width: expandToParent
      height: wrap content
      border.color: "%(prompt.selectColor)"

      children {
        PromptOption {
          type: TextDisplay

          border.width: 0
          width: expandToParent
          text: "%(prompt.prompt)"
          textColor: "%(prompt.promptColor)"
          multiLine: true
        }

        PromptText {
          type: TextDisplay

          x: 3
          y: 0 below PromptOption
          border.width: 0
          width: expandToParent
          text: "%(prompt.text)"
          textColor: "%(prompt.promptColor)"
          multiLine: true
        }
      }

    }
  }
}