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
import inventory_display

type
  CraftingMenu* = ref object
    widget*: Widget
    activeTemplate*: Taxon
    recipeTemplateInfo*: seq[RecipeTemplateInfo]
    recipeSlotInfo*: seq[RecipeSlotInfo]
    candidateItemInfo*: seq[ItemInfo]
    player*: Entity

  RecipeSlotInfo* = object
    slotKind*: RecipeSlotKind
    name*: string
    description*: string
    icon*: ImageLike
    showName*: bool
    selected*: bool
    selectedItem*: ItemInfo

  RecipeTemplateInfo* = object
    kind*: Taxon
    name*: string
    icon*: ImageLike
    selectedIcon*: ImageLike
    selected*: bool

proc toInfo(name: string, slot: RecipeSlot): RecipeSlotInfo =
  RecipeSlotInfo(
    slotKind: slot.kind,
    name: name.fromCamelCase.capitalize,
    icon: image("survival/icons/blank.png"),
    showName: true
  )


proc selectCandidate(cm: CraftingMenu, world: LiveWorld, item: var ItemInfo) =
  for s in cm.recipeSlotInfo.mitems:
    if s.selected:
      s.selectedItem = item
      s.icon = item.icon

  cm.widget.bindValue("CraftingMenu.recipeSlots", cm.recipeSlotInfo)

  for

proc selectRecipeSlot*(cm: CraftingMenu, world: LiveWorld, slot: var RecipeSlotInfo) =
  for s in cm.recipeSlotInfo.mitems:
    if s.name != slot.name:
      s.selected = false
  slot.selected = true


  cm.candidateItemInfo = constructItemInfo(world, cm.player)
  cm.widget.bindValue("CraftingMenu.candidateItems", cm.candidateItemInfo)

  cm.widget.bindValue("CraftingMenu.recipeSlots", cm.recipeSlotInfo)
  cm.widget.bindValue("CraftingMenu.selectedRecipeSlot", slot)
  cm.widget.bindValue("CraftingMenu.selectedItem.name", "TEST")


proc selectTemplate*(cm: CraftingMenu, world: LiveWorld, recipeTemplateKind: Taxon) =
  cm.activeTemplate = recipeTemplateKind
  for rti in cm.recipeTemplateInfo.mitems:
    rti.selected = rti.kind == cm.activeTemplate
    if rti.selected:
      cm.widget.bindValue("CraftingMenu.activeTemplate", rti)
  cm.widget.bindValue("CraftingMenu.recipeTemplates", cm.recipeTemplateInfo)

  let rt = recipeTemplate(recipeTemplateKind)
  cm.recipeSlotInfo.setLen(0)
  for name, slot in rt.ingredientSlots:
    cm.recipeSlotInfo.add( toInfo(name, slot) )

  if cm.recipeSlotInfo.nonEmpty:
    selectRecipeSlot(cm, world, cm.recipeSlotInfo[0])
  else:
    err &"No recipe slots for recipe template, which doesn't make sense"






proc newCraftingMenu*(ws: ref WindowingSystem, world: LiveWorld, player: Entity) : CraftingMenu =
  let cm = CraftingMenu(
    widget: ws.desktop.createChild("CraftingDisplay", "CraftingMenu"),
    player: player
  )

  for kind, temp in library(RecipeTemplate):
    cm.recipeTemplateInfo.add(RecipeTemplateInfo(
      kind: kind,
      icon: temp.icon,
      selectedIcon: temp.selectedIcon,
      name: kind.displayName.fromCamelCase.capitalize
    ))

  selectTemplate(cm, world, cm.recipeTemplateInfo[0].kind)
  cm



proc onEvent*(cm: CraftingMenu, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(ListItemSelect, index, originatingWidget):
      if originatingWidget.isDescendantOf("RecipeTemplateList"):
        selectTemplate(cm, world, cm.recipeTemplateInfo[index].kind)
      elif originatingWidget.isDescendantOf("IngredientSlotList"):
        selectRecipeSlot(cm, world, cm.recipeSlotInfo[index])
      elif originatingWidget.isDescendantOf("CandidateList"):
        selectCandidate(cm, world, cm.candidateItemInfo[index])


proc update*(world: LiveWorld) =
  discard
