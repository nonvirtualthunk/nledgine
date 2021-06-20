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
import graphics/image_extras
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


type
  ItemInfo* = object
    kind*: Taxon
    icon*: Imagelike
    name*: string
    count*: int
    countStr*: string
    itemEntities*: seq[Entity]

proc constructItemInfo*(world: LiveWorld, player: Entity, filter: (LiveWorld, Entity) -> bool = (a: LiveWorld,b: Entity) => true): seq[ItemInfo] =
  var indexesByTaxon : Table[Taxon,int]
  let lib = library(ItemKind)

  proc itemInfo(t: Taxon, k: ItemKind): ItemInfo =
    let img = if k.images.nonEmpty:
      k.images[0]
    else:
      image("images/unknown.png")
    ItemInfo(kind: t, icon: img, name: t.displayName, count: 0, countStr: "")

  withWorld(world):
    let itemsSeq = toSeq(player[Inventory].items.items).sortedByIt(it.id)
    for item in itemsSeq:
      if filter(world, item):
        let itemKindTaxon = item[Identity].kind
        let itemKind = lib[itemKindTaxon]
        var itemInfoIdx = if itemKind.stackable:
          indexesByTaxon.getOrCreate(itemKindTaxon):
            result.add(itemInfo(itemKindTaxon, itemKind))
            result.len - 1
        else:
          result.add(itemInfo(itemKindTaxon, itemKind))
          result.len - 1

        let count = result[itemInfoIdx].count + 1
        result[itemInfoIdx].count = count
        if count > 1:
          result[itemInfoIdx].countStr = &" x{count}"
        result[itemInfoIdx].itemEntities.add(item)