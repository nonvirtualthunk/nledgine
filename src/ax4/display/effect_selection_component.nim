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
import graphics/core
import ax4/game/effect_types
import ax4/game/effects
import ax4/game/root_types
import ax4/game/targeting
import graphics/canvas
import ax4/game/effects
import ax4/display/ax_display_events
import ax4/game/pathfinder
import ax4/display/data/mapGraphicsData
import sugar

{.experimental.}

type
   SelectionContext* = ref object
      playIndex: int
      key: SelectorKey
      selector: Selector
      tentativeSelection: Watchable[Option[SelectionResult]]

   EffectSelectionComponent* = ref object of GraphicsComponent
      worldWatcher: Watcher[WorldEventClock]
      selectedWatcher: Watcher[Option[Entity]]
      activeEffectPlays: ref Option[ref EffectPlayGroup]
      nextSelectionWatcher: Watcher[Option[(int, SelectorKey, Selector)]]
      selectionContext: ref Option[SelectionContext]
      canvas: SimpleCanvas
      onSelectionComplete: (EffectPlayGroup) -> void

   ChooseActiveEffect* = ref object of UIEvent
      effectPlays*: Option[EffectPlayGroup]
      onSelectionComplete*: (EffectPlayGroup) -> void

   SelectionData* = object
      context: ref Option[SelectionContext]
      activeEffectPlays: ref Option[ref EffectPlayGroup]

   SelectionChanged* = ref object of Event


defineDisplayReflection(SelectionData)

proc computeNextSelection(g: EffectSelectionComponent): Option[(int, SelectorKey, Selector)] =
   if g.activeEffectPlays.isSome:
      let plays = g.activeEffectPlays.get.plays
      for i in 0 ..< plays.len:
         let play = plays[i]
         for key, selector in play.selectors:
            if not play.selected.contains(key):
               return some((i, key, selector))

   none((int, SelectorKey, Selector))

proc selectedFor*(s: ref SelectionData, e: Entity): Option[GameEffect] =
   if s.activeEffectPlays.isSome:
      for play in s.activeEffectPlays.get.plays:
         for selection in play.selected.values:
            if selection.selectedEntities.contains(e):
               return some(play.effect)

proc activeSource*(s: ref SelectionData): Option[Entity] =
   s.activeEffectPlays.map(it => it.source)

