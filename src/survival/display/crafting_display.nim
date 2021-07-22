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
import inventory_display
import survival_display_core
import game/randomness

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
    needsUpdate*: bool

  RecipeSlotInfo* = object
    slotKind*: RecipeSlotKind
    name*: string
    displayName*: string
    description*: string
    icon*: ImageRef
    showName*: bool
    selected*: bool
    selectedItem*: ItemInfo
    count*: int
    index*: int
    subIndex*: int # when there is more than 1 slot of the same name (i.e. distinct ingredients), which index is this

  RecipeOption* = object
    recipe*: Taxon
    name*: string
    icon*: ImageRef
    selected*: bool


  RecipeTemplateInfo* = object
    kind*: Taxon
    name*: string
    icon*: ImageRef
    selectedIcon*: ImageRef
    selected*: bool


proc selectRecipeSlot*(cm: CraftingMenu, world: LiveWorld, slot: var RecipeSlotInfo)

proc toInfo(name: string, slot: RecipeSlot,index: int, subIndex: int = 0): RecipeSlotInfo =
  RecipeSlotInfo(
    slotKind: slot.kind,
    displayName: name.fromCamelCase.capitalize,
    name: name,
    icon: image("survival/icons/blank.png"),
    showName: true,
    count: if slot.`distinct`: 1 else: slot.count,
    index: index,
    subIndex: subIndex
  )

proc currentChoices(cm: CraftingMenu) : Table[string, RecipeInputChoice] =
  for s in cm.recipeSlotInfo:
    var items : seq[Entity]
    # todo: actually deal with counts other than 1
    for i in 0 ..< min(max(s.count,1), s.selectedItem.itemEntities.len):
      items.add(s.selectedItem.itemEntities[i])
    if not result.contains(s.name):
      result[s.name] = RecipeInputChoice(items: items)
    else:
      result[s.name].items.add(items)

proc selectedRecipeOption(cm: CraftingMenu): Option[Taxon] =
  for ro in cm.recipeOptions:
    if ro.selected:
      return some(ro.recipe)
  none(Taxon)

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

  let recipeInfo = recipe(recipeOption.recipe)
  var outputItemInfo = constructItemInfo(world, cm.hypotheticalCreatedEntities)
  for output in recipeInfo.outputs:
    for oii in outputItemInfo.mitems:
      if oii.kind == output.item:
        oii.countStr = "x" & output.amount.displayString

  cm.widget.bindValue("CraftingMenu.selectedRecipeOption", recipeOption)
  cm.widget.bindValue("CraftingMenu.selectedRecipeOption.outputs", outputItemInfo)
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
  slot.selectedItem.count = min(slot.selectedItem.count, max(slot.count, 1))
  if slot.selectedItem.itemEntities.len > max(slot.selectedItem.count, 1):
    slot.selectedItem.itemEntities.setLen(max(slot.selectedItem.count, 1))
  slot.icon = item.icon

  cm.widget.bindValue("CraftingMenu.recipeSlots", cm.recipeSlotInfo)

  recalculateOutcomes(cm, world)

proc entitiesInUse(cm: CraftingMenu): HashSet[Entity] =
  # gather all the entities that are in use by any of the slots
  var entitiesAlreadyInUse : HashSet[Entity]
  for s in cm.recipeSlotInfo:
    entitiesAlreadyInUse.incl(s.selectedItem.itemEntities)
  # and exclude any in use by this specific recipe slot, we can still show those
  for s in cm.recipeSlotInfo:
    if s.selected:
      entitiesAlreadyInUse.incl(s.selectedItem.itemEntities)
  entitiesAlreadyInUse


proc selectRecipeSlot*(cm: CraftingMenu, world: LiveWorld, slot: var RecipeSlotInfo) =
  for s in cm.recipeSlotInfo.mitems:
    s.selected = false
  slot.selected = true


  let entitiesAlreadyInUse = entitiesInUse(cm)
  let accessibleEntities = entitiesAccessibleForCrafting(world, cm.player)

  let selectedName = slot.name
  cm.candidateItemInfo = constructItemInfo(world, accessibleEntities, (w,e) => not entitiesAlreadyInUse.contains(e) and matchesAnyRecipeInSlot(w, cm.player, recipeTemplate(cm.activeTemplate), selectedName, e))
  cm.widget.bindValue("CraftingMenu.candidateItems", cm.candidateItemInfo)

  cm.widget.bindValue("CraftingMenu.recipeSlots", cm.recipeSlotInfo)
  cm.widget.bindValue("CraftingMenu.selectedRecipeSlot", slot)
  cm.widget.bindValue("CraftingMenu.selectedItem.name", slot.selectedItem.name)

