import survival/game/events
import survival/game/entities
import survival/game/tiles
import survival/game/survival_core
import survival/game/logic
import prelude
import engines
import worlds
import graphics/canvas
import graphics/color
import options
import reflect
import resources
import graphics/images
import glm
import random
import times
import tables
import game/library
import sequtils
import sets
import noto
import windowingsystem/windowingsystem
import core
import worlds/identity
import algorithm
import windowingsystem/rich_text
import windowingsystem/list_widget
import strutils
import survival_display_core

type
  ItemInfo* = object
    kind*: Taxon
    icon*: ImageRef
    name*: string
    count*: int
    countStr*: string
    itemEntities*: seq[Entity]

  InventoryDisplayData* = object
    items*: seq[ItemInfo]

  InventoryItemSelectedEvent* = ref object of WidgetEvent
    itemInfo*: ItemInfo
    originatingPosition*: Vec3i


  EquipmentSlotB = object
    showing: bool
    imageLayers: seq[ImageLayer]
    identifier: string
    name: string

  EquipmentLayerB = object
    name: string
    slots: seq[EquipmentSlotB]

  EquipmentSlotsB = object
    showing: bool
    layers: seq[EquipmentLayerB]

  EquipmentUI* = ref object
    mainWidget*: Widget
    menu*: Widget
    activeSlotInteraction*: Option[Taxon]
    forEntity*: Entity

  EquipmentSlotInteracted* = ref object of WidgetEvent
    slot*: Taxon
    originatingPosition*: Vec3i

  EquipmentChangeRequested* = ref object of UIEvent
    entity*: Entity
    newEquipment*: Option[Entity]
    slot*: Taxon

  EquipOption = object
    text*: string
    identifier*: string

defineDisplayReflection(InventoryDisplayData)


proc toItemInfo*(world: LiveWorld, item: Entity) : ItemInfo =
  let itemKindTaxon = item[Identity].kind
  ItemInfo(
    kind: itemKindTaxon,
    icon: iconFor(itemKindTaxon),
    name: itemKindTaxon.displayName,
    count: 1,
    itemEntities: @[item]
  )



proc constructItemInfo*(world: LiveWorld, items: seq[Entity], filter: (LiveWorld, Entity) -> bool = (a: LiveWorld,b: Entity) => true): seq[ItemInfo] =
  var indexesByTaxon : Table[Taxon,int]
  let lib = library(ItemKind)

  proc itemInfo(t: Taxon, item: Entity, k: ref ItemKind): ItemInfo =
    let img = iconFor(world, item)
    ItemInfo(kind: t, icon: img, name: t.displayName, count: 0, countStr: "")

  withWorld(world):
    let itemsSeq = items.sortedByIt(it.id)
    for item in itemsSeq:
      if filter(world, item):
        let itemKindTaxon = item[Identity].kind
        let itemKind = lib[itemKindTaxon]
        var itemInfoIdx = if itemKind.stackable and (not item.hasData(Fire) or not item[Fire].active):
          indexesByTaxon.getOrCreate(itemKindTaxon):
            result.add(itemInfo(itemKindTaxon, item, itemKind))
            result.len - 1
        else:
          result.add(itemInfo(itemKindTaxon, item, itemKind))
          result.len - 1

        let count = result[itemInfoIdx].count + 1
        result[itemInfoIdx].count = count
        if count > 1:
          result[itemInfoIdx].countStr = &"x{count}"
        result[itemInfoIdx].itemEntities.add(item)

proc constructItemInfo*(world: LiveWorld, player: Entity, filter: (LiveWorld, Entity) -> bool = (a: LiveWorld,b: Entity) => true): seq[ItemInfo] =
  constructItemInfo(world, toSeq(player[Inventory].items.items), filter)


import macros
proc createInventoryDisplay*(parent: Widget, name: string) : Widget =
  let invWidget = parent.createChild("Inventory", "InventoryWidget")
  invwidget.identifier = name
  invWidget.attachData(InventoryDisplayData())
  onEventLW(invWidget):
    extract(ListItemSelect, index, widget, originatingWidget):
      display.addEvent(InventoryItemSelectedEvent(widget: widget, itemInfo: widget.data(InventoryDisplayData).items[index], originatingPosition: originatingWidget.resolvedPosition))
  invWidget


proc setInventoryDisplayItems*(w: Widget, world: LiveWorld, items: seq[Entity], filter: (LiveWorld, Entity) -> bool =  (a: LiveWorld,b: Entity) => true) =
  if w.hasData(InventoryDisplayData):
    let inv = w.data(InventoryDisplayData)
    inv.items = constructItemInfo(world, items, filter)
    w.bindValue("inventory.items", inv.items)
  else:
    warn &"Attempting to update the inventory contents of non-inventory widget: {w}"


