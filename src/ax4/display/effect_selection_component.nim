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
import ax4/display/ax_display_events
import ax4/game/pathfinder
import ax4/display/data/mapGraphicsData
import sugar
import patty
import sequtils

{.experimental.}

type
  SelectionContext* = ref object
    playIndex: int
    key: SelectorKey
    selector: Selector
    tentativeSelection: Watchable[Option[SelectionResult]]
    # i.e. if you are looking for characters in a shape, this would be the hexes the shape covers
    tentativeBaseSelection: Watchable[Option[SelectionResult]]

  EffectSelectionComponent* = ref object of GraphicsComponent
    worldWatcher: Watcher[WorldEventClock]
    selectedWatcher: Watcher[Option[Entity]]
    activeEffectPlays: ref Option[ref EffectPlayGroup]
    nextSelectionWatcher: Watcher[Option[(int, SelectorKey, Selector)]]
    selectionContext: ref Option[SelectionContext]
    canvas: SimpleCanvas
    onSelectionComplete: (EffectPlayGroup) -> void
    currentMouseHexPosition: AxialVec

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

proc selectedFor*(s: ref SelectionData, e: Entity): Option[SelectableEffects] =
  if s.activeEffectPlays.isSome:
    for play in s.activeEffectPlays.get.plays:
      for selection in play.selected.values:
        if selection.selectedEntities.contains(e):
          return some(play.effects)

proc activeSource*(s: ref SelectionData): Option[Entity] =
  s.activeEffectPlays.map(it => it.source)

method initialize(g: EffectSelectionComponent, world: World, curView: WorldView, display: DisplayWorld) =
  g.name = "EffectSelectionComponent"

  g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
  g.canvas.drawOrder = 15

  g.selectedWatcher = watch: display[TacticalUIData].selectedCharacter
  g.worldWatcher = watch: curView.currentTime
  g.nextSelectionWatcher = watch: g.computeNextSelection()

  g.selectionContext = new Option[SelectionContext]
  g.activeEffectPlays = new Option[ref EffectPlayGroup]
  display.attachData(SelectionData(context: g.selectionContext, activeEffectPlays: g.activeEffectPlays))


proc setEffectPlays(g: EffectSelectionComponent, view: WorldView, display: DisplayWorld, effectPlays: Option[EffectPlayGroup]) =
  if effectPlays.isNone:
    g.activeEffectPlays[] = none(ref EffectPlayGroup)
  else:
    let tuid = display[TacticalUIData]

    let r = new EffectPlayGroup
    r[] = effectPlays.get
    if display[TacticalUIData].selectedCharacter.isSome:
      r.plays = r.plays.filterIt(isConditionMet(view, display[TacticalUIData].selectedCharacter.get, it.effects.condition))
    else:
      warn &"Setting selection without a selected character?"
    g.activeEffectPlays[] = some(r)
  g.selectionContext[] = none(SelectionContext)
  g.canvas.swap()
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


proc charOnHex(view: WorldView, hex: AxialVec): Option[Entity] =
  withView(view):
    for ent in view.entitiesWithData(Character):
      if ent[Physical].position == hex:
        return some(ent)

proc tentativelySelectHex(g: EffectSelectionComponent, world: World, display: DisplayWorld, hex: AxialVec) =
  display.withSelectedCharacter:
    if g.selectionContext.isSome and g.activeEffectPlays.isSome:
      withView(world):
        let map = world[Maps].activeMap[Map]

        let ctxt = g.selectionContext.get
        let play = g.activePlay()

        var newBaseSel: Option[SelectionResult]
        let newSel = case ctxt.selector.kind:
        of SelectionKind.Path:
          let mover = play.selected[Subject()].selectedEntities[0]
          let pf = createPathfinder(world, mover)
          let possiblePath = pf.findPath(PathRequest(fromHex: mover[Physical].position, targetHexes: @[hex]))
          if possiblePath.isSome:
            let truncPath = possiblePath.get.subPath(ctxt.selector.moveRange)
            var tiles: seq[Entity]
            for pos in truncPath.hexes[1 ..< truncPath.hexes.len]:
              let tile = map.tileAt(pos)
              if tile.isSome:
                tiles.add(tile.get)
              else:
                warn "Non-tile encountered when building out tentative path"
            some(SelectedEntity(tiles))
          else:
            none(SelectionResult)
        of SelectionKind.Character:
          charOnHex(world, hex).map((ent: Entity) => SelectedEntity(@[ent]))
        of SelectionKind.CharactersInShape:
          match ctxt.selector.shape:
            Hex:
              map.tileAt(hex).ifPresent:
                newBaseSel = some(SelectedEntity(@[it]))
              charOnHex(world, hex).map((entity: Entity) => SelectedEntity(@[entity]))
            Line(startDist, length):
              let origin = selC[Physical].position

              let dir = sideClosestTo(origin, hex, AxialZero)

              var entities: seq[Entity]
              var hexes: seq[Entity]

              for i in startDist ..< startDist + length:
                let v = origin + axialDelta(dir) * i
                let c = charOnHex(world, v)
                if c.isSome:
                  entities.add(c.get)
                hexes.addOpt(map.tileAt(v))

              info &"Checking characters in shape: {hexes}, {entities}"
              newBaseSel = some(SelectedEntity(hexes))

              if entities.nonEmpty:
                some(SelectedEntity(entities))
              else:
                none(SelectionResult)
        else:
          # doesn't do selection by hex
          ctxt.tentativeSelection

        ctxt.tentativeBaseSelection.setTo(newBaseSel)

        if newSel.isSome:
          if matchesRestriction(world, selC, g.activeEffectPlays.get.source, newSel.get, ctxt.selector.restrictions):
            ctxt.tentativeSelection.setTo(newSel)
        else:
          ctxt.tentativeSelection.setTo(newSel)

