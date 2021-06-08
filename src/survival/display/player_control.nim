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

type Latch* = object
  notValue: bool

type
  PlayerControlComponent* = ref object of GraphicsComponent
    inventoryLatch*: Latch
    messageText*: RichText
    messageLatch*: Latch
    quickSlotLatch*: Latch



proc flipOn*(latch: var Latch) : bool {.discardable.} =
  result = latch.notValue
  latch.notValue = false

proc flipOff*(latch: var Latch) : bool {.discardable.}  =
  result = not latch.notValue
  latch.notValue = true


method initialize(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "PlayerControlComponent"

  let ws = display[WindowingSystem]
  ws.desktop.background.image = bindable(imageLike("ui/woodBorderTransparent.png"))

  ws.desktop.createChild("hud", "VitalsWidget")
  ws.desktop.createChild("Inventory", "InventoryWidget")
  ws.desktop.createChild("hud", "MessageLog")
  ws.desktop.createChild("hud", "QuickSlots")


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

        var actionStr = naturalLanguageList(actions, (a) => actionKind(a).presentVerb)

        if fromEntity.isSome:
          let fromEnt = fromEntity.get
          let kindStr = fromEnt[Identity].kind.displayName
          if items.isEmpty:
            result = some(richText(&"You {actionStr} the {kindStr} but haven't yet acquired any resources"))
          else:
            result = some(richText(&"You {actionStr} the {kindStr} and acquire {itemList}"))
        else:
          if items.isEmpty:
            result = some(richText(&"You {actionStr} the ground but haven't yet acquired any resources"))
          else:
            result = some(richText(&"You {actionStr} the ground and acquire {itemList}"))
    extract(CouldNotGatherEvent, entity, fromEntity):
      if entity == player:
        if fromEntity.isSome:
          let kindStr = fromEntity.get()[Identity].kind.displayName
          result = some(richText(&"You could not gather anything further from the {kindStr} with the tools you are using"))
        else:
          result = some(richText(&"You could not gather anything further with the tools you are using"))




method onEvent*(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(KeyPress, key):
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
                  if interact(world, player, player[Creature].allEquippedItems, ent):
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
                      moveItemToInventory(world, ent, ent)
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

    extract(ItemMovedToInventoryEvent, toInventory):
      if toInventory.hasData(Player):
        g.inventoryLatch.flipOn()
    extract(ItemRemovedFromInventoryEvent,fromInventory):
      if fromInventory.hasData(Player):
        g.inventoryLatch.flipOn()


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

type ItemInfo = object
  kind*: Taxon
  icon*: Imagelike
  name*: string
  count*: int
  countStr*: string


proc constructItemInfo*(world: LiveWorld, player: Entity): seq[ItemInfo] =
  var indexesByTaxon : Table[Taxon,int]
  let lib = library(ItemKind)

  proc itemInfo(t: Taxon, k: ItemKind): ItemInfo = ItemInfo(kind: t, icon: k.images[0], name: t.displayName, count: 0, countStr: "")

  withWorld(world):
    let itemsSeq = toSeq(player[Inventory].items.items).sortedByIt(it.id)
    for item in itemsSeq:
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

type QuickSlotInfo = object
  kind: Taxon
  icon: ImageLike
  showing: bool
  index: int


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


method update(g: PlayerControlComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  withWorld(world):
    let ws = display[WindowingSystem]
    for player in world.entitiesWithData(Player):
      let phys = player[Physical]
      let creature = player[Creature]

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
        ws.desktop.bindValue("inventory", {
          "items" : constructItemInfo(world, player)
        }.toTable())

      if g.messageLatch.flipOff():
        ws.desktop.bindValue("messages", g.messageText)

      if g.quickSlotLatch.flipOff():
        ws.desktop.bindValue("quickslots.items", constructQuickSlotItemsInfo(world, player))
    @[]