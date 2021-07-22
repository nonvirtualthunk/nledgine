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
import noto

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
    let img = if item.hasData(Fire) and item[Fire].active:
      image("survival/graphics/effects/fire_c_24.png")
    elif k.images.nonEmpty:
      k.images[0]
    else:
      image("images/unknown.png")
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