method initialize(g: EffectSelectionComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "EffectSelectionComponent"

   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")

   g.selectedWatcher = watch: display[TacticalUIData].selectedCharacter
   g.worldWatcher = watch: curView.currentTime
   g.nextSelectionWatcher = watch: g.computeNextSelection()

   g.selectionContext = new Option[SelectionContext]
   g.activeEffectPlays = new Option[ref EffectPlayGroup]
   display.attachData(SelectionData(context: g.selectionContext, activeEffectPlays: g.activeEffectPlays))


proc setEffectPlays(g: EffectSelectionComponent, display: DisplayWorld, effectPlays: Option[EffectPlayGroup]) =
   if effectPlays.isNone:
      g.activeEffectPlays[] = none(ref EffectPlayGroup)
   else:
      let r = new EffectPlayGroup
      r[] = effectPlays.get
      g.activeEffectPlays[] = some(r)
   g.selectionContext[] = none(SelectionContext)
   display.addEvent(SelectionChanged())

proc select(g: EffectSelectionComponent, display: DisplayWorld, res: SelectionResult) =
   if g.selectionContext.isNone:
      warn "Tried to select when there is no active context"
      return
   let ctxt = g.selectionContext.get
   let effectPlays = g.activeEffectPlays.get
   effectPlays.plays[ctxt.playIndex].selected[ctxt.key] = res
   display.addEvent(SelectionChanged())

proc activePlay(g: EffectSelectionComponent): EffectPlay =
   g.activeEffectPlays.get.plays[g.selectionContext.get.playIndex]

proc tentativelySelectHex(g: EffectSelectionComponent, world: World, display: DisplayWorld, hex: AxialVec) =
   if g.selectionContext.isSome and g.activeEffectPlays.isSome:
      withView(world):
         let ctxt = g.selectionContext.get
         let play = g.activePlay()

         case ctxt.selector.kind:
         of SelectionKind.Path:
            let mover = play.selected[Subject()].selectedEntities[0]
            let pf = createPathfinder(world, mover)
            let possiblePath = pf.findPath(PathRequest(fromHex: mover[Physical].position, targetHexes: @[hex]))
            if possiblePath.isSome:
               let truncPath = possiblePath.get.subPath(ctxt.selector.moveRange)
               var tiles: seq[Entity]
               let map = world[Map]
               for pos in truncPath.hexes[1 ..< truncPath.hexes.len]:
                  let tile = map.tileAt(pos)
                  if tile.isSome:
                     tiles.add(tile.get)
                  else:
                     warn "Non-tile encountered when building out tentative path"
               ctxt.tentativeSelection.setTo(some(SelectedEntity(tiles)))
            else:
               ctxt.tentativeSelection.setTo(none(SelectionResult))
         else:
            # doesn't do selection by hex
            discard

proc confirmSelection(g: EffectSelectionComponent, world: World, display: DisplayWorld) =
   if g.selectionContext.isSome and g.activeEffectPlays.isSome:
      let ctxt = g.selectionContext.get
      if ctxt.tentativeSelection.isSome:
         let sel = ctxt.tentativeSelection.get
         g.select(display, sel)



method onEvent(g: EffectSelectionComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   let tuid = display[TacticalUIData]
   let selc = tuid.selectedCharacter

   matchType(event):
      extract(ChooseActiveEffect, effectPlays, onSelectionComplete):
         echo &"Choosing active effect : {effectPlays}"
         g.onSelectionComplete = onSelectionComplete
         g.setEffectPlays(display, effectPlays)
      extract(HexMouseEnter, hex):
         g.tentativelySelectHex(world, display, hex)
      extract(HexMouseRelease):
         g.confirmSelection(world, display)

proc renderTentativeSelection(g: EffectSelectionComponent, view: WorldView, ctxt: SelectionContext, sel: Option[SelectionResult]) =
   if sel.isSome:
      withView(view):
         let sel = sel.get
         case ctxt.selector.kind:
         of SelectionKind.Path:
            var qb = QuadBuilder()
            qb.centered()
            let img = image("ax4/images/ui/hex_selection.png")
            qb.texture = img
            qb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
            let hexSize = mapGraphicsSettings().hexSize.float

            for ent in sel.selectedEntities:
               let hex = ent[Tile].position
               qb.position = hex.asCartVec.Vec3f * hexSize
               qb.dimensions = vec2f(hexSize, hexSize)

               qb.drawTo(g.canvas)
         of SelectionKind.Self:
            discard
         else:
            warn &"Unsupported tentative selection rendering, type: {ctxt.selector.kind}"
   g.canvas.swap()


method update(g: EffectSelectionComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   let selCopt = display[TacticalUIData].selectedCharacter
   if g.worldWatcher.hasChanged or g.selectedWatcher.hasChanged:
      g.setEffectPlays(display, none(EffectPlayGroup))
   if selCopt.isSome:
      let selC = selCopt.get

      let selWatcherChanged = g.nextSelectionWatcher.hasChanged
      if selWatcherChanged:
         let sel = g.nextSelectionWatcher.currentValue
         if sel.isSome:
            let sel = sel.get
            g.selectionContext[] = some(SelectionContext(playIndex: sel[0], key: sel[1], selector: sel[2]))
            display.addEvent(SelectionChanged())
         else:
            if g.activeEffectPlays.isSome:
               echo "Active effeect plays, no pending selections, resolving"
               # this is the point where we have all of our selections chosen, time to resolve
               let effectPlays = g.activeEffectPlays.get
               g.onSelectionComplete(effectPlays[])
               g.canvas.swap()
               g.setEffectPlays(display, none(EffectPlayGroup))
            else:
               echo "next selection changed but no active effect plays (expected only once)"
               discard

      if g.selectionContext.isSome and g.activeEffectPlays.isSome:
         withView(curView):
            let ctx = g.selectionContext.get
            let plays = g.activeEffectPlays.get

            if ctx.tentativeSelection.hasChanged or selWatcherChanged:
               g.renderTentativeSelection(curView, ctx, ctx.tentativeSelection)

            case ctx.selector.kind:
            of SelectionKind.Self:
               g.select(display, SelectedEntity(@[selC]))
            else:
               discard
               # warn &"selection not supported by effect selection component : {ctx.selector.kind}"
   @[g.canvas.drawCommand(display)]

