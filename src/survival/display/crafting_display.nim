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
import survival_display_core

type
  CraftingMenu* = ref object
    widget*: Widget
    activeTemplate*: Taxon
    recipeTemplateInfo*: seq[RecipeTemplateInfo]
    recipeSlotInfo*: seq[RecipeSlotInfo]
    candidateItemInfo*: seq[ItemInfo]
    recipeOptions*: seq[RecipeOption]
    player*: Entity
    hypotheticalCreatedEntities*: seq[Entity]

  RecipeSlotInfo* = object
    slotKind*: RecipeSlotKind
    name*: string
    description*: string
    icon*: ImageLike
    showName*: bool
    selected*: bool
    selectedItem*: ItemInfo

  RecipeOption* = object
    recipe*: Taxon
    name*: string
    icon*: ImageLike
    selected*: bool


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

proc currentChoices(cm: CraftingMenu) : Table[string, RecipeInputChoice] =
  for s in cm.recipeSlotInfo:
    result[s.name] = RecipeInputChoice(items: s.selectedItem.itemEntities)

proc selectRecipeOption(cm: CraftingMenu, world: LiveWorld, recipeOption: var RecipeOption) =
  for ro in cm.recipeOptions.mitems:
    ro.selected = false
  recipeOption.selected = true

  for ent in cm.hypotheticalCreatedEntities:
    world.destroyEntity(ent)

  let hypo = craftItem(world, cm.player, recipeOption.recipe, currentChoices(cm), true)
  if hypo.isSome:
    cm.hypotheticalCreatedEntities = hypo.get()
    # for ent in cm.hypotheticalCreatedEntities:
    #   printEntityData(world, ent)

  cm.widget.bindValue("CraftingMenu.selectedRecipeOption", recipeOption)
  cm.widget.bindValue("CraftingMenu.selectedRecipeOption.outputs", constructItemInfo(world, cm.hypotheticalCreatedEntities))
  cm.widget.bindValue("CraftingMenu.recipeOptions", cm.recipeOptions)


proc recalculateOutcomes(cm: CraftingMenu, world: LiveWorld) =
  var choices : Table[string, RecipeInputChoice] = currentChoices(cm)

  var newOptions: seq[RecipeOption]
  for recipe in matchingRecipes(world, cm.player, recipeTemplate(cm.activeTemplate), choices):
    newOptions.add(RecipeOption(
      recipe: recipe.taxon,
      name: recipe.name.capitalize,
      icon: iconFor(recipe.taxon)
    ))

  var selectedIndex = if newOptions.mapIt(it.recipe) != cm.recipeOptions.mapIt(it.recipe):
    0
  else:
    max(cm.recipeOptions.indexWhereIt(it.selected), 0)

  if newOptions.nonEmpty:
    newOptions[selectedIndex].selected = true

  cm.recipeOptions = newOptions
  cm.widget.bindValue("CraftingMenu.recipeOptions", cm.recipeOptions)
  cm.widget.bindValue("CraftingMenu.selectedRecipeOption.selected", false)
  cm.widget.bindValue("CraftingMenu.selectedRecipeOption.outputs", newSeq[ItemInfo]())

  if newOptions.nonEmpty:
    selectRecipeOption(cm, world, cm.recipeOptions[selectedIndex])

proc selectCandidate(cm: CraftingMenu, world: LiveWorld, slot: var RecipeSlotInfo, item: ItemInfo) =
  slot.selectedItem = item
  slot.icon = item.icon

  cm.widget.bindValue("CraftingMenu.recipeSlots", cm.recipeSlotInfo)

  recalculateOutcomes(cm, world)


proc selectRecipeSlot*(cm: CraftingMenu, world: LiveWorld, slot: var RecipeSlotInfo) =
  for s in cm.recipeSlotInfo.mitems:
    if s.name != slot.name:
      s.selected = false
  slot.selected = true


  let selectedName = slot.name
  cm.candidateItemInfo = constructItemInfo(world, cm.player, (w,e) => matchesAnyRecipeInSlot(w, cm.player, recipeTemplate(cm.activeTemplate), selectedName, e))
  cm.widget.bindValue("CraftingMenu.candidateItems", cm.candidateItemInfo)

  cm.widget.bindValue("CraftingMenu.recipeSlots", cm.recipeSlotInfo)
  cm.widget.bindValue("CraftingMenu.selectedRecipeSlot", slot)
  cm.widget.bindValue("CraftingMenu.selectedItem.name", slot.selectedItem.name)


proc selectTemplate*(cm: CraftingMenu, world: LiveWorld, recipeTemplateKind: Taxon) =
  cm.activeTemplate = recipeTemplateKind
  for rti in cm.recipeTemplateInfo.mitems:
    rti.selected = rti.kind == cm.activeTemplate
    if rti.selected:
      cm.widget.bindValue("CraftingMenu.activeTemplate", rti)
  cm.widget.bindValue("CraftingMenu.recipeTemplates", cm.recipeTemplateInfo)

  let rt = recipeTemplate(recipeTemplateKind)
  cm.recipeSlotInfo.setLen(0)
  for name, slot in rt.recipeSlots:
    cm.recipeSlotInfo.add( toInfo(name, slot) )
    # never auto-fill ingredients
    # if slot.kind != RecipeSlotKind.Ingredient:

    # if there's only one valid match here, automatically select it
    var matching: seq[Entity]
    for item in cm.player[Inventory].items:
      if matchesAnyRecipeInSlot(world, cm.player, rt, name, item):
        matching.add(item)
    # could add other distinctions on how to choose which tool to use
    if matching.len == 1 or (matching.nonEmpty and slot.kind != RecipeSlotKind.Ingredient):
      selectCandidate(cm, world, cm.recipeSlotInfo[^1], toItemInfo(world, matching[0]))

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
        for s in cm.recipeSlotInfo.mitems:
          if s.selected:
            selectCandidate(cm, world, s, cm.candidateItemInfo[index])


proc update*(world: LiveWorld) =
  discard
