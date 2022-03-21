import windowing_system_core

import engines
import graphics
import prelude
import tables
import strformat
import options
import windowingsystem/windowingsystem
import windowingsystem/rich_text
import noto
import math
import windowingsystem/list_widget
import graphics/core
import core/metrics
import graphics/ascii_renderer


type

  CardUI* = object
    hand: seq[CardDisplayB]
    modified: bool
    handWidget: Widget
    cardWidgets: Table[Entity,Widget]
    focused*: bool
    tentativeCard*: Option[Entity]
    selectedGroup*: int
    cardControlHints: Widget
    cardDefinitionHints: Widget
    active: bool

    showHints*: bool

  CardCostB* = object
    cost*: int
    symbol*: RichText
    color*: Option[RGBA]

  CardDisplayB* = object
    entity*: Entity
    name*: RichText
    primaryCost*: Option[CardCostB]
    secondaryCost*: Option[CardCostB]
    primaryStats*: Option[RichText]
    image*: Option[Image]
    textOptions*: seq[RichText]
    definitions*: seq[RichText]


  CardDisplayInternal = object
    formattedName: RichText
    primaryCost: RichText
    hasPrimaryCost: bool
    secondaryCost: RichText
    hasSecondaryCost: bool
    primaryStats: RichText
    hasPrimaryStats: bool
    image: Option[Image]
    hasImage: bool
    textOptions: seq[RichText]
    hasMultipleOptions: bool

  CardChosenEvent* = ref object of UIEvent
    card*: Entity
    activeGroup*: int


type
  AsciiCardComponent* = ref object of GraphicsComponent

defineDisplayReflection(CardUI)


proc tentativeCardIndex(cardUI: ref CardUI) : int =
  if cardUI.tentativeCard.isSome:
    let ent = cardUI.tentativeCard.get
    for i in 0 ..< cardUI.hand.len:
      if cardUI.hand[i].entity == ent:
        return i
  0

method initialize(g: AsciiCardComponent, world: LiveWorld, display: DisplayWorld) =
  g.name = "AsciiCardComponent"

  let ws = display[WindowingSystem]
  let handWidget = ws.desktop.createChild("AsciiCardWidgets", "HandWidget")
  display.attachData(CardUI(
    handWidget: handWidget,
    cardControlHints: descendantByIdentifier(handWidget, "CardControlHints").get,
    cardDefinitionHints: descendantByIdentifier(handWidget, "CardDefinitionHints").get,
    modified: true,
    showHints: true
  ))
  let cardUI = display[CardUI]
  handWidget.bindValue("showHints", display[CardUI].showHints)
  handWidget.takeFocus(world)
  onEvent(handWidget):
    extract(WidgetKeyPress, key, widget, originatingWidget):
      if widget == cardUI.handWidget:
        if key == KeyCode.Tab:
          cardUI.focused = not cardUI.focused
          cardUI.modified = true
        elif key == KeyCode.Left:
          let index = max(tentativeCardIndex(cardUI) - 1, 0)
          cardUI.tentativeCard = some(cardUI.hand[index].entity)
          cardUI.selectedGroup = 0
          cardUI.modified = true
        elif key == KeyCode.Right:
          let index = min(tentativeCardIndex(cardUI) + 1, cardUI.hand.len - 1)
          cardUI.tentativeCard = some(cardUI.hand[index].entity)
          cardUI.selectedGroup = 0
          cardUI.modified = true
        elif key == KeyCode.Up or key == KeyCode.Down:
          let delta = if key == KeyCode.Up: -1 else: 1
          if cardUI.hand.len > 0:
            let tent = cardUI.hand[tentativeCardIndex(cardUI)]
            cardUI.selectedGroup = (cardUI.selectedGroup + tent.textOptions.len + delta) mod (tent.textOptions.len)
            cardUI.modified = true
        elif key == KeyCode.Enter:
          if cardUI.tentativeCard.isSome:
            display.addEvent(CardChosenEvent(card: cardUI.tentativeCard.get, activeGroup: cardUI.selectedGroup))

    extract(KeyRelease, key):
      discard

proc `active=`*(cardUI: ref CardUI, b: bool) =
  if cardUI.active != b:
    cardUI.active = b
    cardUI.modified = true

proc active*(cardUI: ref CardUI): bool = cardUI.active

proc removeUnneededCardWidgets(cardUI: ref CardUI) =
  var handEntities: HashSet[Entity]
  for c in cardUI.hand:
    handEntities.incl(c.entity)

  var toRemove: HashSet[Entity]
  for e,w in cardUI.cardWidgets.mpairs:
    if not handEntities.contains(e):
      w.destroyWidget()
      toRemove.incl(e)

  for e in toRemove:
    cardUI.cardWidgets.del(e)

proc createMissingCardWidgets(cardUI: ref CardUI) =
  var existingWidgets: HashSet[Entity]
  for e,w in cardUI.cardWidgets:
    existingWidgets.incl(e)

  for c in cardUI.hand:
    if not existingWidgets.contains(c.entity):
      let cardWidget = cardUI.handWidget.createChild("AsciiCardWidgets", "CardWidget")
      cardWidget.identifier = &"Card[{c.entity.id}]"
      cardUI.cardWidgets[c.entity] = cardWidget

