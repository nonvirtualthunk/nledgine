
EquipmentDisplay {
  type: ListWidget
  showing: "%(EquipmentSlots.showing)"

  width: WrapContent
  height: WrapContent

  horizontal: true
  selectable: false

  listItemArchetype: "EquipmentSlotUI.EquipmentLayer"
  listItemBinding: "EquipmentSlots.layers -> layer"

  background.image: "ui/buttonBackground.png"
  padding: [5,5]
}

EquipmentLayer {
  type: Div

  children {
    LayerLabel {
      type: TextDisplay

      text: "%(layer.name)"
      x: Centered
    }
    SlotList {
      type: ListWidget

      y: 4 below LayerLabel

      width: WrapContent
      height: WrapContent

      selectable: false

      listItemArchetype: "EquipmentSlotUI.EquipmentSlot"
      listItemBinding: "layer.slots -> slot"

      background.draw: false
    }
  }
}

EquipmentSlot {
  type: ImageDisplay

  width: 76
  height: 76
  scale: ScaleToFit

  background.image: "ui/minimalistBorderWhite.png"
  background.color: [75,75,75,255]
  background.draw: "%(slot.showing)"
  image: "%(slot.image)"

  boundData: "%(slot.identifier)"
}