proc constructEquipmentSlotsInfo(world : LiveWorld, player: Entity) : EquipmentSlotsB =
  let ck : ref CreatureKind = creatureKind(player.kind)

  result.showing = true

  # var slotKinds: seq[ref EquipmentSlotKind]
  var groupings : OrderedSet[Taxon]
  var layers: OrderedTable[Taxon, seq[ref EquipmentSlotKind]]
  let cd = player[Creature]

  for slotK in ck.equipmentSlots:
    let slot : ref EquipmentSlotKind = equipmentSlot(slotK)
    groupings.incl(slot.grouping)
    layers.mgetOrPut(slot.layer, @[]).add(slot)

  for layerKind, slotsInLayer in layers:
    var layerB = EquipmentLayerB(name: layerKind.displayName)
    for grouping in groupings:
      var found = false
      for s in slotsInLayer:
        if s.grouping == grouping:
          var imageLayers: seq[ImageLayer] = @[imageLayer(s.image)]
          if cd.equipment.contains(s.identity):
            imageLayers[0].color = rgba(255,255,255,120)
            imageLayers.add(imageLayer(iconFor(world, cd.equipment[s.identity])))

          layerB.slots.add(EquipmentSlotB(showing: true, imageLayers: imageLayers, identifier: $s.identity))
          found = true
          break
      if not found:
        layerB.slots.add(EquipmentSlotB(showing: false, imageLayers: @[]))

    result.layers.add(layerB)

proc constructWieldingSlotsInfo(world: LiveWorld, player: Entity) : seq[EquipmentSlotB] =
  let ck : ref CreatureKind = creatureKind(player.kind)
  let cd : ref Creature = player[Creature]

  for bp, bpk in ck.bodyParts:
    if bpk.capabilities.contains(† BodyCapabilities.Manipulate):
      let baseImg = if bp == † BodyParts.LeftHand:
        image("survival/icons/equipment_ui/left_hand.png")
      elif bp == † BodyParts.RightHand:
        image("survival/icons/equipment_ui/right_hand.png")
      else:
        image("survival/icons/equipment_ui/brooch.png")

      var imgLayers : seq[ImageLayer] = @[imageLayer(baseImg)]
      let equipped = cd.equipment.getOrDefault(bp)
      if equipped.nonSentinel:
        imgLayers[0].color = rgba(255,255,255,120)
        imgLayers.add(imageLayer(iconFor(world, equipped)))

      result.add(EquipmentSlotB(name: bp.displayName.capitalize, showing: true, imageLayers: imgLayers, identifier: $bp))

proc closeMenus*(ui: EquipmentUI) =
  ui.menu.bindValue("EquipMenu.showing", false)
  ui.activeSlotInteraction = none(Taxon)

proc updateEquipmentDisplay*(ui: EquipmentUI, world: LiveWorld, player: Entity) =
  ui.mainWidget.bindValue("EquipmentSlots", constructEquipmentSlotsInfo(world, player))
  ui.mainWidget.bindValue("WieldingSlots", constructWieldingSlotsInfo(world, player))


proc toggleEquipMenu*(ui: EquipmentUI, world: LiveWorld, player: Entity, slot: Taxon, originatingPosition: Vec3i) =
  if ui.menu.showing and ui.activeSlotInteraction == some(slot):
    ui.menu.bindValue("EquipMenu.showing", false)
    ui.activeSlotInteraction = none(Taxon)
  else:
    ui.activeSlotInteraction = some(slot)
    ui.menu.bindValue("EquipMenu.showing", true)
    ui.menu.x = absolutePos(originatingPosition.x + 6, WidgetOrientation.TopLeft)
    ui.menu.y = absolutePos(originatingPosition.y, WidgetOrientation.TopLeft)

    let cd = player[Creature]

    var options: seq[EquipOption]
    for item in entitiesHeldBy(world, player):
      if item.isA(† Item):
        let ik : ref ItemKind = itemKind(item.kind)
        let canEquipToThis = ik.equipmentSlot == some(slot) or (ik.wieldable and slot.isA(† BodyPart))
        let alreadyEquipped = cd.equipment.getOrDefault(slot, SentinelEntity) == item
        if canEquipToThis and not alreadyEquipped:
          options.add(EquipOption(text: item.kind.displayName.capitalize, identifier: $item))

    if options.isEmpty:
      if cd.equipment.contains(slot):
        options.add(EquipOption(text: "Unequip", identifier: "None"))
      else:
        options.add(EquipOption(text: "No Equipment Available", identifier: "None"))

    ui.menu.bindValue("EquipMenu.equipOptions", options)



proc createEquipmentDisplay*(parent: Widget, forEntity: Entity, name: string) : EquipmentUI =
  let ui = EquipmentUI(
    mainWidget: parent.createChild("EquipmentSlotUI", "EquipmentDisplay"),
    menu: parent.createChild("EquipmentSlotUI", "EquipMenu"),
    forEntity: forEntity
  )
  ui.menu.bindValue("EquipMenu.showing", false)
  onEventLW(ui.mainWidget):
    extract(WidgetMouseRelease, widget, originatingWidget, position):
      for w in originatingWidget.selfAndAncestors:
        if w.boundData.value.nonEmpty:
          let slot = findTaxon(w.boundData.value)
          display.addEvent(EquipmentSlotInteracted(widget: widget, slot: slot, originatingPosition: vec3i(position.x.int, position.y.int, 0)))
          break
    extract(EquipmentSlotInteracted, slot, originatingPosition):
      toggleEquipMenu(ui, world, forEntity, slot, originatingPosition)

  onEventLW(ui.menu):
    extract(ListItemSelect, index, widget, originatingWidget):
      if ui.activeSlotInteraction.isSome:
        let slot = ui.activeSlotInteraction.get
        let identifier = originatingWidget.boundData.value

        let newEquip = if identifier != "None": some(parseEntity(identifier)) else: none(Entity)
        display.addEvent(EquipmentChangeRequested(entity: ui.forEntity, newEquipment: newEquip, slot: slot))
      else:
        warn &"Attempting to interact with equipment menu when no slot is active"
  ui
