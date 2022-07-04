import : [survival/widgets/Common.sml]

ActionMenu: ${Menu} {
  showing: "%(ActionMenu.showing)"

  children {
    ActionList: ${MenuList} {
      y: 0

      listItemArchetype: "ActionMenu.ActionItem"
      listItemBinding: "ActionMenu.actions -> option"
    }
  }
}



ActionItem: ${MenuItem} {

}