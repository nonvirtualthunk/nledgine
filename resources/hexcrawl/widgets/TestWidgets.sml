TestBox {
  x: 10
  y: 10
  width: -20
  height: 5
}

TestText {
  type: TextDisplay
  text: Test Text
  x: 10
  y: 5 below TestBox
}

TestList {
  type: ListWidget

  x: 25
  y: 5 below TestBox
  width: expandToParent(10)
  height: 20

  listItemArchetype: TestWidgets.ListItem
  listItemBinding: "testData.items -> item"
  gapSize: 0
  selectable: true
}

ListItem {
  type: Widget

  width: 100%
  height: wrap content
  border.width: 0

  children {
    Selector {
      type: TextDisplay

      text: "%(item.id))"
      textColor: "%(item.color)"
      horizontalAlignment: left
      width: 4
    }
    Content {
      type: TextDisplay

      x: -1 right of Selector

      text: "%(item.content)"
      textColor: "%(item.color)"
      horizontalAlignment: centered
      width: expandToParent
    }
  }
}

TestImage {
  type: ImageDisplay

  x: 5
  y: 50

  width: 45
  height: 45

  image: "%(testData.image)"
  samples: "%(testData.samples)"
}