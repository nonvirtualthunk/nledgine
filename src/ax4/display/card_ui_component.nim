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

         let totalHandWidth = (hand.len-1) * cardGap + w.effectiveDimensions.x
         let centeringOffset = (w.parent.get.effectiveClientDimensions.x - totalHandWidth).float * 0.5f

         w.identifier = "CardInHand[" & $index & "]"
         if g.heldCard != some(card):
            if not cardWidget.initialized:
               cardWidget.currentPos.x = w.resolvePosition(Axis.X, fixedPos(0)).float
               cardWidget.currentPos.y = w.resolvePosition(Axis.Y, fixedPos(-500, BottomLeft)).float
               cardWidget.initialized = true


            cardWidget.desiredPos.x = w.resolvePosition(Axis.X, fixedPos(index * cardGap + centeringOffset.int))

            let indexPcnt = if hand.len > 1: index.float / (hand.len.float - 1.0f) else: 0.5
            let yOffset = sin(indexPcnt*3.14159) * (-170.0 * (hand.len.float/5.0))
            if g.mousedOverCard != some(card) or g.heldCard.isSome:
               cardWidget.desiredPos.y = w.resolvePosition(Axis.Y, fixedPos(-300, BottomLeft)) + yOffset.int
               cardWidget.desiredPos.z = w.resolvePosition(Axis.Z, fixedPos((100 - (index-g.mostRecentMousedOverIndex).abs * 10)))
            else:
               cardWidget.desiredPos.y = w.resolvePosition(Axis.Y, fixedPos(0, BottomLeft))
               cardWidget.desiredPos.z = w.resolvePosition(Axis.Z, fixedPos(200))

proc updateCardWidgetPositions(g: CardUIComponent, view: WorldView, display: DisplayWorld, selC: Entity) =
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

   for card, cw in g.cardWidgets.mpairs:
      let desiredf = vec3f(cw.desiredPos)
      let delta = desiredf.xy - cw.currentPos.xy
      let mag2 = delta.length2

      if mag2 > 0.001f:
         let mag = sqrt(mag2)
         let v = if g.heldCard == some(card): 1000.0f else: max(mag/12.0f, 40.0f)
         if mag <= v:
            cw.currentPos.xy = desiredf.xy
         else:
            cw.currentPos.xy += delta.normalize * v

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
               g.setHeldCard(none(Entity))
               g.ignoreMouseOverCard = true
               event.consume()
               if g.cardActiveOnDrop:
                  g.resolvingCard = some(card)

                  let cw = g.cardWidgets[card]
                  let groupIndex = cw.selectedGroup
                  let cardData = card[Card]
                  let effectGroup = cardData.cardEffectGroups[groupIndex]

                  let playGroup = toEffectPlayGroup(injectedView, selC, card, effectGroup)
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
                     echo &"Not playing card, cannot pay cost"
               updateCardWidgetDesiredPositions(g, curView, display, selC)
         ifOfType(SelectionChanged, event):
            g.selectionChanged = true
         ifOfType(MouseMove, event):
            g.ignoreMouseOverCard = false

   # withWorld(world):
   #    matchType(event):

method update(g: CardUIComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   let selCopt = display[TacticalUIData].selectedCharacter
   if g.worldWatcher.hasChanged or g.selectedWatcher.hasChanged or g.selectionChanged:
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
                  let card = cardIter
                  # the local + capture shouldn't be necessary, but nim 1.4 gets confused if you
                  # try to take it directly from the iteration variable
                  capture(card):
                     let w = g.cardWidgets.getOrCreate(card):
                        let widget = ws.desktop.createChild("CardWidgets", "CardWidget")
                        widget.y = fixedPos(0, WidgetOrientation.BottomLeft)
                        widget.onEvent(WidgetMouseMove, move):
                           g.ignoreMouseOverCard = false
                           move.consume()
                        widget.onEvent(WidgetMouseEnter, enter):
                           updateCardWidgetDesiredPositions(g, curView, display, selC)
                        widget.onEvent(WidgetMouseExit, exit):
                           updateCardWidgetDesiredPositions(g, curView, display, selC)
                        widget.onEvent(ListItemMouseOver, listItem):
                           if g.cardWidgets.hasKey(card):
                              g.cardWidgets[card].selectedGroup = listItem.index
                              g.updateCardWidgetBindings(curView, display, card, g.cardWidgets[card], selC)
                        widget.onEvent(WidgetMousePress, press):
                           g.setHeldCard(some(card))
                           g.grabbedPosition = vec2i(press.relativePosition)
                           disableCursor()

                        CardWidget(widget: widget)
                     g.updateCardWidgetBindings(curView, display, card, w, selC)
               g.updateCardWidgetDesiredPositions(curView, display, selC)

         caseNone:
            for e, w in g.cardWidgets:
               w.widget.destroyWidget()
            g.cardWidgets.clear()
      # update UI
      discard

   if selCopt.isSome:
      # g.updateCardWidgetDesiredPositions(curView, display, selCopt.get)
      g.updateCardWidgetPositions(curView, display, selCopt.get)

   @[]

