InventoryWidget {
  type: ListWidget
  width: 250
  height: 400

  y: 0
  x: 0 from right
  background.pixelScale: 2
  padding: [3,8]

  background.image: ui/fancyBackgroundWhite.png
  background.color: [120,120,120,200]

  listItemArchetype: Inventory.Item
  listItemBinding: "inventory.items -> item"
  gapSize: -4


  selectable : true
}

Item {
  type: TextDisplay

  text: "%(item.name)%(item.countStr)"

  // This doesn't actually work, just thinking about it
  conditionalText: [
    {
      condition: "%(itemTextOnly)"
      text: "%(item.name)%(item.countStr)"
    },
    {
      condition: "%(itemIconOnly)"
      text: "%(item.icon)%(item.countStr)"
    },
    {
      condition: "%(itemIconAndText)"
      text: "%(item.icon) %(item.name)%(item.countStr)"
    }
  ]

  background.draw: false
  font: "ChevyRayThicket.ttf"
  fontSize: 16
  horizontalAlignment: left
}