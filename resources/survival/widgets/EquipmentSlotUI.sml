import : [survival/widgets/Common.sml]

EquipmentDisplay: ${Pane} {
  type: Widget
  y: centered
  width: WrapContent
  height: WrapContent
  showing: "%(EquipmentSlots.showing)"
  padding: [5,5]

  children {
    WieldingArea {
      type: Div
      x: centered

      children {
        WieldingLabel {
          type: TextDisplay
          x: centered
          fontSize: 16
          text: "Wielding"
        }
        WieldingSlots {
          type: ListWidget

          y: 4 below WieldingLabel

          width: WrapContent
          height: WrapContent

          horizontal: true
          selectable: false

          listItemArchetype: "EquipmentSlotUI.WieldingSlot"
          listItemBinding: "WieldingSlots -> slot"
        }
      }
    }
    EquipmentArea {
      type: Div

      y: 10 below WieldingArea

      children {
        EquipmentLabel {
          type: TextDisplay
          x: centered
          fontSize: 16
          text: "Wearing"
        }
        EquipmentSlots {
          type: ListWidget

          y: 4 below EquipmentLabel

          width: WrapContent
          height: WrapContent

          horizontal: true
          selectable: false

          listItemArchetype: "EquipmentSlotUI.EquipmentLayer"
          listItemBinding: "EquipmentSlots.layers -> layer"
        }
      }
    }
  }

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
  showing: "%(slot.showing)"
  imageLayers: "%(slot.imageLayers)"

  boundData: "%(slot.identifier)"
}

WieldingSlot {
  type: Div

  children {
    WieldingLabel {
      type: TextDisplay
      text: %(slot.name)
      x: centered
    }
    WieldingSlotDisplay: ${EquipmentSlot} {
      y: 0 below WieldingLabel
    }
  }
}


EquipMenu: ${Menu} {
  showing: "%(EquipMenu.showing)"

  children {
    EquipHeader : {
      type: TextDisplay
      text: "Equip"
      fontSize: 16

      x: Centered
    }
    EquipDivider {
      type: Divider
      y: 4 below EquipHeader
      width: 100%
      pixelScale: 2
    }
    EquipList : ${MenuList} {
      y: 4 below EquipDivider
      listItemArchetype: "EquipmentSlotUI.EquipItem"
      listItemBinding: "EquipMenu.equipOptions -> option"
    }
  }
}

EquipItem: ${MenuItem} {

}