proc toRichText(c: CardCostB): RichText =
  result = richText($c.cost)
  result.add(c.symbol)
  if c.color.isSome:
    for s in result.sections.mitems:
      s.color = c.color

proc toInternalBinding(c: CardDisplayB, selectedGroup: int) : CardDisplayInternal =
  var cdi : CardDisplayInternal
  cdi.formattedName = c.name
  if c.primaryCost.isSome:
    cdi.primaryCost = toRichText(c.primaryCost.get)
    cdi.hasPrimaryCost = true
  if c.secondaryCost.isSome:
    cdi.secondaryCost = toRichText(c.secondaryCost.get)
    cdi.hasSecondaryCost = true
  cdi.image = c.image
  cdi.hasImage = c.image.isSome
  cdi.textOptions = c.textOptions
  cdi.hasMultipleOptions = c.textOptions.len > 1
  for i in 0 ..< cdi.textOptions.len:
    if i == selectedGroup:
      cdi.textOptions[i].tint = none(RGBA)
    else:
      cdi.textOptions[i].tint = some(rgba(80,80,80,255))
  if c.primaryStats.isSome:
    cdi.primaryStats = c.primaryStats.get
    cdi.hasPrimaryStats = true
  cdi


proc cardYOffset(cardUI: ref CardUI, i: int) : int =
  # yOffset is proportional to the distance from the middle, with some adjustments to deal with even
  # numbered card hands given the low resolution of ascii based rendering. The selected card is
  # always at max height + 2 to help distinguish it
  let maxYOffset = 2 * ((cardUI.hand.len-1) div 2)
  let c = cardUI.hand[i]

  var yOffset = (if i <= cardUI.hand.len div 2: i * 2 else: ((cardUI.hand.len - 1) - i) * 2).min(maxYOffset)
  if cardUI.hand.len mod 2 == 0 and i >= cardUI.hand.len div 2:
    yOffset += 1
  if cardUI.focused and cardUI.tentativeCardIndex == i:
    yOffset = maxYOffset + 2
  yOffset


proc syncCardWidgets(cardUI: ref CardUI) =
  if cardUI.hand.nonEmpty:
    let cardDim = cardUI.cardWidgets[cardUI.hand[0].entity].resolvedDimensions
    let handDim = cardUI.handWidget.resolvedDimensions
    let rawOffsetPer = (handDim.x - cardDim.x - 2) div cardUI.hand.len
    let offsetPer = min(rawOffsetPer, cardDim.x - 4)

    let topIndex = tentativeCardIndex(cardUI)
    var i = 0
    for i in 0 ..< cardUI.hand.len:
      let c = cardUI.hand[i]
      let w = cardUI.cardWidgets[c.entity]
      let selectedGroup = if cardUI.tentativeCard == some(c.entity): cardUI.selectedGroup else: 0
      w.bindValue("card", toInternalBinding(c, selectedGroup))
      w.x = fixedPos(i * offsetPer)
      if cardUI.focused:
        w.y = fixedPos(cardYOffset(cardUI, i), WidgetOrientation.BottomLeft)
      else:
        w.y = fixedPos(cardYOffset(cardUI, i) - w.resolvedDimensions.y + 2, WidgetOrientation.BottomLeft)
      # Z gets further back the further away from the selected index you are
      w.z = absolutePos(cardUI.hand.len + 1 - (topIndex - i).abs)
      if cardUI.tentativeCard == some(c.entity):
        w.data(AsciiWidget).border.color = some(bindable(rgba(120,120,255,255)))
      else:
        w.data(AsciiWidget).border.color = none(Bindable[RGBA])

proc updateHintUI(cardUI: ref CardUI) =
  if cardUI.focused and cardUI.tentativeCard.isSome:
    let i = tentativeCardIndex(cardUI)
    let cardWidget = cardUI.cardWidgets[cardUI.tentativeCard.get]
    cardUI.cardControlHints.bindValue("card", toInternalBinding(cardUI.hand[i], 0))
    cardUI.cardControlHints.x = matchPos(cardWidget.identifier)

    let definitions = cardUI.hand[i].definitions
    cardUI.cardDefinitionHints.bindValue("definitions", definitions)
    cardUI.cardDefinitionHints.bindValue("hasDefinitions", definitions.nonEmpty)
    cardUI.cardDefinitionHints.x = relativePos(cardWidget.identifier, 1, WidgetOrientation.TopRight)
    cardUI.cardDefinitionHints.y = matchPos(cardWidget.identifier)
  else:
    cardUI.cardControlHints.x = fixedPos(0)
    cardUI.cardDefinitionHints.x = fixedPos(0)
    cardUI.cardDefinitionHints.y = fixedPos(0)

proc updateTentativeCard(cardUI: ref CardUI) =
  var containsTentative = false
  for h in cardUI.hand:
    if cardUI.tentativeCard == some(h.entity):
      containsTentative = true
      break

  if not containsTentative:
    cardUI.tentativeCard = none(Entity)
  if cardUI.tentativeCard.isNone:
    if cardUI.hand.nonEmpty:
      cardUI.tentativeCard = some(cardUI.hand[0].entity)


