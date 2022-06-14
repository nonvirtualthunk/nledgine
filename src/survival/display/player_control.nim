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
import game/flags
import graphics/image_extras

type Latch* = object
  notValue: bool

type
  PlayerControlComponent* = ref object of GraphicsComponent
    inventoryLatch*: Latch
    equipmentLatch*: Latch
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
    lastMove*: UnitOfTime
    inventoryWidget*: Widget
    equipmentWidget*: Widget
    choosingQuickSlot*: int
    choosingQuickSlotWidget*: Widget
    activeEventStack*: seq[Event]
    movementDelta*: Vec2i

  ActionInfo = object
    action: ActionChoice
    icon: ImageRef
    text: string
    shortcut: string

  QuickSlotInfo = object
    kind: Taxon
    icon: ImageRef
    showing: bool
    index: int

  EquipmentSlotB = object
    showing: bool
    image: Image
    identifier: string

  EquipmentLayerB = object
    name: string
    slots: seq[EquipmentSlotB]

  EquipmentSlotsB = object
    showing: bool
    layers: seq[EquipmentLayerB]


proc constructActionInfo(world: LiveWorld, player: Entity, considering: Entity): seq[ActionInfo] {.gcsafe.}
proc bindValue*(f: ActionInfo): BoundValue =
  bindValue({"icon": bindValue(f.icon), "text": bindValue(f.text), "shortcut": bindValue(f.shortcut)}.toTable)

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
  ws.desktop.background.image = bindable(imageRef("ui/woodBorderTransparent.png"))

  ws.desktop.createChild("hud", "VitalsWidget")
  g.inventoryWidget = createInventoryDisplay(ws.desktop, "MainInventory")
  ws.desktop.createChild("hud", "MessageLog")
  ws.desktop.createChild("hud", "QuickSlots")
  g.actionMenu = ws.desktop.createChild("ActionMenu", "ActionMenu")
  g.actionMenu.bindValue("ActionMenu.showing", false)
  g.craftingMenu = newCraftingMenu(ws, world, player)
  g.equipmentWidget = ws.desktop.createChild("EquipmentSlotUI", "EquipmentDisplay")




proc performAction(g: PlayerControlComponent, world: LiveWorld, player: Entity, action: ActionChoice) =
  let actionKind = action.action
  if actionKind == † Actions.Place:
    if isEntityTarget(action.target):
      placeEntity(world, action.target.entity, facedPosition(world, player), true)
    else: warn &"Cannot place a tile, what would that mean?: {action.target}"
  elif actionKind == † Actions.Eat:
    if isEntityTarget(action.target):
      eat(world, player, action.target.entity)
    else: warn &"Cannot eat a tile, what would that mean?: {action.target}"
  elif actionKind == † Actions.Ignite:
    var valid = true
    case action.target.kind:
      of TargetKind.Entity:
        if isHeld(world, action.target.entity) and not isEquipped(world, action.target.entity):
          g.messageText.add(richTextVerticalBreak(7))
          g.messageText.add(richText("Cannot ignite an item in inventory, must be equipped", color=some(rgba(120,20,20,255))))
          g.messageLatch.flipOn()
          valid = false
      else:
        discard

    if action.tool.isSentinel:
      warn &"Somehow got an ignite action choice with no tool"
      valid = false

    if valid:
      ignite(world, player, action.tool, some(action.target))
  elif actionKind == † Actions.Equip:
    if isEntityTarget(action.target):
      player[Creature].equipment[† BodyParts.RightHand] = action.target.entity
    else: warn &"Cannot equip a tile, what would that mean?: {action.target}"
  else:
    if not action.tool.isSentinel:
      interact(world, player, @[action.tool], action.target)
    else: warn &"Freeform interact(...) case of performAction, but with no tool?"


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

proc entityKind*(world: LiveWorld, e: Entity): Taxon =
  e[Identity].kind

proc targetToTaxon*(world: LiveWorld, t: Target): Taxon =
  if isEntityTarget(t):
    entityKind(world, t.entity)
  else:
    warn &"Target to taxon only works with entity targets at present"
    UnknownThing

template anyOfType*[T](s: seq[T], t: typedesc) : bool =
  var ret = false
  for v in s:
    if v of t:
      ret = true
  ret

