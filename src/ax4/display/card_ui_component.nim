import engines
import graphics
import prelude
import tables
import ax4/game/map
import hex
import ax4/game/characters
import strformat
import options
import ax4/game/ax_events
import windowingsystem/windowingsystem
import ax4/display/tactical_ui_component
import noto
import ax4/game/cards
import math
import windowingsystem/list_widget
import graphics/core
import ax4/display/effect_selection_component
import ax4/game/effects
import ax4/game/effect_types
import ax4/game/card_display
import core/metrics

type
  CardUIComponent* = ref object of GraphicsComponent
    worldWatcher: Watcher[WorldEventClock]
    selectedWatcher: Watcher[Option[Entity]]
    cardWidgets: Table[Entity, CardWidget]
    heldCard: Option[Entity]
    grabbedPosition: Vec2i
    mousedOverCard: Option[Entity]
    cardActiveOnDrop: bool
    resolvingCard: Option[Entity]
    selectionChanged: bool
    ignoreMouseOverCard: bool
    mostRecentMousedOverIndex: int

  CardWidget* = object
    widget: Widget
    selectedGroup: int
    desiredPos: Vec3i
    currentPos: Vec3f
    initialized: bool

method initialize(g: CardUIComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.name = "CardUIComponent"
  g.eventPriority = 10

  g.selectedWatcher = watch: display[TacticalUIData].selectedCharacter
  g.worldWatcher = watch: curView.currentTime


proc setHeldCard(g: CardUIComponent, c: Option[Entity]) =
  if g.heldCard != c:
    if g.heldCard.isSome:
      if g.cardWidgets.hasKey(g.heldCard.get):
        g.cardWidgets[g.heldCard.get].widget.bindValue("card.active", false)
    g.heldCard = c
    if g.heldCard.isSome:
      disableCursor()
    else:
      enableCursor()

proc effectiveHand(g: CardUIComponent, view: WorldView, display: DisplayWorld): seq[Entity] =
  display.withSelectedCharacter:
    let hand = activeDeck(view, selC).cards.getOrDefault(CardLocation.Hand)
    let selData = display[SelectionData]
    for card in hand:
      if selData.selectedFor(card).isNone and selData.activeSource() != some(card):
        result.add(card)


proc updateCardWidgetBindings(g: CardUIComponent, view: WorldView, display: DisplayWorld, card: Entity, w: CardWidget, selC: Entity) {.gcsafe.} =
  let cardInfo = cardInfoFor(view, selC, card, w.selectedGroup)
  w.widget.bindValue("card", cardInfo)


proc updateCardWidgetDesiredPositions(g: CardUIComponent, view: WorldView, display: DisplayWorld, selC: Entity) =
  withView(view):
    g.mousedOverCard = none(Entity)
    let ws = display[WindowingSystem]

    let cardGap = 125

    let hand = g.effectiveHand(view, display)
    for card, cardWidget in g.cardWidgets.mpairs:
      let index = hand.find(card)
      let w = cardWidget.widget
      if not g.ignoreMouseOverCard and w.containsWidget(ws.lastWidgetUnderMouse) and g.heldCard.isNone:
        g.mousedOverCard = some(card)
        g.mostRecentMousedOverIndex = index

    for card, cardWidget in g.cardWidgets.mpairs:
      let index = hand.find(card)
      let w = cardWidget.widget

      let totalHandWidth = (hand.len-1) * cardGap + w.resolveEffectiveDimension(Axis.X)
      let centeringOffset = (w.parent.get.effectiveClientDimensions.x - totalHandWidth).float * 0.5f

      w.identifier = "CardInHand[" & $index & "]"
      if g.heldCard != some(card):
        cardWidget.desiredPos.x = w.resolvePosition(Axis.X, fixedPos(index * cardGap + centeringOffset.int))

        let indexPcnt = if hand.len > 1: index.float / (hand.len.float - 1.0f) else: 0.5
        let yOffset = sin(indexPcnt*3.14159) * (-170.0 * (hand.len.float/5.0))
        if g.mousedOverCard != some(card) or g.heldCard.isSome:
          if g.mousedOverCard.isSome:
            if index < g.mostRecentMousedOverIndex:
              cardWidget.desiredPos.x -= 200
            elif index > g.mostRecentMousedOverIndex:
              cardWidget.desiredPos.x += 200
          cardWidget.desiredPos.y = w.resolvePosition(Axis.Y, fixedPos(-300, BottomLeft)) + yOffset.int
          cardWidget.desiredPos.z = w.resolvePosition(Axis.Z, fixedPos((100 - (index-g.mostRecentMousedOverIndex).abs * 10)))
        else:
          cardWidget.desiredPos.y = w.resolvePosition(Axis.Y, fixedPos(0, BottomLeft))
          cardWidget.desiredPos.z = w.resolvePosition(Axis.Z, fixedPos(200))

        # if not cardWidget.initialized:
        #   cardWidget.currentPos.x = w.resolvePosition(Axis.X, fixedPos(0)).float
        #   cardWidget.currentPos.y = w.resolvePosition(Axis.Y, fixedPos(-500, BottomLeft)).float
        #   cardWidget.initialized = true



proc heldCardEffectGroups(g: CardUIComponent, view: WorldView) : EffectGroup =
  if g.heldCard.isSome:
    let card = g.heldCard.get
    let cw = g.cardWidgets[card]
    let groupIndex = cw.selectedGroup
    let cardData = card[Card]
    cardData.cardEffectGroups[groupIndex]
  else:
    EffectGroup()


proc activateCard(g: CardUIComponent, card: Entity, world: World, curView: WorldView, display: DisplayWorld) =
  display.withSelectedCharacter:
    g.setHeldCard(none(Entity))
    g.ignoreMouseOverCard = true
    if g.cardActiveOnDrop:
      g.resolvingCard = some(card)

      let cw = g.cardWidgets[card]
      let groupIndex = cw.selectedGroup
      let cardData = card[Card]
      let effectGroup = cardData.cardEffectGroups[groupIndex]

      let playGroup = toEffectPlayGroup(curView, selC, card, effectGroup)
      var valid = true
      for effectPlay in playGroup.plays:
        if effectPlay.isCost:
          if not isEffectPlayable(world, selC, playGroup.source, effectPlay):
            valid = false

      if valid:
        let evt = ChooseActiveEffect(effectPlays: some(playGroup), onSelectionComplete: proc (effectPlays: EffectPlayGroup) =
          playCard(world, selC, card, effectPlays)
        )
        display.addEvent(evt)
      else:
        info &"Not playing card, cannot pay cost"
    updateCardWidgetDesiredPositions(g, curView, display, selC)


proc updateCardWidgetPositions(g: CardUIComponent, world: World, view: WorldView, display: DisplayWorld, selC: Entity, df: float) =
  let ws = display[WindowingSystem]

  if g.heldCard.isSome:
    let heldCard = g.heldCard.get
    if not g.cardWidgets.contains(heldCard):
      g.setHeldCard(none(Entity))
    else:
      g.cardWidgets.withValue(heldCard, w):
        w.desiredPos.x = ws.lastMousePosition.x.int - g.grabbedPosition.x
        w.desiredPos.y = ws.lastMousePosition.y.int - g.grabbedPosition.y
        w.desiredPos.z = 300

        g.cardActiveOnDrop = w.widget.resolvedPosition.y < w.widget.parent.get.resolvedDimensions.y - (w.widget.resolvedDimensions.y.float * 1.25).int
        w.widget.bindValue("card.active", g.cardActiveOnDrop)
        if g.cardActiveOnDrop and heldCardEffectGroups(g, view).requiresSelection(view, selC):
          info "activating card"
          activateCard(g, heldCard, world, view, display)

  for card, cw in g.cardWidgets.mpairs:
    let desiredf = vec3f(cw.desiredPos)
    let delta = desiredf.xy - cw.currentPos.xy
    let mag2 = delta.length2

    if not cw.initialized:
      cw.currentPos.x = desiredf.x
      cw.currentPos.y = desiredf.y
      cw.initialized = true
      cw.widget.x = absolutePos(cw.currentPos.x.round.int)
      cw.widget.y = absolutePos(cw.currentPos.y.round.int)
    elif mag2 > 0.001f:
      let yspeed = 50.0f
      let xspeed = max(20.0f, delta.x/20.0f)
      if g.heldCard == some(card):
        cw.currentPos.xy = desiredf.xy
      else:
        if delta.x.abs < xspeed:
          cw.currentPos.x = desiredf.x
        else:
          cw.currentPos.x += sgn(delta.x).float * xspeed * df

        if delta.y.abs < yspeed:
          cw.currentPos.y = desiredf.y
        else:
          cw.currentPos.y += sgn(delta.y).float * yspeed * df


      # let v = if g.heldCard == some(card): 1000.0f else: max(mag/12.0f, 40.0f)
      # if mag <= v:
      #   cw.currentPos.xy = desiredf.xy
      # else:
      #   cw.currentPos.xy += delta.normalize * v

      cw.widget.x = absolutePos(cw.currentPos.x.round.int)
      cw.widget.y = absolutePos(cw.currentPos.y.round.int)
    cw.widget.z = absolutePos(cw.desiredPos.z)

method onEvent(g: CardUIComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  withView(world):
    let tuid = display[TacticalUIData]
    display.withSelectedCharacter:
      ifOfType(MouseRelease, event):
        if g.heldCard.isSome:
          let card = g.heldCard.get
          event.consume()
          activateCard(g, card, world, curView, display)
      ifOfType(SelectionChanged, event):
        g.selectionChanged = true
      ifOfType(MouseMove, event):
        g.ignoreMouseOverCard = false

  # withWorld(world):
  #   matchType(event):

method update(g: CardUIComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  let selCopt = display[TacticalUIData].selectedCharacter
  let selCChanged = g.selectedWatcher.hasChanged
  if g.worldWatcher.hasChanged or selCChanged or g.selectionChanged:
    if selCChanged:
      g.mousedOverCard = none(Entity)
      g.resolvingCard = none(Entity)
      g.heldCard = none(Entity)
      g.ignoreMouseOverCard = false
    g.selectionChanged = false

    matcher(selCopt):
      caseSome(selC):
        withView(curView):
          let ws = display[WindowingSystem]
          let cards = g.effectiveHand(curView, display)
          var toRemove: seq[Entity]
          for card, cardWidget in g.cardWidgets:
            if not cards.contains(card):
              toRemove.add(card)
          for remCard in toRemove:
            g.cardWidgets[remCard].widget.destroyWidget()
            g.cardWidgets.del(remCard)


          for cardIter in cards:
            let startTime = relTime()
            let card = cardIter
            # the local + capture shouldn't be necessary, but nim 1.4 gets confused if you
            # try to take it directly from the iteration variable
            capture(card):
              let w = g.cardWidgets.getOrCreate(card):
                let widget = ws.desktop.createChild("CardWidgets", "CardWidget")
                widget.y = fixedPos(0, WidgetOrientation.BottomLeft)
                widget.onEventOfTypeW(WidgetMouseMove, move):
                  g.ignoreMouseOverCard = false
                  move.consume()
                widget.onEventOfTypeW(WidgetMouseEnter, enter):
                  updateCardWidgetDesiredPositions(g, curView, display, selC)
                widget.onEventOfTypeW(WidgetMouseExit, exit):
                  updateCardWidgetDesiredPositions(g, curView, display, selC)
                widget.onEventOfTypeW(ListItemMouseOver, listItem):
                  if g.cardWidgets.hasKey(card):
                    g.cardWidgets[card].selectedGroup = listItem.index
                    g.updateCardWidgetBindings(curView, display, card, g.cardWidgets[card], selC)
                widget.onEventOfTypeW(WidgetMousePress, press):
                  g.setHeldCard(some(card))
                  g.grabbedPosition = vec2i(press.relativePosition)
                  disableCursor()

                CardWidget(widget: widget)
              g.updateCardWidgetBindings(curView, display, card, w, selC)
              let endTime = relTime()
          g.updateCardWidgetDesiredPositions(curView, display, selC)

      caseNone:
        for e, w in g.cardWidgets:
          w.widget.destroyWidget()
        g.cardWidgets.clear()
    # update UI
    discard

  if selCopt.isSome:
    # g.updateCardWidgetDesiredPositions(curView, display, selCopt.get)
    g.updateCardWidgetPositions(world, curView, display, selCopt.get, df)

  @[]