method update(g: AsciiCardComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let cardUI: ref CardUI = display[CardUI]
  if cardUI.modified:
    cardUI.handWidget.bindValue("active", cardUI.active)
    cardUI.handWidget.bindValue("handShowing", cardUI.focused and cardUI.tentativeCard.isSome)
    updateTentativeCard(cardUI)
    removeUnneededCardWidgets(cardUI)
    createMissingCardWidgets(cardUI)
    display[WindowingSystem].updateGeometry()
    syncCardWidgets(cardUI)
    display[WindowingSystem].updateGeometry()
    updateHintUI(cardUI)
    cardUI.modified = false


method onEvent*(g: AsciiCardComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  let cardUI : ref CardUI = display[CardUI]
  if cardUI.active:
    matcher(event):
      extract(KeyPress, key):
        if key == KeyCode.LeftShift or key == KeyCode.RightShift:
          display[WindowingSystem].desktop.bindValue("showDetail", true)
      extract(KeyRelease, key):
        if key == KeyCode.LeftShift or key == KeyCode.RightShift:
          display[WindowingSystem].desktop.bindValue("showDetail", false)



proc hand*(c: ref CardUI): seq[CardDisplayB] = c.hand
proc `hand=`*(c: ref CardUI, h: seq[CardDisplayB]) =
  c.hand = h
  c.modified = true



when isMainModule:
  import main
  import application
  import glm

  type CardTest = ref object of GraphicsComponent


  method initialize(g: CardTest, world: LiveWorld, display: DisplayWorld) =
    g.name = "CardTest"

    display[CardUI].hand = @[CardDisplayB(
                               entity: Entity(id:1),
                               name: richText("A Normal Tree"),
                               image: some(image("hexcrawl/test/tree.png")),
                               primaryCost: some(CardCostB(cost: 1, symbol: richText("G"), color: some(rgba("#369720")))),
                               textOptions: @[richText("Add 3 leaf tokens to a permanent of your choice"), richText("Create a 0/1 seed")],
                               definitions: @[parseRichText("{Token:|[255,255,255,255]} a marker that can be placed on a card in play"),
                                              parseRichText("{Seed:|[255,255,255,255]} a creature that cannot attack or defend, but transforms when it grows over time")]
                             ),CardDisplayB(
                               entity: Entity(id:2),
                               name: richText("Chest"),
                               image: some(image("hexcrawl/test/chest.png")),
                               primaryCost: some(CardCostB(cost: 1, symbol: richText("L"), color: some(rgba("#4d4a47")))),
                               textOptions: @[richText("Gain 2 gold\nExhaust")]
                              ),CardDisplayB(
                               entity: Entity(id:3),
                               name: richText("Bunny Hopper"),
                               image: some(image("hexcrawl/test/bunny.png")),
                               primaryCost: some(CardCostB(cost: 1, symbol: richText("*"), color: some(rgba("#777777")))),
                               textOptions: @[richText("Hop real good")],
                               primaryStats: some(richText("1A/1D"))
                              ),CardDisplayB(
                               entity: Entity(id:4),
                               name: richText("Dragon Head!"),
                               image: some(image("hexcrawl/test/dragonhead.png")),
                               primaryCost: some(CardCostB(cost: 5, symbol: richText("*"), color: some(rgba("#772222")))),
                               textOptions: @[richText("Aaaahhhh! It's a dragon's head! Hopefully that is legible after image conversion")],
                               primaryStats: some(richText("10A/5D"))
                              ),CardDisplayB(
                               entity: Entity(id:5),
                               name: richText("Sword of Stabbing"),
                               image: some(image("hexcrawl/test/sword.png")),
                               primaryCost: some(CardCostB(cost: 2, symbol: richText("S"), color: some(rgba("#cd8311")))),
                               textOptions: @[richText("Equipment\n\nEquipped creature gains +3 stabbing")],
                              )
                              ]

    # let ws = display[WindowingSystem]
    # let cardWidget = createWidgetFromConfig(ws, "Card Widget", config("ui/widgets/AsciiCardWidgets.sml")["CardWidget"], ws.desktop)
    # cardWidget.bindValue("card", CardDisplayB(
    #       name: richText("Test Card"),
    #       image: some(image("hexcrawl/test/tree.png")),
    #       primaryCost: some(CardCostB(cost: 1, symbol: richText("G"), color: some(rgba("#369720")))),
    #       textOptions: @[richText("Add 3 leaf tokens to a permanent of your choice"), richText("Create a 0/1 seed")]
    #     ).toInternalBinding())


  main(GameSetup(
     windowSize: vec2i(1680, 1200),
     resizeable: false,
     windowTitle: "Card Test",
     liveGameComponents: @[],
     graphicsComponents: @[AsciiCanvasComponent(), AsciiWindowingSystemComponent(), AsciiCardComponent(), CardTest()],
     useLiveWorld: true
  ))