proc message*(world: LiveWorld, evt: Event, activeEventStack: seq[Event]): Option[RichText] =
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
        let toolsUsed = actions.mapIt(it.source).filterIt(it != player).deduplicate
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
        let anyPositive = hungerRecovered > 0 or staminaRecovered > 0 or hydrationRecovered > 0 or sanityRecovered > 0 or healthRecovered > 0
        let anyNegative = hungerRecovered < 0 or staminaRecovered < 0 or hydrationRecovered < 0 or sanityRecovered < 0 or healthRecovered < 0
        let verb = if flagValue(world, eaten, † Flags.Liquid) > 0: "drink some"
          else: "eat a"
        var text = textSection(&"You {verb} {kindStr}")
        var first = true
        proc addVital(amount: int, vital: Taxon, positiveOnly: bool, color: RGBA, last: bool) =
          if (positiveOnly and amount > 0) or (not positiveOnly and amount < 0):
            let commaStr = if first: "" elif last: " and " else: ", "
            text.add(&"{commaStr}{amount.abs} {vital.displayName.toLowerAscii}", textColor = some(color))
            first = false

        
        if anyPositive:
          first = true
          text &= " and recover "

          addVital(hungerRecovered, † GameConcepts.Hunger, true, rgba(100, 40, 120, 255), hydrationRecovered <= 0 and staminaRecovered <= 0 and healthRecovered <= 0 and sanityRecovered <= 0)
          addVital(hydrationRecovered, † GameConcepts.Hydration, true, rgba(0.1, 0.15, 0.75, 1.0), staminaRecovered <= 0 and healthRecovered <= 0 and sanityRecovered <= 0)
          addVital(staminaRecovered, † GameConcepts.Stamina, true, rgba(0.1, 0.75, 0.2, 1.0), healthRecovered <= 0 and sanityRecovered <= 0)
          addVital(healthRecovered, † GameConcepts.Health, true, rgba(0.75, 0.15, 0.2, 1.0), sanityRecovered <= 0)
          addVital(sanityRecovered, † GameConcepts.Sanity, true, rgba(0.75, 0.35, 0.4, 1.0), true)
        
        if anyNegative:
          first = true
          text &= " and lose "
          
          var first = true
          addVital(hungerRecovered, † GameConcepts.Hunger, false, rgba(100, 40, 120, 255), hydrationRecovered >= 0 and staminaRecovered >= 0 and healthRecovered >= 0 and sanityRecovered >= 0)
          addVital(hydrationRecovered, † GameConcepts.Hydration, false, rgba(0.1, 0.15, 0.75, 1.0), staminaRecovered >= 0 and healthRecovered >= 0 and sanityRecovered >= 0)
          addVital(staminaRecovered, † GameConcepts.Stamina, false, rgba(0.1, 0.75, 0.2, 1.0), healthRecovered >= 0 and sanityRecovered >= 0)
          addVital(healthRecovered, † GameConcepts.Health, false, rgba(0.75, 0.15, 0.2, 1.0), sanityRecovered >= 0)
          addVital(sanityRecovered, † GameConcepts.Sanity, false, rgba(0.75, 0.35, 0.4, 1.0), true)

        result = some(richText(text))
    extract(DamageTakenEvent, entity, damageTaken, damageType, source, reason):
      if entity == player and not anyOfType(activeEventStack, AttackHitEvent): # attack events handle this themselves
        result = some(richText(&"You take {damageTaken} {damageType} damage"))
    extract(AttackHitEvent, attacker, target, attackType, damage, damageType):
      if attacker == player:
        let enemyKind = targetToTaxon(world, target)

        result = some(richText(&"You {attackType.kind} the {enemyKind} for {damage} {damageType} damage"))
      elif isEntityTarget(target) and target.entity == player:
        let attackerKind = attacker[Identity].kind

        result = some(richText(&"The {attackerKind} {attackType.kind} you for {damage} {damageType} damage"))
    extract(AttackMissedEvent, attacker, target, attackType):
      if attacker == player:
        result = some(richText(&"(You attempt to {attackType.kind} the {targetToTaxon(world, target)} but you miss"))
      elif isEntityTarget(target) and target.entity == player:
        result = some(richText(&"The {entityKind(world, attacker)} attempst to {attackType.kind} you but misses"))



