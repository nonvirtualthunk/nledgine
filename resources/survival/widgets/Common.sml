Menu {
  z: 10

  width: 340
  height: WrapContent

  background.pixelScale: 2
  background.image: ui/fancyBackgroundWhite.png
  background.color: [120,120,120,200]

  padding: [3,4]
}

MenuList {
  type: ListWidget

  width: 100%
  height: WrapContent

  y: 0
  background.pixelScale: 2

  background.draw: false

  gapSize: 0
}

MenuItem {
  type: Div
  background.draw : true
  background.image: ui/minimalistBorder.png

  width: 100%

  padding: [2,2]

  boundData: "%(option.identifier)"

  children {
    Text {
      width: 100%
      horizontalAlignment: Center

      y: 2

      type: TextDisplay
      text: "%(option.text)"

      font: "ChevyRayThicket.ttf"
      fontSize: 14
    }
  }
}

Pane {
  background.image: "ui/fancyBackgroundWhite.png"
  background.color: [120, 120, 120, 200]
}