proc updateRecipeSlotSelections*(cm: CraftingMenu, world: LiveWorld) =
  var selectedName = ""
  let rt = recipeTemplate(cm.activeTemplate)


  let entitiesAlreadyInUse = entitiesInUse(cm)
  let accessibleEntities = entitiesAccessibleForCrafting(world, cm.player)

  for slot in cm.recipeSlotInfo.mitems:
    let slotName = slot.name
    if slot.selected:
      selectedName = slotName

    if slot.selectedItem.itemEntities.nonEmpty:
      if slot.selectedItem.itemEntities.anyMatchIt(regionForOpt(world, it).isNone):
        selectCandidate(cm, world, slot, ItemInfo(icon: image("survival/icons/blank.png")))

    if slot.selectedItem.itemEntities.isEmpty:
      # if there's only one valid match here and it's not an ingredient (i.e. tool or location), automatically select it
      if slot.slotKind != RecipeSlotKind.Ingredient:
        var matchingItemInfo = constructItemInfo(world, accessibleEntities, (w,e) => not entitiesAlreadyInUse.contains(e) and matchesAnyRecipeInSlot(w, cm.player, recipeTemplate(cm.activeTemplate), slotName, e))
        # could add other distinctions on how to choose which tool to use
        if matchingItemInfo.len == 1 or (matchingItemInfo.nonEmpty and slot.slotKind != RecipeSlotKind.Ingredient):
          selectCandidate(cm, world, slot, matchingItemInfo[0])

  if selectedName != "":
    cm.candidateItemInfo = constructItemInfo(world, accessibleEntities, (w,e) => not entitiesAlreadyInUse.contains(e) and matchesAnyRecipeInSlot(w, cm.player, recipeTemplate(cm.activeTemplate), selectedName, e))
    cm.widget.bindValue("CraftingMenu.candidateItems", cm.candidateItemInfo)

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
    if slot.`distinct`:
      for i in 0 ..< slot.count:
        cm.recipeSlotInfo.add( toInfo(name, slot, cm.recipeSlotInfo.len, i) )
    else:
      cm.recipeSlotInfo.add( toInfo(name, slot, cm.recipeSlotInfo.len) )

  updateRecipeSlotSelections(cm, world)

  if cm.recipeSlotInfo.nonEmpty:
    selectRecipeSlot(cm, world, cm.recipeSlotInfo[0])
  else:
    err &"No recipe slots for recipe template, which doesn't make sense"

proc craft(cm: CraftingMenu, world: LiveWorld) =
  let recipeOpt = selectedRecipeOption(cm)
  if recipeOpt.isNone:
    err &"Confirm button hit with no recipe option selected, can't do"
    return

  let itemsOpt = craftItem(world, cm.player, recipeOpt.get, currentChoices(cm), false)
  if itemsOpt.isNone:
    err &"Crafting menu was not able to actually craft when confirm button was hit"
    return

  let items = itemsOpt.get
  for item in items:
    moveItemToInventory(world, item, cm.player)

  updateRecipeSlotSelections(cm, world)


proc toggle*(cm: CraftingMenu, world: LiveWorld) =
  cm.widget.showing = bindable(not cm.widget.showing.value)
  cm.needsUpdate = true


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

  cm.widget.showing = bindable(false)
  cm



proc onEvent*(cm: CraftingMenu, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(ListItemSelect, index, originatingWidget):
      if originatingWidget.isDescendantOf("RecipeTemplateList"):
        selectTemplate(cm, world, cm.recipeTemplateInfo[index].kind)
      elif originatingWidget.isDescendantOf("IngredientSlotList"):
        selectRecipeSlot(cm, world, cm.recipeSlotInfo[index])
      elif originatingWidget.isDescendantOf("CandidateList"):
        var selectedIndex = -1
        for s in cm.recipeSlotInfo.mitems:
          if s.selected:
            selectedIndex = s.index
            selectCandidate(cm, world, s, cm.candidateItemInfo[index])

        if selectedIndex >= 0:
          for i in 1 ..< cm.recipeSlotInfo.len:
            let idx = (i + selectedIndex) mod cm.recipeSlotInfo.len
            if cm.recipeSlotInfo[idx].selectedItem.itemEntities.isEmpty:
              selectRecipeSlot(cm, world, cm.recipeSlotInfo[idx])
              break
      elif originatingWidget.isDescendantOf("OptionsList"):
        selectRecipeOption(cm, world, cm.recipeOptions[index])
    extract(WidgetMouseRelease, originatingWidget):
      if originatingWidget.isSelfOrDescendantOf("ConfirmButton"):
        if cm.hypotheticalCreatedEntities.nonEmpty and selectedRecipeOption(cm).isSome:
          cm.craft(world)
    extract(CancelContext):
      cm.widget.showing = bindable(false)
    extract(WorldAdvancedEvent):
      cm.needsUpdate = true



proc update*(cm: CraftingMenu, world: LiveWorld) =
  if cm.needsUpdate and cm.widget.showing.value:
    updateRecipeSlotSelections(cm, world)
    cm.needsUpdate = false