proc confirmSelection(g: EffectSelectionComponent, world: World, display: DisplayWorld) =
  if g.selectionContext.isSome and g.activeEffectPlays.isSome:
    let ctxt = g.selectionContext.get
    if ctxt.tentativeSelection.isSome:
      let sel = ctxt.tentativeSelection.get
      g.select(display, sel)



method onEvent(g: EffectSelectionComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  let tuid = display[TacticalUIData]

  matchType(event):
    extract(ChooseActiveEffect, effectPlays, onSelectionComplete):
      info &"Choosing active effect : {effectPlays}"
      g.onSelectionComplete = onSelectionComplete
      g.setEffectPlays(world, display, effectPlays)
      g.tentativelySelectHex(world, display, g.currentMouseHexPosition)
    extract(HexMouseEnter, hex):
      g.currentMouseHexPosition = hex
      g.tentativelySelectHex(world, display, hex)
    extract(HexMouseRelease):
      g.confirmSelection(world, display)
    extract(KeyPress, key):
      if key == KeyCode.Escape:
        g.setEffectPlays(world, display, none(EffectPlayGroup))

proc renderTentativeSelection(g: EffectSelectionComponent, view: WorldView, ctxt: SelectionContext, sel: Option[SelectionResult], baseSel: Option[SelectionResult], selC: Entity) =
  if sel.isSome or baseSel.isSome:
    let hexSize = mapGraphicsSettings().hexSize.float
    var qb = QuadBuilder()
    qb.centered()

    let hexOutline = image("ax4/images/ui/hex_selection.png")
    withView(view):
      if baseSel.isSome:
        let baseSel = baseSel.get
        case ctxt.selector.kind:
        of SelectionKind.CharactersInShape:
          # let scale = ((hexSize*0.5f).int div img.dimensions.x).float
          # let selCPos = selC[Physical].position

          for ent in baseSel.selectedEntities:
            let hex = ent[Tile].position
            qb.texture = hexOutline
            qb.color = rgba(0.75f, 0.1f, 0.2f, 1.0f)
            qb.position = hex.asCartVec.Vec3f * hexSize
            qb.dimensions = vec2f(hexSize, hexSize)
            qb.drawTo(g.canvas)
        else: discard

      if sel.isSome:
        let sel = sel.get
        case ctxt.selector.kind:
        of SelectionKind.Path:

          qb.texture = hexOutline
          qb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)

          for ent in sel.selectedEntities:
            let hex = ent[Tile].position
            qb.position = hex.asCartVec.Vec3f * hexSize
            qb.dimensions = vec2f(hexSize, hexSize)

            qb.drawTo(g.canvas)
        of SelectionKind.Character, SelectionKind.CharactersInShape:
          let img = image("ax4/images/icons/sword1.png")
          let scale = ((hexSize*0.5f).int div img.dimensions.x).float
          let selCPos = selC[Physical].position

          baseSel.ifPresent:
            for ent in it.selectedEntities:
              let hex = ent[Tile].position
              qb.texture = hexOutline
              qb.color = rgba(0.75f, 0.1f, 0.2f, 1.0f)
              qb.position = hex.asCartVec.Vec3f * hexSize
              qb.dimensions = vec2f(hexSize, hexSize)

              qb.drawTo(g.canvas)

          qb.texture = img
          qb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
          for ent in sel.selectedEntities:
            let targetPos = ent[Physical].position
            let pos = (selCPos.asCartVec.Vec3f + targetPos.asCartVec.Vec3f) * 0.5 * hexSize
            qb.position = pos
            qb.dimensions = vec2f(img.dimensions.x.float * scale, img.dimensions.y.float * scale)

            qb.drawTo(g.canvas)


        else:
          warn &"Unsupported tentative selection rendering, type: {ctxt.selector.kind}"
  g.canvas.swap()


method update(g: EffectSelectionComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
  let selCopt = display[TacticalUIData].selectedCharacter
  if g.worldWatcher.hasChanged or g.selectedWatcher.hasChanged:
    g.setEffectPlays(world, display, none(EffectPlayGroup))
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
          fine "Active effect plays, no pending selections, resolving"
          # this is the point where we have all of our selections chosen, time to resolve
          let effectPlays = g.activeEffectPlays.get
          g.onSelectionComplete(effectPlays[])
          g.canvas.swap()
          g.setEffectPlays(world, display, none(EffectPlayGroup))
        else:
          fine "next selection changed but no active effect plays (expected only once)"
          discard

    if g.selectionContext.isSome and g.activeEffectPlays.isSome:
      withView(curView):
        let ctxt = g.selectionContext.get
        let plays = g.activeEffectPlays.get

        if ctxt.tentativeSelection.hasChanged or selWatcherChanged or ctxt.tentativeBaseSelection.hasChanged:
          g.renderTentativeSelection(curView, ctxt, ctxt.tentativeSelection, ctxt.tentativeBaseSelection, selC)

        # todo: make this a more generalized auto-selection when there's only one option, maybe
        for restriction in ctxt.selector.restrictions.asSeq:
          if restriction == Self():
            g.select(display, SelectedEntity(@[selC]))
            break
          if restriction == EffectSource():
            g.select(display, SelectedEntity(@[plays.source]))

  @[g.canvas.drawCommand(display)]

