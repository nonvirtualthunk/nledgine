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
import graphics/camera_component
import graphics/cameras
import core
import worlds/identity
import algorithm
import windowingsystem/rich_text
import windowingsystem/list_widget
import strutils
import crafting_display
import inventory_display
import survival_display_core

type Latch* = object
  notValue: bool

type
  PlayerControlComponent* = ref object of GraphicsComponent
    inventoryLatch*: Latch
    messageText*: RichText
    messageLatch*: Latch
    quickSlotLatch*: Latch
    anyLatch*: Latch
    inventoryItems*: seq[ItemInfo]
    actionItems*: seq[ActionInfo]
    actionTarget*: Option[Entity]
    actionMenu*: Widget
    craftingMenu*: CraftingMenu
    lastRepeat*: UnitOfTime

  ActionInfo = object
    kind: Taxon
    icon: ImageLike
    text: string
    shortcut: string

  QuickSlotInfo = object
    kind: Taxon
    icon: ImageLike
    showing: bool
    index: int


proc constructActionInfo(world: LiveWorld, player: Entity, target: Entity): seq[ActionInfo] {.gcsafe.}

proc flipOn*(latch: var Latch) : bool {.discardable.} =
  result = latch.notValue
  latch.notValue = false

proc flipOff*(latch: var Latch) : bool {.discardable.}  =
  result = not latch.notValue
  latch.notValue = true


