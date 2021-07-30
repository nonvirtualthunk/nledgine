InventoryWidget {
  type: ListWidget
  width: 250
  height: 600

  y: 0
  x: 0 from right
  padding: [3,3]

  background.pixelScale: 2
  background.image: ui/fancyBackgroundWhite.png
  background.color: [120,120,120,200]
  background.draw: true

  listItemArchetype: Inventory.Item
  listItemBinding: "inventory.items -> item"
  gapSize: -2


  selectable : true
}

Item {
  type: TextDisplay

  text: "%(item.name)%(item.countStr)"

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
      text: "%(item.icon) %(item.name) %(item.countStr)"
    }
  ]

  background.draw: false
  font: "ChevyRayThicket.ttf"
  fontSize: 16
  horizontalAlignment: left
}