proc closeMenus(g: PlayerControlComponent) =
  g.actionMenu.bindValue("ActionMenu.showing", false)
  g.actionTarget = none(Entity)
  g.craftingMenu.hide()
  if g.choosingQuickSlotWidget != nil:
    g.choosingQuickSlotWidget.destroyWidget()
    g.choosingQuickSlotWidget = nil
    g.choosingQuickSlot = 0


method onEvent*(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  let ws = display[WindowingSystem]
  matcher(event):
    extract(KeyRelease, key):
      case key:
        of KeyCode.W, KeyCode.A, KeyCode.S, KeyCode.D:
          g.movementDelta = vec2i(0,0)
        else: discard
    extract(KeyPress, key, modifiers, repeat):
      if not repeat:
        g.lastRepeat = relTime()
      else:
        if (relTime() - g.lastRepeat).inSeconds < 0.05:
          return
        g.lastRepeat = relTime()

      let delta = case key:
        of KeyCode.W: vec2i(0,1)
        of KeyCode.A: vec2i(-1,0)
        of KeyCode.S: vec2i(0,-1)
        of KeyCode.D: vec2i(1,0)
        else: vec2(0,0)

      if delta.x != 0 or delta.y != 0:
        if modifiers.shift:
          for player in world.entitiesWithData(Player):
            let phys = player[Physical]
            let facing = primaryDirectionFrom(phys.position.xy, phys.position.xy + delta)
            world.eventStmts(FacingChangedEvent(entity: player, facing: facing)):
              phys.facing = facing
        else:
          g.movementDelta = delta
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
        display.addEvent(CameraChangedEvent())
      elif key == KeyCode.X:
        display[CameraData].camera.changeScale(-1)
        display.addEvent(CameraChangedEvent())
      elif key == KeyCode.C:
        if g.craftingMenu.showing:
          g.closeMenus()
        else:
          g.closeMenus()
          g.craftingMenu.toggle(world)
      elif key == KeyCode.Escape:
        display.addEvent(CancelContext())
      elif key == KeyCode.Period:
        advanceCreatureTime(world, player(world), ShortActionTime)
    extract(WidgetMouseRelease, originatingWidget):
      if originatingWidget == ws.desktop:
        display.addEvent(CancelContext())
    extract(CancelContext):
      g.closeMenus()
    extract(ListItemSelect, originatingWidget, index):
      if originatingWidget.isDescendantOf(g.actionMenu):
        let action = g.actionItems[index]
        if g.actionTarget.isSome:
          performAction(g, world, player(world), action.action)
          g.closeMenus()
        else:
          warn &"Cannot perform action {action.action} without a target"
      # g.closeMenus()
      elif originatingWidget.isDescendantOf("QuickSlots"):
        g.closeMenus()

        g.choosingQuickSlot = index
        g.choosingQuickSlotWidget = createInventoryDisplay(ws.desktop, "QuickSlotSelect")
        g.choosingQuickSlotWidget.x = absolutePos(originatingWidget.resolvedPosition.x, WidgetOrientation.Center)
        g.choosingQuickSlotWidget.y = absolutePos(originatingWidget.resolvedPosition.y, WidgetOrientation.BottomLeft)
        g.choosingQuickSlotWidget.setInventoryDisplayItems(world, toSeq(player(world)[Inventory].items.items))
        g.choosingQuickSlotWidget.onEvent:
          extract(InventoryItemSelectedEvent, itemInfo):
            player(world)[Player].quickSlots[index] = itemInfo.itemEntities[^1]
            g.quickSlotLatch.flipOn()
            g.closeMenus()


    extract(InventoryItemSelectedEvent, itemInfo, originatingPosition, originatingWidget):
      if originatingWidget.identifier == "MainInventory":
        g.closeMenus()

        let item = itemInfo.itemEntities[^1]
        g.actionTarget = some(item)
        g.actionItems = constructActionInfo(world, player(world), item)
        g.actionMenu.bindValue("ActionMenu.showing", true)
        g.actionMenu.bindValue("ActionMenu.actions", g.actionItems)
        g.actionMenu.x = absolutePos(originatingPosition.x, WidgetOrientation.TopRight)
        g.actionMenu.y = absolutePos(originatingPosition.y, WidgetOrientation.TopRight)


  postMatcher(event):
    extract(EntityMovedToInventoryEvent, toInventory):
      if toInventory.hasData(Player):
        g.inventoryLatch.flipOn()
    extract(ItemRemovedFromInventoryEvent,fromInventory):
      if fromInventory.hasData(Player):
        g.inventoryLatch.flipOn()
    extract(ItemEquippedEvent):
      g.equipmentLatch.flipOn()
    extract(ItemUnequippedEvent):
      g.equipmentLatch.flipOn()
    extract(IgnitedEvent):
      g.inventoryLatch.flipOn()
    extract(ExtinguishedEvent):
      g.inventoryLatch.flipOn()
    extract(EntityDestroyedEvent, entity):
      if entity.hasData(Player):
        info "You lose!"
        ws.desktop.createChild("Notifications", "YouLoseWidget")
    # fallthrough case, this must remain last
    extract(GameEvent):
      g.anyLatch.flipOn()

  g.craftingMenu.onEvent(world, display, event)

  if event of GameEvent:
    if event.GameEvent.state == GameEventState.PreEvent:
      g.activeEventStack.add(event)
    else:
      if g.activeEventStack.nonEmpty and g.activeEventStack[^1].eventTypeString == event.eventTypeString:
        g.activeEventStack.del(g.activeEventStack.len-1)

  let msg = message(world, event, g.activeEventStack)
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

proc constructActionInfo(world: LiveWorld, player: Entity, considering: Entity): seq[ActionInfo] =
  for action in possibleActions(world, player, considering):
    let ak = actionKind(action.action)

    # If the target is what we're considering then it is implied and doesn't need to be written out
    let targetText = if action.target == entityTarget(considering):
      ""
    else:
      &" {displayName(world, action.target).toLowerAscii}"

    let text = if not action.tool.isSentinel:
      &"{ak.presentVerb}{targetText} with {displayName(world,action.tool).toLowerAscii}"
    else:
      &"{ak.presentVerb}{targetText}"

    result.add(ActionInfo(
      action: action,
      text: text,
    ))


proc constructEquipmentSlotsInfo(world : LiveWorld, player: Entity) : EquipmentSlotsB =
  let ck : ref CreatureKind = creatureKind(player.kind)

  result.showing = true

  # var slotKinds: seq[ref EquipmentSlotKind]
  var groupings : OrderedSet[Taxon]
  var layers: OrderedTable[Taxon, seq[ref EquipmentSlotKind]]

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
          layerB.slots.add(EquipmentSlotB(showing: true, image: s.image, identifier: s.))
          found = true
          break
      if not found:
        layerB.slots.add(EquipmentSlotB(showing: false))

    result.layers.add(layerB)

  info &"Binding equipment slots: {result}"


method update(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.movementDelta != vec2i(0,0):
    if relTime() - g.lastMove >= 0.18.seconds:
      g.lastMove = relTime()
      let delta = g.movementDelta
      withWorld(world):
        for player in world.entitiesWithData(Player):
          let phys : ref Physical = player[Physical]
          let facing = primaryDirectionFrom(phys.position.xy, phys.position.xy + delta)
          # or facing != phys.facing
          let toPos = phys.position + vec3i(delta.x, delta.y, 0)
          let toTile = tileRef(phys.region[Region], toPos)

          if not interact(world, player, player[Creature].allEquippedItems, toPos, skipNonBlocking=true):

            moveEntityDelta(world, player, vec3i(delta.x, delta.y, 0))
            for ent in toTile.entities:
              ifHasData(ent, Physical, phys):
                if phys.capsuled:
                # if not phys.occupiesTile:
                  if ent.hasData(Item):
                    moveEntityToInventory(world, ent, player)
                  else:
                    warn &"Entity on the ground but not an item: {ent[Identity].kind}"

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
          "sanity" : creature.sanity.currentValue,
          "maxSanity" : creature.sanity.maxValue,
        }.toTable())

      if g.inventoryLatch.flipOff():
        ws.desktop.bindValue("itemIconAndText", true)
        g.inventoryWidget.setInventoryDisplayItems(world, toSeq(player[Inventory].items.items))

      if g.equipmentLatch.flipOff():
        ws.desktop.bindValue("EquipmentSlots", constructEquipmentSlotsInfo(world, player))

      if g.messageLatch.flipOff():
        ws.desktop.bindValue("messages", g.messageText)

      if g.quickSlotLatch.flipOff():
        ws.desktop.bindValue("quickslots.items", constructQuickSlotItemsInfo(world, player))
    @[]