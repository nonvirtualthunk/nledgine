ActionMenu {
  width: WrapContent
  height: WrapContent

  showing: "%(ActionMenu.showing)"

  children {
    ActionList {
      type: ListWidget

      width: 200
      height: 300

      y: 0
      background.pixelScale: 2
      padding: [3,8]

      background.image: ui/fancyBackgroundWhite.png
      background.color: [120,120,120,200]

      listItemArchetype: "ActionMenu.ActionItem"
      listItemBinding: "ActionMenu.actions -> action"
      gapSize: 0
    }
  }
}



ActionItem {
  type: Div
  background.draw : true
  background.image: ui/minimalistBorder.png

  width: 100%

  padding: [2,2]

  children {
    ActionText {
      y: centered
      type: TextDisplay
      text: "%(action.text)"

      font: "ChevyRayThicket.ttf"
      fontSize: 16
    }
  }
}