method initialize(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "PlayerControlComponent"

  let player = player(world)

  let ws = display[WindowingSystem]
  ws.desktop.background.image = bindable(imageLike("ui/woodBorderTransparent.png"))

  ws.desktop.createChild("hud", "VitalsWidget")
  let inventoryWidget = ws.desktop.createChild("Inventory", "InventoryWidget")
  ws.desktop.createChild("hud", "MessageLog")
  ws.desktop.createChild("hud", "QuickSlots")
  g.actionMenu = ws.desktop.createChild("ActionMenu", "ActionMenu")
  g.actionMenu.bindValue("ActionMenu.showing", false)
  g.craftingMenu = newCraftingMenu(ws, world, player)


  inventoryWidget.onEvent(ListItemSelect, lis):
    let item = g.inventoryItems[lis.index].itemEntities[^1]
    g.actionTarget = some(item)
    g.actionItems = constructActionInfo(world, player(world), item)
    g.actionMenu.bindValue("ActionMenu.showing", true)
    g.actionMenu.bindValue("ActionMenu.actions", g.actionItems)
    g.actionMenu.x = absolutePos(lis.originatingWidget.resolvedPosition.x, WidgetOrientation.TopRight)
    g.actionMenu.y = absolutePos(lis.originatingWidget.resolvedPosition.y, WidgetOrientation.TopRight)





proc performAction(world: LiveWorld, display: DisplayWorld, player: Entity, target: Entity, action: Taxon) =
  if action == † Actions.Place:
    placeItem(world, some(player), target, facedPosition(world, player), true)
  elif action == † Actions.Eat:
    eat(world, player, target)


proc naturalLanguageList*[T](s : seq[T], f : (T) -> string) : string =
  for i in 0 ..< s.len:
    if i != 0:
      if i == s.len - 1 and i > 1:
        result.add(", and ")
      elif i == s.len - 1:
        result.add(" and ")
      else:
        result.add(",")
    result.add(f(s[i]))

proc message*(world: LiveWorld, evt: Event): Option[RichText] =
  let player = player(world)
  postMatcher(evt):
    extract(GatheredEvent, entity, items, actions, fromEntity):
      if entity == player:
        var gatheredByKind : Table[Taxon, int]
        for item in items:
          let ik = item[Identity].kind
          gatheredByKind[ik] = gatheredByKind.getOrDefault(ik) + 1

        var itemList : string
        var spacer = ""
        for kind, count in gatheredByKind:
          itemList.add(&"{spacer}{count} {kind.displayName}")
          spacer = ", "

        var actionStr = naturalLanguageList(actions, (a) => actionKind(a.kind).presentVerb)
        let toolsUsed = actions.mapIt(it.source).filterIt(it != player)
        let toolStr = if toolsUsed.isEmpty:
          ""
        else:
          " with your " & naturalLanguageList(toolsUsed, (t) => t[Identity].kind.displayName.fromCamelCase)


        if fromEntity.isSome:
          let fromEnt = fromEntity.get
          let kindStr = fromEnt[Identity].kind.displayName
          if items.isEmpty:
            result = some(richText(&"You {actionStr} the {kindStr}{toolStr} but haven't yet acquired any resources"))
          else:
            result = some(richText(&"You {actionStr} the {kindStr}{toolStr} and acquire {itemList}"))
        else:
          if items.isEmpty:
            result = some(richText(&"You {actionStr} the ground{toolStr} but haven't yet acquired any resources"))
          else:
            result = some(richText(&"You {actionStr} the ground{toolStr} and acquire {itemList}"))
    extract(CouldNotGatherEvent, entity, fromEntity):
      if entity == player:
        if fromEntity.isSome:
          let kindStr = fromEntity.get()[Identity].kind.displayName
          result = some(richText(&"You could not gather anything further from the {kindStr} with the tools you are using"))
        else:
          result = some(richText(&"You could not gather anything further with the tools you are using"))
    extract(FoodEatenEvent, entity, eaten, hungerRecovered, staminaRecovered, hydrationRecovered, sanityRecovered, healthRecovered):
      if entity == player:
        let kindStr = eaten[Identity].kind.displayName
        var text = textSection(&"You eat a {kindStr} and recover ")
        var first = true

        proc addVital(amount: int, vital: Taxon, color: RGBA, last: bool) =
          if amount > 0:
            let commaStr = if first: "" elif last: " and " else: ", "
            text.add(&"{commaStr}{amount} {vital.displayName.toLowerAscii}", textColor = some(color))
            first = false

        addVital(hungerRecovered, † GameConcepts.Hunger, rgba(100, 40, 120, 255), hydrationRecovered == 0 and staminaRecovered == 0 and healthRecovered == 0 and sanityRecovered == 0)
        addVital(hydrationRecovered, † GameConcepts.Hydration, rgba(0.1, 0.15, 0.75, 1.0), staminaRecovered == 0 and healthRecovered == 0 and sanityRecovered == 0)
        addVital(staminaRecovered, † GameConcepts.Stamina, rgba(0.1, 0.75, 0.2, 1.0), healthRecovered == 0 and sanityRecovered == 0)
        addVital(healthRecovered, † GameConcepts.Health, rgba(0.75, 0.15, 0.2, 1.0), sanityRecovered == 0)
        addVital(sanityRecovered, † GameConcepts.Sanity, rgba(0.75, 0.35, 0.4, 1.0), true)

        result = some(richText(text))


proc closeMenus(g: PlayerControlComponent) =
  g.actionMenu.bindValue("ActionMenu.showing", false)
  g.actionTarget = none(Entity)


method onEvent*(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  let ws = display[WindowingSystem]
  matcher(event):
    extract(KeyPress, key, modifiers, repeat):
      if not repeat:
        g.lastRepeat = relTime()
      else:
        if (relTime() - g.lastRepeat).inSeconds < 0.1:
          return
        g.lastRepeat = relTime()

      let delta = case key:
        of KeyCode.W: vec2i(0,1)
        of KeyCode.A: vec2i(-1,0)
        of KeyCode.S: vec2i(0,-1)
        of KeyCode.D: vec2i(1,0)
        else: vec2(0,0)

      if delta.x != 0 or delta.y != 0:
        withWorld(world):
          for player in world.entitiesWithData(Player):
            let phys = player[Physical]
            let facing = primaryDirectionFrom(phys.position.xy, phys.position.xy + delta)
            # or facing != phys.facing
            if modifiers.shift:
              world.eventStmts(FacingChangedEvent(entity: player, facing: facing)):
                phys.facing = facing
            else:
              let toPos = phys.position + vec3i(delta.x, delta.y, 0)
              let toTile = tile(phys.region, toPos.x, toPos.y, toPos.z)

              var interactingWithBlockingEntity = false
              var interactedSuccessfully = false
              var interactedWithEntity : Entity
              for ent in toTile.entities:
                ifHasData(ent, Physical, phys):
                  if phys.occupiesTile:
                    interactedWithEntity = ent
                    interactingWithBlockingEntity = true
                    if interact(world, player, player[Creature].allEquippedItems, Target(kind: TargetKind.Entity, entity: ent)):
                      interactedSuccessfully = true
                      break

              if interactingWithBlockingEntity and not interactedSuccessfully:
                world.addFullEvent(CouldNotGatherEvent(entity: player, fromEntity: some(interactedWithEntity)))

              if not interactingWithBlockingEntity:
                moveEntityDelta(world, player, vec3i(delta.x, delta.y, 0))
                for ent in toTile.entities:
                  ifHasData(ent, Physical, phys):
                    if phys.capsuled:
                      if ent.hasData(Item):
                        moveItemToInventory(world, ent, player)
                      else:
                        warn &"Entity on the ground but not an item: {ent[Identity].kind}"

      elif key.ord >= KeyCode.K0.ord and key.ord <= KeyCode.K9.ord:
        # map 1-9 -> 0-8, 0 -> 9 so we can use the keys in order of the keyboard
        let index = if key == KeyCode.K0:
          9
        else:
          key.ord - KeyCode.K0.ord - 1

        withWorld(world):
          for player in world.entitiesWithData(Player):
            let inSlot = player[Player].quickSlots[index]
            if not inSlot.isSentinel:
              if not interact(world, player, @[inSlot], facedPosition(world, player)):
                world.addFullEvent(CouldNotGatherEvent(entity: player, fromEntity: none(Entity)))
      elif key == KeyCode.Z:
        display[CameraData].camera.changeScale(+1)
      elif key == KeyCode.X:
        display[CameraData].camera.changeScale(-1)
      elif key == KeyCode.C:
        g.craftingMenu.toggle(world)
      elif key == KeyCode.Escape:
        display.addEvent(CancelContext())
    extract(WidgetMouseRelease, originatingWidget):
      if originatingWidget == ws.desktop:
        display.addEvent(CancelContext())
    extract(CancelContext):
      g.actionMenu.bindValue("ActionMenu.showing", false)
    extract(ListItemSelect, originatingWidget, index):
      if originatingWidget.isDescendantOf(g.actionMenu):
        let action = g.actionItems[index]
        if g.actionTarget.isSome:
          performAction(world, display, player(world), g.actionTarget.get, action.kind)
        else:
          warn &"Cannot perform action {action.kind} without a target"
      g.closeMenus()


  postMatcher(event):
    extract(ItemMovedToInventoryEvent, toInventory):
      if toInventory.hasData(Player):
        g.inventoryLatch.flipOn()
    extract(ItemRemovedFromInventoryEvent,fromInventory):
      if fromInventory.hasData(Player):
        g.inventoryLatch.flipOn()
    extract(GameEvent):
      g.anyLatch.flipOn()

  g.craftingMenu.onEvent(world, display, event)

  let msg = message(world, event)
  if msg.isSome:
    if g.messageText.isEmpty:
      g.messageText.add(richText(msg.get))
    else:
      g.messageText.add(richTextVerticalBreak(7))
      g.messageText.add(msg.get)
    if g.messageText.sections.len > 30:
      g.messageText = g.messageText.subsection(-30,-1)
    g.messageLatch.flipOn()




proc constructQuickSlotItemsInfo(world: LiveWorld, player: Entity): seq[QuickSlotInfo] =
  withWorld(world):
    for inSlot in player[Player].quickSlots:
      if inSlot.isSentinel:
        result.add(QuickSlotInfo())
      else:
        if inSlot.hasData(Player):
          result.add(QuickSlotInfo(
            kind: † Actions.Gather,
            icon: image("survival/icons/hands.png"),
            showing: true
          ))
        else:
          let kind = inSlot[Identity].kind
          result.add(QuickSlotInfo(
            kind: kind,
            icon: itemKind(kind).images[0],
            showing: true
          ))
    for i in 0 ..< result.len:
      result[i].index = (i+1) mod 10

proc constructActionInfo(world: LiveWorld, player: Entity, target: Entity): seq[ActionInfo] =
  for action in possibleActions(world, player, target):
    let ak = actionKind(action)
    result.add(ActionInfo(
      kind: action,
      text: ak.presentVerb,
    ))

method update(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  g.craftingMenu.update(world)

  withWorld(world):
    let ws = display[WindowingSystem]
    for player in world.entitiesWithData(Player):
      let phys = player[Physical]
      let creature = player[Creature]

      if g.anyLatch.flipOff():
        ws.desktop.bindValue("player", {
          "health" : phys.health.currentValue,
          "maxHealth" : phys.health.maxValue,
          "stamina" : creature.stamina.currentValue,
          "maxStamina" : creature.stamina.maxValue,
          "hydration" : creature.hydration.currentValue,
          "maxHydration" : creature.hydration.maxValue,
          "hunger" : creature.hunger.currentValue,
          "maxHunger" : creature.hunger.maxValue,
        }.toTable())

      if g.inventoryLatch.flipOff():
        ws.desktop.bindValue("itemIconAndText", true)
        g.inventoryItems = constructItemInfo(world, player)
        ws.desktop.bindValue("inventory", {
          "items" : g.inventoryItems
        }.toTable())

      if g.messageLatch.flipOff():
        ws.desktop.bindValue("messages", g.messageText)

      if g.quickSlotLatch.flipOff():
        ws.desktop.bindValue("quickslots.items", constructQuickSlotItemsInfo(world, player))
    @[]