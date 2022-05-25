import worlds
import prelude
import options
import graphics
import sets
import hashes
import tables
import noto
import arxmath
import windowing_rendering
import config
import strutils
import resources
import arxregex
import engines/event_types
import sugar
import engines/key_codes
import unicode
import algorithm
import nimclipboard/libclipboard
import config/config_binding

export windowing_rendering
export config
export sets

type
  WidgetEdge* = enum
    Left
    Top
    Right
    Bottom

  NineWayImage* = object
    image*: Bindable[ImageRef]
    pixelScale*: int32
    drawCenter*: bool
    dimensionDelta*: Vec2i
    color*: Bindable[RGBA]
    edgeColor*: Bindable[RGBA]
    draw*: Bindable[bool]
    drawEdges*: set[WidgetEdge]

  WidgetOrientation* = enum
    TopLeft
    BottomRight
    TopRight
    BottomLeft
    Center

  WidgetPositionKind {.pure.} = enum
    Fixed
    Absolute
    Proportional
    Centered
    Relative
    Match

  WidgetPosition* = object
    case kind: WidgetPositionKind
    of Fixed:
      fixedOffset: int
      fixedRelativeTo: WidgetOrientation
    of Proportional:
      proportion: float
      proportionalRelativeTo: WidgetOrientation
      proportionalAnchorTo: WidgetOrientation
    of Absolute:
      absoluteOffset: int
      absoluteAnchorTo: WidgetOrientation
    of Centered:
      discard
    of Relative:
      relativeToWidget: string
      relativeOffset: int32
      relativeToWidgetAnchorPoint: WidgetOrientation
    of Match:
      matchWidget: string

  WidgetDimensionKind {.pure.} = enum
    Intrinsic
    Fixed
    Relative
    Proportional
    ExpandToParent
    WrapContent
    ExpandTo

  WidgetDimension* = object
    case kind: WidgetDimensionKind
    of WidgetDimensionKind.Fixed:
      fixedSize: int
    of WidgetDimensionKind.Relative:
      sizeDelta: int
    of WidgetDimensionKind.Proportional:
      sizeProportion: float
    of WidgetDimensionKind.ExpandToParent:
      parentGap: int
    of WidgetDimensionKind.Intrinsic:
      intrinsicMax*: Option[int]
      intrinsicMin*: Option[int]
    of WidgetDimensionKind.WrapContent:
      discard
    of WidgetDimensionKind.ExpandTo:
      expandToWidget: string
      expandToGap: int

  RecalculationFlag* = enum
    DependentX
    DependentY
    DependentZ
    PositionX
    PositionY
    PositionZ
    DimensionsX
    DimensionsY
    Contents

  Widget* = ref object
    # links and references
    windowingSystem*: WindowingSystemRef
    entity: DisplayEntity
    children: seq[Widget]
    dependents: HashSet[Dependent]
    parent_f: Option[Widget]
    identifier*: string
    # core attributes
    background*: NineWayImage
    overlays*: seq[NineWayImage]
    position*: array[3, WidgetPosition]
    resolvedPosition*: Vec3i
    resolvedPartialPosition: Vec3i
    clientOffset*: Vec3i
    padding*: Vec3i # padding contributes to the client offset
    dimensions: array[2, WidgetDimension]
    resolvedDimensions*: Vec2i
    showing_f: seq[Bindable[bool]]
    cursor*: Option[int]
    # drawing caches
    preVertices: seq[WVertex]
    postVertices: seq[WVertex]
    # binding
    bindings: ref Table[string, BoundValue]
    # events
    eventCallbacks: seq[(UIEvent, World, DisplayWorld) -> void]
    liveWorldEventCallbacks: seq[(UIEvent, LiveWorld, DisplayWorld) -> void]
    acceptsFocus*: bool
    destroyed*: bool
    ignoreMissingRelativePosition*: bool

  WidgetArchetype* = object
    widgetData: Widget
    children: Table[string, WidgetArchetype]


  DependencyKind = enum
    Position
    PartialPosition
    Dimensions

  Dependency = tuple
    widget: Widget
    kind: DependencyKind
    axis: Axis

  Dependent = tuple
    dependentWidget: Widget
    dependsOnKind: DependencyKind
    sourceKind: DependencyKind
    dependsOnAxis: Axis
    sourceAxis: Axis

  RecalculationFlatSet = set[RecalculationFlag]


  WindowingSystem* = object
    display*: DisplayWorld
    desktop*: Widget
    pixelScale*: int
    dimensions*: Vec2i
    components*: seq[WindowingComponent]
    rootConfigPath*: string

    # indicates whether the windowing system is using a custom renderer (i.e. ascii)
    customRenderer*: bool

    # standard tilesheet to apply as defaults
    stylesheet*: ConfigValue

    # recomputaton
    renderRevision: int
    pendingUpdates: Table[Widget, RecalculationFlatSet]
    rerenderSet: HashSet[Widget]

    # event handling
    focusedWidget*: Option[Widget]
    lastWidgetUnderMouse*: Widget
    lastMousePosition*: Vec2f

    # optimization metrics tracking
    updateDependentsCount: int
    updateDimensionsCount: int
    updatePositionCount: int
    renderContentsCount: int

    # cached widget archetypes
    widgetArchetypes: Table[string, WidgetArchetype]

    # os interaction
    clipboard*: ptr clipboard_c


  WindowingSystemRef* = ref WindowingSystem

  WindowingComponent* = ref object of RootRef

  WidgetArchetypeIdentifier* = object
    location: string
    identifier: string

  WidgetEvent* = ref object of InputEvent
    i_originatingWidget: Widget
    widget*: Widget
    nonPropagating*: bool

  WidgetMouseMove* = ref object of WidgetEvent
    position*: Vec2f
  WidgetMouseDrag* = ref object of WidgetEvent
    button*: MouseButton
    position*: Vec2f
    origin*: Vec2f
  WidgetMouseEnter* = ref object of WidgetEvent
  WidgetMouseExit* = ref object of WidgetEvent

  WidgetMousePress* = ref object of WidgetEvent
    button*: MouseButton
    position*: Vec2f
    doublePress*: bool

  WidgetMouseRelease* = ref object of WidgetEvent
    button*: MouseButton
    position*: Vec2f

  WidgetKeyPress* = ref object of WidgetEvent
    key*: KeyCode
    repeat*: bool
  WidgetKeyRelease* = ref object of WidgetEvent
    key*: KeyCode
  WidgetRuneEnter* = ref object of WidgetEvent
    rune*: Rune
  WidgetFocusGain* = ref object of WidgetEvent
  WidgetFocusLoss* = ref object of WidgetEvent


defineDisplayReflection(WindowingSystem)



proc `$`*(w: Widget): string =
  if w.identifier.len > 0:
    "Widget(" & w.identifier & ")"
  else:
    "Widget(" & $w.entity.id & ")"



method toString*(evt: WidgetEvent) : string =
  "WidgetEvent(?)"

eventToStr(WidgetFocusLoss)
eventToStr(WidgetFocusGain)
eventToStr(WidgetRuneEnter)
eventToStr(WidgetKeyRelease)
eventToStr(WidgetKeyPress)
eventToStr(WidgetMouseRelease)
eventToStr(WidgetMousePress)
eventToStr(WidgetMouseExit)
eventToStr(WidgetMouseEnter)
eventToStr(WidgetMouseDrag)
eventToStr(WidgetMouseMove)

const AllEdges = {WidgetEdge.Left, WidgetEdge.Top, WidgetEdge.Right, WidgetEdge.Bottom}

proc childByIdentifier*(e: Widget, identifier: string): Option[Widget] =
  for c in e.children:
    if c.identifier == identifier:
      return some(c)
  none(Widget)

proc descendantByIdentifier*(e: Widget, identifier: string): Option[Widget] =
  let childMatch = e.childByIdentifier(identifier)
  if childMatch.isSome:
    childMatch
  else:
    for c in e.children:
      let descMatch = c.descendantByIdentifier(identifier)
      if descMatch.isSome:
        return descMatch
    none(Widget)

iterator descendantsMatching*(e: Widget, predicate : (Widget) -> bool): Widget =
  var descendantStack = e.children
  while descendantStack.nonEmpty:
    let c = descendantStack.pop()
    if predicate(c):
      yield c
    for subChild in c.children:
      descendantStack.add(subChild)

iterator descendantsWithData*[T](e: Widget, dataType : typedesc[T]): Widget =
  for c in descendantsMatching(e, w => w.hasData(dataType)):
    yield c


proc isDescendantOf*(w: Widget, target: Widget): bool =
  if w.parent_f.isSome:
    if w.parent_f.get == target:
      true
    else:
      isDescendantOf(w.parent_f.get, target)
  else:
    false

proc isDescendantOf*(w: Widget, target: string): bool =
  if w.parent_f.isSome:
    if w.parent_f.get.identifier == target:
      true
    else:
      isDescendantOf(w.parent_f.get, target)
  else:
    false

proc isSelfOrDescendantOf*(w: Widget, target: string): bool =
  if w.identifier == target:
    true
  else:
    isDescendantOf(w, target)

proc isSelfOrDescendantOf*(w: Widget, target: Widget): bool =
  if w == target:
    true
  else:
    isDescendantOf(w, target)

proc isEmpty*(w: WidgetArchetypeIdentifier): bool =
  w.location.isEmpty or w.identifier.isEmpty

proc children*(w: Widget): seq[Widget] = w.children

proc giveWidgetFocus*[WorldType](ws: WindowingSystemRef, world: WorldType, widget: Widget)

proc takeFocus*[WorldType](w: Widget, world: WorldType) =
  w.windowingSystem.giveWidgetFocus(world, w)

# =========================================================================================

method render*(ws: WindowingComponent, widget: Widget): seq[WQuad] {.base.} =
  warn "WindowingComponent must implement render"

method customRender*(ws: WindowingComponent, display: DisplayWorld, widget: Widget, tb: TextureBlock, bounds: Bounds) {.base.} =
  warn "WindowingComponent must implement customRender"

method intrinsicSize*(ws: WindowingComponent, widget: Widget, axis: Axis, minimums: Vec2i, maximums: Vec2i): Option[int] {.base.} =
  none(int)

method clientOffset*(ws: WindowingComponent, widget: Widget, axis: Axis): Option[Vec3i] {.base.} =
  none(Vec3i)

method readDataFromConfig*(ws: WindowingComponent, cv: ConfigValue, widget: Widget) {.base.} =
  discard

method updateBindings*(ws: WindowingComponent, widget: Widget, resolver: var BoundValueResolver) {.base.} =
  discard

method handleEvent*(ws: WindowingComponent, widget: Widget, event: UIEvent, display: DisplayWorld) {.base.} =
  discard

method onCreated*(ws: WindowingComponent, widget: Widget) {.base.} =
  discard


proc renderContents(ws: WindowingSystemRef, w: Widget, tb: TextureBlock, bounds: Bounds)
proc customRenderContents(ws: WindowingSystemRef, display: DisplayWorld, w: Widget, tb: TextureBlock, bounds: Bounds)

var imageMetrics {.threadvar.}: Table[Image, ImageMetrics]
proc imageMetricsFor*(img: Image): ImageMetrics =
  if not imageMetrics.contains(img):
    var metrics = ImageMetrics()

    while metrics.outerOffset < img.width and img[metrics.outerOffset, img.height div 2, 3] == 0:
      metrics.outerOffset += 1
    # if it is entirely transparent, treat it as having no offset
    if metrics.outerOffset == img.width:
      metrics.outerOffset = 0

    metrics.borderWidth = metrics.outerOffset
    while metrics.borderWidth < img.width and img[metrics.borderWidth, img.height div 2, 3] > 0:
      metrics.borderWidth += 1
    # if it is entirely transparent, treat it as having no border
    if metrics.borderWidth == img.width:
      metrics.borderWidth = 0

    metrics.centerColor = img[img.width - 1, 0][]
    imageMetrics[img] = metrics
  imageMetrics[img]


proc isIntrinsic*(dim: WidgetDimension): bool = dim.kind == WidgetDimensionKind.Intrinsic

proc nineWayImage*(img: ImageRef, pixelScale: int = 1, color: RGBA = rgba(1.0f, 1.0f, 1.0f, 1.0f), edges: set[WidgetEdge] = AllEdges): NineWayImage =
  NineWayImage(
    image: bindable(img),
    pixelScale: pixelScale.int32,
    color: bindable(color),
    edgeColor: bindable(color),
    draw: bindable(true),
    drawCenter: true,
    drawEdges: edges
  )

iterator quadToVertices(quad: WQuad, tb: TextureBlock, bounds: Bounds): WVertex =
  var tc: array[4, Vec2f]
  case quad.texCoords.kind:
  of WTexCoordKind.NoImage:
    tc = tb.blankTexCoords()[]
  of WTexCoordKind.SubRect:
    let subRect = quad.texCoords.subRect
    let imgData = tb.imageData(quad.image)
    # let min = imgData.texPosition + imgData.texDimensions * subRect.position
    # let max = imgData.texPosition + imgData.texDimensions * (subRect.position + subRect.dimensions)
    # [min, vec2f(max.x, min.y), max, vec2f(min.x, max.y)]
    for q in 0 ..< 4:
      tc[q] = imgData.texPosition + (subRect.position + subRect.dimensions * UnitSquareVertices2d[q]) * imgData.texDimensions
    if quad.texCoords.flipSubRect.x:
      swap(tc[0], tc[1])
      swap(tc[2], tc[3])
    if quad.texCoords.flipSubRect.y:
      swap(tc[0], tc[3])
      swap(tc[1], tc[2])
  of WTexCoordKind.RawTexCoords:
    tc = quad.texCoords.rawTexCoords
  of WTexCoordKind.NormalizedTexCoords:
    let imgData = tb.imageData(quad.image)
    let base = quad.texCoords.texCoords
    for q in 0 ..< 4:
      tc[q] = imgData.texPosition + imgData.texDimensions * base[q]
  of WTexCoordKind.Simple:
    tc = tb[quad.image][]
    if quad.texCoords.flip.x:
      swap(tc[0], tc[1])
      swap(tc[2], tc[3])
    if quad.texCoords.flip.y:
      swap(tc[0], tc[3])
      swap(tc[1], tc[2])


  case quad.shape.kind:
    of WShapeKind.Rect:
      let pos = vec3f(quad.shape.position)
      let dim = vec2f(quad.shape.dimensions)
      let fwd = vec3f(quad.shape.forward.x, quad.shape.forward.y, 0.0f)
      let oto = vec3f(-fwd.y, fwd.x, 0.0f)


      yield WVertex(vertex: pos, color: quad.color, texCoords: tc[3], boundsOrigin: bounds.origin, boundsDirection: bounds.direction, boundsDimensions: bounds.dimensions)
      yield WVertex(vertex: pos + fwd * dim.x, color: quad.color, texCoords: tc[2], boundsOrigin: bounds.origin, boundsDirection: bounds.direction, boundsDimensions: bounds.dimensions)
      yield WVertex(vertex: pos + fwd * dim.x + oto * dim.y, color: quad.color, texCoords: tc[1], boundsOrigin: bounds.origin, boundsDirection: bounds.direction, boundsDimensions: bounds.dimensions)
      yield WVertex(vertex: pos + oto * dim.y, color: quad.color, texCoords: tc[0], boundsOrigin: bounds.origin, boundsDirection: bounds.direction, boundsDimensions: bounds.dimensions)
    of WShapeKind.Polygon:
      for i in 0 ..< 4:
        yield WVertex(vertex: quad.shape.points[i], color: quad.color, texCoords: tc[3-i], boundsOrigin: bounds.origin, boundsDirection: bounds.direction, boundsDimensions: bounds.dimensions)

proc fixedSize*(size: int): WidgetDimension = WidgetDimension(kind: WidgetDimensionKind.Fixed, fixedSize: size)
proc relativeSize*(sizeDelta: int): WidgetDimension = WidgetDimension(kind: WidgetDimensionKind.Relative, sizeDelta: sizeDelta)
proc proportionalSize*(proportion: float): WidgetDimension = WidgetDimension(kind: WidgetDimensionKind.Proportional, sizeProportion: proportion)
proc wrapContent*(): WidgetDimension = WidgetDimension(kind: WidgetDimensionKind.WrapContent)
proc expandToParent*(gap: int = 0): WidgetDimension = WidgetDimension(kind: WidgetDimensionKind.ExpandToParent, parentGap: gap)
proc expandToWidget*(expandTo: string, gap: int = 0): WidgetDimension = WidgetDimension(kind: WidgetDimensionKind.ExpandTo, expandToWidget: expandTo,  expandToGap: gap)
proc intrinsic*(): WidgetDimension = WidgetDimension(kind: WidgetDimensionKind.Intrinsic)

proc centered*(): WidgetPosition = WidgetPosition(kind: WidgetPositionKind.Centered)
proc absolutePos*(pos: int, absoluteAnchorTo: WidgetOrientation = WidgetOrientation.TopLeft): WidgetPosition = WidgetPosition(kind: WidgetPositionKind.Absolute, absoluteOffset: pos,
    absoluteAnchorTo: absoluteAnchorTo)
proc fixedPos*(pos: int, relativeTo: WidgetOrientation = WidgetOrientation.TopLeft): WidgetPosition = WidgetPosition(kind: WidgetPositionKind.Fixed, fixedOffset: pos, fixedRelativeTo: relativeTo)
proc proportionalPos*(proportion: float, relativeTo: WidgetOrientation = WidgetOrientation.TopLeft, anchorTo: WidgetOrientation = WidgetOrientation.TopLeft): WidgetPosition =
  WidgetPosition(kind: WidgetPositionKind.Proportional, proportion: proportion, proportionalRelativeTo: relativeTo, proportionalAnchorTo: anchorTo)
proc relativePos*(relativeTo: string, offset: int32, anchorPoint: WidgetOrientation = WidgetOrientation.TopLeft): WidgetPosition =
  WidgetPosition(kind: WidgetPositionKind.Relative, relativeToWidget: relativeTo, relativeOffset: offset, relativeToWidgetAnchorPoint: anchorPoint)
proc relativePos*(relativeTo: string, offset: int, anchorPoint: WidgetOrientation = WidgetOrientation.TopLeft): WidgetPosition =
  WidgetPosition(kind: WidgetPositionKind.Relative, relativeToWidget: relativeTo, relativeOffset: offset.int32, relativeToWidgetAnchorPoint: anchorPoint)
proc matchPos*(matchTo: string): WidgetPosition =
  WidgetPosition(kind: WidgetPositionKind.Match, matchWidget: matchTo)

proc hash*(w: Widget): Hash = w.entity.hash
proc `==`*(a, b: Widget): bool =
  if a.isNil or b.isNil:
    a.isNil and b.isNil
  else:
    a.entity == b.entity

proc `==`*(a, b: WidgetPosition): bool =
  if a.kind != b.kind: return false

  case a.kind:
  of WidgetPositionKind.Fixed:
    a.fixedOffset == b.fixedOffset and a.fixedRelativeTo == b.fixedRelativeTo
  of WidgetPositionKind.Proportional:
    a.proportion == b.proportion and a.proportionalRelativeTo == b.proportionalRelativeTo and a.proportionalAnchorTo == b.proportionalAnchorTo
  of WidgetPositionKind.Absolute:
    a.absoluteOffset == b.absoluteOffset and a.absoluteAnchorTo == b.absoluteAnchorTo
  of WidgetPositionKind.Centered:
    true
  of WidgetPositionKind.Relative:
    a.relativeToWidget == b.relativeToWidget and a.relativeOffset == b.relativeOffset and a.relativeToWidgetAnchorPoint == b.relativeToWidgetAnchorPoint
  of WidgetPositionKind.Match:
    a.matchWidget == b.matchWidget

proc `==`*(a, b: WidgetDimension): bool =
  if a.kind != b.kind: return false

  case a.kind:
  of WidgetDimensionKind.Fixed:
    a.fixedSize == b.fixedSize
  of WidgetDimensionKind.Relative:
    a.sizeDelta == b.sizeDelta
  of WidgetDimensionKind.Proportional:
    a.sizeProportion == b.sizeProportion
  of WidgetDimensionKind.ExpandToParent:
    a.parentGap == b.parentGap
  of WidgetDimensionKind.Intrinsic:
    a.intrinsicMin == b.intrinsicMin and a.intrinsicMax == b.intrinsicMax
  of WidgetDimensionKind.WrapContent:
    true
  of WidgetDimensionKind.ExpandTo:
    a.expandToWidget == b.expandToWidget and a.expandToGap == b.expandToGap

proc markForUpdate*(ws: WindowingSystemRef, w: Widget, r: RecalculationFlag) =
  fine &"marking for update : {w.entity} {r}"
  ws.pendingUpdates.mgetOrPut(w, {}).incl(r)

proc markForUpdate*(w: Widget, r: RecalculationFlag) =
  if not w.windowingSystem.isNil:
    w.windowingSystem.markForUpdate(w, r)

proc isMarkedForUpdate*(w: Widget, r: RecalculationFlag) : bool =
  if not w.windowingSystem.isNil:
    w.windowingSystem.pendingUpdates.getOrDefault(w).contains(r)
  else:
    false

proc isFarSide(axis: Axis, relativeTo: WidgetOrientation): bool =
  (axis == Axis.X and (relativeTo == TopRight or relativeTo == BottomRight)) or
  (axis == Axis.Y and (relativeTo == BottomRight or relativeTo == BottomLeft))


iterator dependentOn(p: WidgetPosition, axis: Axis, widget: Widget, parent: Widget): Dependency =
  case p.kind:
  of WidgetPositionKind.Fixed:
    yield (widget: parent, kind: DependencyKind.Position, axis: axis)
    if isFarSide(axis, p.fixedRelativeTo):
      yield (widget: parent, kind: DependencyKind.Dimensions, axis: axis)
      yield (widget: widget, kind: DependencyKind.Dimensions, axis: axis)
  of WidgetPositionKind.Proportional:
    yield (widget: parent, kind: DependencyKind.Dimensions, axis: axis)
    yield (widget: parent, kind: DependencyKind.Position, axis: axis)
    if isFarSide(axis, p.proportionalRelativeTo) or p.proportionalAnchorTo == WidgetOrientation.Center:
      yield (widget: widget, kind: DependencyKind.Dimensions, axis: axis)
  of WidgetPositionKind.Centered:
    yield (widget: parent, kind: DependencyKind.Dimensions, axis: axis)
    yield (widget: parent, kind: DependencyKind.Position, axis: axis)
    yield (widget: widget, kind: DependencyKind.Dimensions, axis: axis)
  of WidgetPositionKind.Relative:
    let relativeWidget = parent.childByIdentifier(p.relativeToWidget)
    if relativeWidget.isSome:
      yield (widget: relativeWidget.get, kind: DependencyKind.Position, axis: axis)
      yield (widget: relativeWidget.get, kind: DependencyKind.Dimensions, axis: axis)
    else:
      if not widget.ignoreMissingRelativePosition:
        warn &"Relative positioning with target {p.relativeToWidget} on widget {widget.identifier}, but no matching relative widget found"

    if not isFarSide(axis, p.relativeToWidgetAnchorPoint):
      yield (widget: widget, kind: DependencyKind.Dimensions, axis: axis)
  of WidgetPositionKind.Match:
    let matchWidget = parent.childByIdentifier(p.matchWidget)
    if matchWidget.isSome:
      yield (widget: matchWidget.get, kind: DependencyKind.Position, axis: axis)
    else:
      if not widget.ignoreMissingRelativePosition:
        warn &"Matched position did not find corresponding widget {p.matchWidget} to match to"
  of WidgetPositionKind.Absolute:
    if isFarSide(axis, p.absoluteAnchorTo) or p.absoluteAnchorTo == WidgetOrientation.Center:
      yield (widget: widget, kind: DependencyKind.Dimensions, axis: axis)
    discard

iterator dependentOn(p: WidgetDimension, axis: Axis, widget: Widget, parent: Widget, children: seq[Widget]): Dependency =
  case p.kind:
    of WidgetDimensionKind.Fixed:
      discard
    of WidgetDimensionKind.Proportional, WidgetDimensionKind.Relative:
      yield (widget: parent, kind: DependencyKind.Dimensions, axis: axis)
    of WidgetDimensionKind.ExpandToParent:
      yield (widget: parent, kind: DependencyKind.Dimensions, axis: axis)
      yield (widget: widget, kind: DependencyKind.Position, axis: axis)
    of WidgetDimensionKind.Intrinsic:
      if not widget.dimensions[axis.oppositeAxis2d().ord].isIntrinsic:
        yield (widget: widget, kind: DependencyKind.Dimensions, axis: axis.oppositeAxis2d())
    of WidgetDimensionKind.WrapContent:
      for c in children:
        yield (widget: c, kind: DependencyKind.PartialPosition, axis: axis)
        yield (widget: c, kind: DependencyKind.Dimensions, axis: axis)
    of WidgetDimensionKind.ExpandTo:
      let expandToWidget = parent.childByIdentifier(p.expandToWidget)
      if expandToWidget.isSome:
        yield (widget: expandToWidget.get, kind: DependencyKind.Position, axis: axis)
        yield (widget: expandToWidget.get, kind: DependencyKind.Dimensions, axis: axis) # todo: this could probably be tightened up a little bit
      else:
        warn &"ExpandTo dimension with target {p.expandToWidget} on widget {widget.identifier}, but no matching widget found"


proc toDependent(w: Widget, srcAxis: Axis, srcKind: DependencyKind, dep: Dependency): Dependent =
  (dependentWidget: w, dependsOnKind: dep.kind, sourceKind: srcKind, dependsOnAxis: dep.axis, sourceAxis: srcAxis)

proc initializeWidgetBindings(widget: Widget)

proc parent*(w: Widget): Option[Widget] = w.parent_f

proc `parent=`*(w: Widget, parent: Option[Widget]) =
  if parent != w.parent_f:
    if w.parent_f.isSome:
      let oldP = w.parent_f.get
      for i in 0 ..< oldP.children.len:
        if oldP.children[i] == w:
          oldP.children.del(i)
          break
      for e in enumValues(RecalculationFlag): oldP.markForUpdate(e)

    w.parent_f = parent
    if parent.isSome:
      parent.get.children.add(w)
      for e in enumValues(RecalculationFlag): parent.get.markForUpdate(e)
    for e in enumValues(RecalculationFlag): w.markForUpdate(e)

    # might need up re-initialize some bindings at this point


proc `parent=`*(w: Widget, parent: Widget) =
  w.parent = some(parent)

proc createWidgetFromArchetype*(ws: WindowingSystemRef, archetype: WidgetArchetype, identifier: string, parent: Widget = nil): Widget =
  result = new Widget
  result[] = archetype.widgetData[]
  result.identifier = identifier
  result.windowingSystem = ws
  result.entity = ws.display.copyEntity(archetype.widgetData.entity)
  if parent.isNil:
    result.parent = ws.desktop
  else:
    result.parent = parent

  for childIdentifier, childArchetype in archetype.children:
    let newChild = ws.createWidgetFromArchetype(childArchetype, childIdentifier, result)

  for comp in ws.components:
    comp.onCreated(result)


proc createWidget*(ws: WindowingSystemRef, parent: Widget = nil): Widget =
  result = new Widget
  result.windowingSystem = ws
  result.entity = ws.display.createEntity()
  if parent.isNil:
    result.parent = ws.desktop
  else:
    result.parent = parent

  for comp in ws.components:
    comp.onCreated(result)


proc `x=`*(w: Widget, p: WidgetPosition) =
  if w.position[0] != p:
    w.position[0] = p
    w.markForUpdate(RecalculationFlag.PositionX)
    w.markForUpdate(RecalculationFlag.DependentX)
  # w.markForUpdate(Axis.X)

proc `y=`*(w: Widget, p: WidgetPosition) =
  if w.position[1] != p:
    w.position[1] = p
    w.markForUpdate(RecalculationFlag.PositionY)
    w.markForUpdate(RecalculationFlag.DependentY)
  # w.markForUpdate(Axis.Y)

proc `z=`*(w: Widget, p: WidgetPosition) =
  if w.position[2] != p:
    w.position[2] = p
    w.markForUpdate(RecalculationFlag.PositionZ)
    w.markForUpdate(RecalculationFlag.DependentZ)
  # w.markForUpdate(Axis.Z)

proc `width=`*(w: Widget, p: WidgetDimension) =
  if w.dimensions[0] != p:
    w.dimensions[0] = p
    w.markForUpdate(RecalculationFlag.DimensionsX)
    w.markForUpdate(RecalculationFlag.DependentX)
  # w.markForUpdate(Axis.X)

proc `height=`*(w: Widget, p: WidgetDimension) =
  if w.dimensions[1] != p:
    w.dimensions[1] = p
    w.markForUpdate(RecalculationFlag.DimensionsY)
    w.markForUpdate(RecalculationFlag.DependentY)
  # w.markForUpdate(Axis.Y)

proc `showing=`*(w: Widget, b: Bindable[bool]) =
  if w.showing_f != @[b]:
    w.showing_f = @[b]
    for e in enumValues(RecalculationFlag): w.markForUpdate(e)

proc showing*(w: Widget): bool =
  for b in w.showing_f:
    if not b:
      return false
  true

proc width*(w: Widget): WidgetDimension = w.dimensions[0]
proc height*(w: Widget): WidgetDimension = w.dimensions[1]

# converter toEntity* (w : Widget) : DisplayEntity = w.entity

proc recalculateDependents(w: Widget, axis: Axis) =
  if w.parent.isSome:
    fine &"recalculating dependents for widget {w.entity} {axis}"

    for dep in dependentOn(w.position[axis.ord], axis, w, w.parent.get):
      dep.widget.dependents.incl(toDependent(w, axis, DependencyKind.Position, dep))
    if axis == Axis.X or axis == Axis.Y:
      for dep in dependentOn(w.dimensions[axis.ord], axis, w, w.parent.get, w.children):
        dep.widget.dependents.incl(toDependent(w, axis, DependencyKind.Dimensions, dep))





proc posFlag(axis: Axis): RecalculationFlag =
  case axis:
  of Axis.X: RecalculationFlag.PositionX
  of Axis.Y: RecalculationFlag.PositionY
  of Axis.Z: RecalculationFlag.PositionZ

proc dimFlag(axis: Axis): RecalculationFlag =
  case axis:
  of Axis.X: RecalculationFlag.DimensionsX
  of Axis.Y: RecalculationFlag.DimensionsY
  of Axis.Z:
    warn "no z dimension flag"
    RecalculationFlag.DimensionsY

proc depFlag(axis: Axis): RecalculationFlag =
  case axis:
  of Axis.X: RecalculationFlag.DependentX
  of Axis.Y: RecalculationFlag.DependentY
  of Axis.Z: RecalculationFlag.DependentZ

proc ensureDependency(dep: Dependency, dirtySet: HashSet[Dependency], completedSet: var HashSet[Dependency]) {.gcsafe.}
# proc updateDependent(dep : Dependent, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency])

proc recalculatePartialPosition(w: Widget, axis: Axis, dirtySet: HashSet[Dependency], completedSet: var HashSet[Dependency]) =
  let completedKey = (widget: w, kind: DependencyKind.PartialPosition, axis: axis)
  if completedSet.containsOrIncl(completedKey):
    return
  fine &"recalculating partial position for widget {w.entity} {axis}"

  let pos = w.position[axis.ord]
  if w.parent.isSome:
    w.resolvedPartialPosition[axis] = case pos.kind:
    of WidgetPositionKind.Fixed:
      if isFarSide(axis, pos.fixedRelativeTo):
        0
      else:
        pos.fixedOffset * w.windowingSystem.pixelScale
    of WidgetPositionKind.Proportional:
      0
    of WidgetPositionKind.Centered:
      0
    of WidgetPositionKind.Relative:
      let relativeToWidget = w.parent.get.childByIdentifier(pos.relativeToWidget)
      if relativeToWidget.isSome:
        ensureDependency((widget: relativeToWidget.get, kind: DependencyKind.PartialPosition, axis: axis), dirtySet, completedSet)
        if isFarSide(axis, pos.relativeToWidgetAnchorPoint):
          ensureDependency((widget: relativeToWidget.get, kind: DependencyKind.Dimensions, axis: axis), dirtySet, completedSet)
          relativeToWidget.get.resolvedPartialPosition[axis] + relativeToWidget.get.resolvedDimensions[axis] + pos.relativeOffset * w.windowingSystem.pixelScale
        else:
          ensureDependency((widget: w, kind: DependencyKind.Dimensions, axis: axis), dirtySet, completedSet)
          relativeToWidget.get.resolvedPartialPosition[axis] - pos.relativeOffset * w.windowingSystem.pixelScale - w.resolvedDimensions[axis]
      else:
        warn &"Partial position resolution looked for relative widget {pos.relativeToWidget} on widget {w.identifier} but no relative widget found"
        0
    of WidgetPositionKind.Match:
      let matchWidget = w.parent.get.childByIdentifier(pos.matchWidget)
      if matchWidget.isSome:
        ensureDependency((widget: matchWidget.get, kind: DependencyKind.PartialPosition, axis: axis), dirtySet, completedSet)
        matchWidget.get.resolvedPartialPosition[axis]
      else:
        warn &"Partial position resolution looked for match widget {pos.matchWidget} on widget {w.identifier} but no match widget found"
        0
    of WidgetPositionKind.Absolute:
      pos.absoluteOffset



proc resolvePositionValue(w: Widget, axis: Axis, pos: WidgetPosition): int =
  let parentV = w.parent.get.resolvedPosition[axis] + w.parent.get.clientOffset[axis]
  let parentD = if axis.is2D(): w.parent.get.resolvedDimensions[axis] - w.parent.get.clientOffset[axis] * 2 else: 10
  case pos.kind:
  of WidgetPositionKind.Fixed:
    if isFarSide(axis, pos.fixedRelativeTo):
      parentV + parentD - (pos.fixedOffset * w.windowingSystem.pixelScale) - w.resolvedDimensions[axis]
    else:
      parentV + pos.fixedOffset * w.windowingSystem.pixelScale
  of WidgetPositionKind.Proportional:
    var primaryPoint = if isFarSide(axis, pos.proportionalRelativeTo):
      parentV + parentD - (parentD.float * pos.proportion).int - w.resolvedDimensions[axis]
    else:
      if axis == Axis.Y: echo fmt"parentD: {parentD}, proportion: {pos.proportion}"
      parentV + (parentD.float * pos.proportion).int

    # if the widget is anchored at the center, shift so the primary point is at the center
    if pos.proportionalAnchorTo == WidgetOrientation.Center:
      primaryPoint - w.resolvedDimensions[axis] div 2
    else:
      primaryPoint
  of WidgetPositionKind.Centered:
    parentV + (parentD - w.resolvedDimensions[axis]) div 2
  of WidgetPositionKind.Relative:
    let relativeToWidget = w.parent.get.childByIdentifier(pos.relativeToWidget)
    if relativeToWidget.isSome:
      if isFarSide(axis, pos.relativeToWidgetAnchorPoint):
        relativeToWidget.get.resolvedPosition[axis] + relativeToWidget.get.resolvedDimensions[axis] + pos.relativeOffset * w.windowingSystem.pixelScale
      else:
        relativeToWidget.get.resolvedPosition[axis] - pos.relativeOffset * w.windowingSystem.pixelScale - w.resolvedDimensions[axis]
    else:
      if not w.ignoreMissingRelativePosition:
        warn &"resolvePositionValue(...) looking for relative widget {pos.relativeToWidget} on widget {w.identifier} but none found"
      0
  of WidgetPositionKind.Match:
    let matchWidget = w.parent.get.childByIdentifier(pos.matchWidget)
    if matchWidget.isSome:
      matchWidget.get.resolvedPosition[axis]
    else:
      if not w.ignoreMissingRelativePosition:
        warn &"resolvePositionValue(...) looking for match widget {pos.matchWidget} on widget {w.identifier} but none found"
      0
  of WidgetPositionKind.Absolute:
    if pos.absoluteAnchorTo == WidgetOrientation.Center:
      pos.absoluteOffset - w.resolvedDimensions[axis] div 2
    elif isFarSide(axis, pos.absoluteAnchorTo):
      pos.absoluteOffset - w.resolvedDimensions[axis]
    else:
      pos.absoluteOffset


proc updateGeometry*(ws: WindowingSystemRef) {.gcsafe.}

proc resolvePosition*(w: Widget, axis: Axis, pos: WidgetPosition): int {.gcsafe.} =
  if w.parent.isNone:
    warn &"Cannot resolve position of widget with no parent: {w.identifier}"
    return 0

  updateGeometry(w.windowingSystem)

  resolvePositionValue(w, axis, pos)

proc resolveEffectiveDimension*(w: Widget, axis: Axis): int {.gcsafe.} =
  updateGeometry(w.windowingSystem)

  w.resolvedDimensions[axis] div w.windowingSystem.pixelScale

proc recalculatePosition(w: Widget, axis: Axis, dirtySet: HashSet[Dependency], completedSet: var HashSet[Dependency]) =
  let completedKey = (widget: w, kind: DependencyKind.Position, axis: axis)
  if completedSet.containsOrIncl(completedKey):
    return
  fine &"recalculating position for widget {w.entity} {axis}"
  w.resolvedPosition[axis.ord] = 0

  let pos = w.position[axis.ord]

  if not w.windowingSystem.customRenderer:
    if w.background.draw:
      w.clientOffset[axis] = (imageMetricsFor(w.background.image.value).borderWidth * w.background.pixelScale + w.padding[axis] * 2) * w.windowingSystem.pixelScale
    else:
      w.clientOffset[axis] = w.padding[axis] * 2 * w.windowingSystem.pixelScale
  else:
    for r in w.windowingSystem.components:
      let co = r.clientOffset(w, axis)
      if co.isSome:
        w.clientOffset[axis.ord] = co.get()[axis.ord]

  if w.parent.isSome:
    for dep in dependentOn(pos, axis, w, w.parent.get):
      if dirtySet.contains(dep):
        ensureDependency(dep, dirtySet, completedSet)

    w.resolvedPosition[axis] = resolvePositionValue(w, axis, pos)



proc recalculateDimensions(w: Widget, axis: Axis, dirtySet: HashSet[Dependency], completedSet: var HashSet[Dependency]) =
  # let pixelScale = w.windowingSystem.pixelScale

  let completedKey = (widget: w, kind: DependencyKind.Dimensions, axis: axis)
  if completedSet.containsOrIncl(completedKey):
    return
  fine &"recalculating dimensions for widget {w.entity} {axis}"
  w.resolvedDimensions[axis.ord] = 0

  let dim = w.dimensions[axis.ord]

  if not w.windowingSystem.customRenderer:
    if w.background.draw:
      w.clientOffset[axis] = (imageMetricsFor(w.background.image.value).borderWidth * w.background.pixelScale + w.padding[axis] * 2) * w.windowingSystem.pixelScale
    else:
      w.clientOffset[axis] = w.padding[axis] * 2 * w.windowingSystem.pixelScale
  else:
    for r in w.windowingSystem.components:
      let co = r.clientOffset(w, axis)
      if co.isSome:
        w.clientOffset[axis.ord] = co.get()[axis.ord]

  if w.parent.isSome:
    for dep in dependentOn(dim, axis, w, w.parent.get, w.children):
      if dirtySet.contains(dep):
        ensureDependency(dep, dirtySet, completedSet)

    let parentV = w.parent.get.resolvedPosition[axis] + w.parent.get.clientOffset[axis]
    let parentD = w.parent.get.resolvedDimensions[axis] - w.parent.get.clientOffset[axis] * 2
    w.resolvedDimensions[axis] = case dim.kind:
    of WidgetDimensionKind.Fixed:
      dim.fixedSize * w.windowingSystem.pixelScale
    of WidgetDimensionKind.Relative:
      parentD + dim.sizeDelta * w.windowingSystem.pixelScale
    of WidgetDimensionKind.Proportional:
      (parentD.float * dim.sizeProportion).int
    of WidgetDimensionKind.ExpandToParent:
      let relativePos = w.resolvedPosition[axis] - parentV
      parentD - dim.parentGap * w.windowingSystem.pixelScale - relativePos
    of WidgetDimensionKind.Intrinsic:
      var intrinsicSize: Option[int] = none(int)
      var minimums: Vec2i = vec2i(0, 0)
      var maximums: Vec2i = vec2i(1000000, 10000000)
      # Todo: this only accounts for intrinsic min/max's, might want to include fixed values too?
      if w.dimensions[0].kind == WidgetDimensionKind.Intrinsic:
        minimums.x = w.dimensions[0].intrinsicMin.get(0).int32
        maximums.x = w.dimensions[0].intrinsicMax.get(1000000).int32
      if w.dimensions[1].kind == WidgetDimensionKind.Intrinsic:
        minimums.y = w.dimensions[1].intrinsicMin.get(0).int32
        maximums.y = w.dimensions[1].intrinsicMax.get(1000000).int32


      for renderer in w.windowingSystem.components:
        intrinsicSize = renderer.intrinsicSize(w, axis, minimums, maximums)
        if intrinsicSize.isSome: break

      if intrinsicSize.isSome:
        intrinsicSize.get + w.clientOffset[axis] * 2
      else:
        warn &"intrinsic sized widget with no intrinsic qualities {w.identifier}"
        10
    of WidgetDimensionKind.WrapContent:
      var min: int = 0
      var max: int = 0
      for c in w.children:
        if c.showing:
          min = min.min(c.resolvedPartialPosition[axis])
          max = max.max(c.resolvedPartialPosition[axis] + c.resolvedDimensions[axis])
      if max > min:
        max - min + w.clientOffset[axis] * 2
      else:
        0
    of WidgetDimensionKind.ExpandTo:
      let expandToWidget = w.parent.get.childByIdentifier(dim.expandToWidget)
      if expandToWidget.isSome:
        expandToWidget.get.resolvedPosition[axis] - dim.expandToGap * w.windowingSystem.pixelScale - w.resolvedPosition[axis]
      else:
        warn &"Resolving dimensions for widget {w.identifier} failed, could not expand to target, target {dim.expandToWidget} not found"
        0
  else:
    case dim.kind:
      of WidgetDimensionKind.Fixed:
        w.resolvedDimensions[axis] = dim.fixedSize * w.windowingSystem.pixelScale
      else:
        w.resolvedDimensions[axis] = w.windowingSystem.dimensions[axis]

proc ensureDependency(dep: Dependency, dirtySet: HashSet[Dependency], completedSet: var HashSet[Dependency]) {.gcsafe.} =
  if not completedSet.contains(dep):
    case dep.kind:
    of DependencyKind.Position:
      dep.widget.windowingSystem.updatePositionCount.inc
      dep.widget.recalculatePosition(dep.axis, dirtySet, completedSet)
    of DependencyKind.Dimensions:
      fine &"Updating dimensions({dep.axis}) for widget {dep.widget.identifier}"
      dep.widget.windowingSystem.updateDimensionsCount.inc
      dep.widget.recalculateDimensions(dep.axis, dirtySet, completedSet)
    of DependencyKind.PartialPosition:
      dep.widget.recalculatePartialPosition(dep.axis, dirtySet, completedSet)
    completedSet.incl(dep)

# proc updateDependent(dep : Dependent, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency]) =
#   case dep.sourceKind:
#   of DependencyKind.Position: dep.dependentWidget.recalculatePosition(dep.sourceAxis, dirtySet, completedSet)
#   of DependencyKind.Dimensions: dep.dependentWidget.recalculateDimensions(dep.sourceAxis, dirtySet, completedSet)

proc collectDirty(dep: Dependency, dirty: var HashSet[Dependency]) =
  var toRemove: seq[Dependent]
  # Copy here since we may be modifying this on the widget itself
  let dependents = dep.widget.dependents
  for dependent in dependents:
    if dependent.dependentWidget.destroyed:
      toRemove.add(dependent)
    else:
      if dependent.dependsOnAxis == dep.axis and dependent.dependsOnKind == dep.kind:
        let newDep = (widget: dependent.dependentWidget, kind: dependent.sourceKind, axis: dependent.sourceAxis)
        if not dirty.containsOrIncl(newDep):
          collectDirty(newDep, dirty)
  for r in toRemove:
    dep.widget.dependents.excl(r)


# proc recursivelyCollectDependents(w : )

proc updateLastWidgetUnderMouse[WorldType](ws: WindowingSystemRef, widget: Widget, world: WorldType, display: DisplayWorld)

proc updateGeometry*(ws: WindowingSystemRef) {.gcsafe.} =
  fine &"Pending updates: {ws.pendingUpdates}"
  for w, v in ws.pendingUpdates:
    for axis in axes():
      if v.contains(depFlag(axis)):
        ws.updateDependentsCount.inc
        w.recalculateDependents(axis)

  var dirtySet: HashSet[Dependency]
  var completedSet: HashSet[Dependency]
  for w, v in ws.pendingUpdates:
    if v.contains(RecalculationFlag.Contents):
      if w.destroyed:
        info &"Adding destroyed widget to rerender set due to pending content updates {w.identifier}"
      ws.rerenderSet.incl(w)
    for axis in axes2d():
      if v.contains(dimFlag(axis)) or v.contains(depFlag(axis)):
        # w.recalculateDimensions(axis, completedSet)
        dirtySet.incl((widget: w, kind: DependencyKind.Dimensions, axis: axis))
        collectDirty((widget: w, kind: DependencyKind.Dimensions, axis: axis), dirtySet)
    for axis in axes3d():
      if v.contains(posFlag(axis)) or v.contains(depFlag(axis)):
        # w.recalculatePosition(axis, completedSet)
        dirtySet.incl((widget: w, kind: DependencyKind.Position, axis: axis))
        dirtySet.incl((widget: w, kind: DependencyKind.PartialPosition, axis: axis))
        collectDirty((widget: w, kind: DependencyKind.Position, axis: axis), dirtySet)

  for dsDep in dirtySet:
    ensureDependency(dsDep, dirtySet, completedSet)

  for completed in completedSet:
    if completed.widget.destroyed:
      info &"Adding destroyed widget to rerender set due to completed set {completed.widget.identifier}"
    ws.rerenderSet.incl(completed.widget)

  ws.pendingUpdates.clear()

  if ws.renderContentsCount + ws.updateDependentsCount + ws.updateDimensionsCount + ws.updatePositionCount > 0:
    fine &"contents renders: {ws.renderContentsCount}"
    fine &"dependents recalc: {ws.updateDependentsCount}"
    fine &"dimensions recalc: {ws.updateDimensionsCount}"
    fine &"position recalc: {ws.updatePositionCount}"


proc widgetAtPosition*(ws: WindowingSystemRef, position: Vec2f): Widget

proc update*[WorldType](ws: WindowingSystemRef, tb: TextureBlock, world: WorldType, display: DisplayWorld) : bool =
  ws.updateDependentsCount = 0
  ws.updateDimensionsCount = 0
  ws.updatePositionCount = 0
  ws.renderContentsCount = 0

  let expectedDimensions = ws.display[GraphicsContextData].framebufferSize + 1
  if ws.dimensions != expectedDimensions:
    ws.dimensions = expectedDimensions
    ws.desktop.markForUpdate(RecalculationFlag.DimensionsX)
    ws.desktop.markForUpdate(RecalculationFlag.DimensionsY)

  updateGeometry(ws)

  let widgetUnderMouse = ws.widgetAtPosition(ws.lastMousePosition)
  if widgetUnderMouse != ws.lastWidgetUnderMouse:
    ws.updateLastWidgetUnderMouse(widgetUnderMouse, world, display)

  if ws.rerenderSet.len != 0:
    for widget in ws.rerenderSet:
      if widget.destroyed: continue

      ws.renderContentsCount.inc
      let bounds = if widget.parent.isSome:
        let pClientOffset = widget.parent.get.clientOffset.xy
        Bounds(origin: vec2f(widget.parent.get.resolvedPosition.xy), dimensions : vec2f(widget.parent.get.resolvedDimensions))
      else:
        Bounds(origin: vec2f(0,0), dimensions: vec2f(100000.0,10000.0))

      if ws.customRenderer:
        customRenderContents(ws, display, widget, tb, bounds)
      else:
        renderContents(ws, widget, tb, bounds)
    ws.renderRevision.inc
    fine "Re-rendered"
    ws.rerenderSet.clear()
    true
  else:
    false


type Corner = object
  enabled: bool
  dimensions: Vec2i


const edgeAxes: array[4, Axis] = [Axis.Y, Axis.X, Axis.Y, Axis.X]
# const cornerRects : array[4,Rectf] = [
#   rect(vec2f(0.0f,0.0f), rectf)
# ]

iterator nineWayImageQuads*(nwi: NineWayImage, inDim: Vec2i, pixelScale: int, allBeforeChildren: bool = false): WQuad =
  let offset = vec3f(nwi.dimensionDelta.x * nwi.pixelScale * pixelScale * -1, nwi.dimensionDelta.y * nwi.pixelScale * pixelScale * -1, 0)
  let dim = inDim + nwi.dimensionDelta * nwi.pixelScale * pixelScale * 2
  let img = nwi.image.asImage
  let imgMetrics = imageMetricsFor(img)

  let fwd = vec3f(1, 0, 0)
  let oto = vec3f(0, 1, 0)
  let basis = [fwd, oto]

  var cornerDim: Vec2i = (img.dimensions div 2) * nwi.pixelScale * pixelScale
  var cornerPercents: Vec2f = vec2f(1.0, 1.0)
  for axis in axes2d():
    if cornerDim[axis] > dim[axis] div 2:
      cornerPercents[axis] = (dim[axis] / 2) / cornerDim[axis].float
      cornerDim[axis] = (dim[axis] div 2) + 1

  let farDims = dim - cornerDim
  let ctcPos = vec2f(0.0f, 1.0f - 0.5f * cornerPercents.y)
  let ctcDim = cornerPercents * 0.5f
  let cornerSubRect = rect(ctcPos, ctcDim)

  var corners: array[4, Corner]
  for q in 0 ..< 4:
    corners[q].enabled = nwi.drawEdges.contains(q.WidgetEdge) and nwi.drawEdges.contains(((q+1) mod 4).WidgetEdge)
    if corners[q].enabled:
      corners[q].dimensions = cornerDim

  if nwi.drawCenter:
    let centerOffset = imgMetrics.borderWidth * nwi.pixelScale * pixelScale - 1
    let startX = if nwi.drawEdges.contains(WidgetEdge.Left): centerOffset else: 0
    let startY = if nwi.drawEdges.contains(WidgetEdge.Top): centerOffset else: 0
    let endX = if nwi.drawEdges.contains(WidgetEdge.Right): dim.x - centerOffset else: 0
    let endY = if nwi.drawEdges.contains(WidgetEdge.Bottom): dim.y - centerOffset else: 0
    let pos = fwd * startX.float32 + oto * startY.float32
    yield WQuad(shape: rectShape(position = pos + offset, dimensions = vec2i(endX-startX+1, endY-startY+1), forward = fwd.xy), texCoords: noImageTexCoords(), color: nwi.color * imgMetrics.centerColor,
        beforeChildren: true)

  for q in 0 ..< 4:
    if corners[q].enabled:
      let pos = fwd * farDims.x.float32 * UnitSquareVertices[q].x + oto * farDims.y.float32 * UnitSquareVertices[q].y
      let tc = subRectTexCoords(cornerSubRect, q mod 3 != 0, q >= 2)
      yield WQuad(shape: rectShape(position = pos + offset, dimensions = cornerDim, forward = fwd.xy), image: img, color: nwi.edgeColor, texCoords: tc, beforeChildren: allBeforeChildren)

    if nwi.drawEdges.contains(q.WidgetEdge):
      let primaryAxis = edgeAxes[q].ord
      let secondaryAxis = 1 - primaryAxis
      if dim[primaryAxis] > cornerDim[primaryAxis] * 2:
        # Make this work properly with just drawing the bottom edge (should not draw corners but extend radius the full distance
        var pos = basis[primaryAxis] * cornerDim[primaryAxis].float +
              basis[secondaryAxis] * farDims[secondaryAxis].float * UnitSquareVertices2d[q][secondaryAxis]
        var edgeDim: Vec2i
        edgeDim[primaryAxis] = dim[primaryAxis] - corners[(q+3) mod 4].dimensions[primaryAxis] - corners[q].dimensions[primaryAxis]
        edgeDim[secondaryAxis] = cornerDim[secondaryAxis]

        var imgSubRect: Rectf
        imgSubRect.position[primaryAxis] = 0.5f - ctcPos[primaryAxis]
        imgSubRect.position[secondaryAxis] = ctcPos[secondaryAxis]
        imgSubRect.dimensions[secondaryAxis] = ctcDim[secondaryAxis]

        yield WQuad(shape: rectShape(position = pos + offset, dimensions = edgeDim, forward = fwd.xy), image: img, color: nwi.edgeColor, texCoords: subRectTexCoords(imgSubRect, q >= 2, q >= 2),
            beforeChildren: allBeforeChildren)




proc addQuadToWidget(w: Widget, tb: TextureBlock, quad: WQuad, offset: Vec2i, bounds: Bounds, forceBeforeChildren: bool = false, forceAfterChildren: bool = false) =
  for vertex in quadToVertices(quad, tb, bounds):
    if (quad.beforeChildren or forceBeforeChildren) and not forceAfterChildren:
      w.preVertices.add(vertex)
      w.preVertices[w.preVertices.len-1].vertex.x += offset.x.float
      w.preVertices[w.preVertices.len-1].vertex.y += offset.y.float
    else:
      w.postVertices.add(vertex)
      w.postVertices[w.postVertices.len-1].vertex.x += offset.x.float
      w.postVertices[w.postVertices.len-1].vertex.y += offset.y.float

proc customRenderContents(ws: WindowingSystemRef, display: DisplayWorld, w: Widget, tb: TextureBlock, bounds: Bounds) =
  if w.destroyed:
    info &"Rendering destroyed widget {w.identifier}"
    writeStackTrace()
  else:
    for renderer in ws.components:
        renderer.customRender(display, w, tb, bounds)

proc renderContents(ws: WindowingSystemRef, w: Widget, tb: TextureBlock, bounds: Bounds) =
  fine &"Rendering widget {w}"
  w.preVertices.setLen(0)
  w.postVertices.setLen(0)

  if w.background.draw:
    for quad in w.background.nineWayImageQuads(w.resolvedDimensions, ws.pixelScale):
      addQuadToWidget(w, tb, quad, w.resolvedPosition.xy, bounds)
  for overlay in w.overlays:
    if overlay.draw:
      for quad in overlay.nineWayImageQuads(w.resolvedDimensions, ws.pixelScale):
        addQuadToWidget(w, tb, quad, w.resolvedPosition.xy, bounds, forceAfterChildren = true)

  for renderer in ws.components:
    let quads = renderer.render(w)
    for quad in quads:
      addQuadToWidget(w, tb, quad, w.resolvedPosition.xy + w.clientOffset.xy, bounds)

proc render(ws: WindowingSystemRef, w: Widget, vao: VAO[WVertex, uint32], tb: TextureBlock, vi, ii: var int) =
  if w.showing:
    fine &"Rendering widget {w}"
    for i in 0 ..< (w.preVertices.len div 4):
      for q in 0 ..< 4:
        vao[vi+q][] = w.preVertices[i*4+q]
      vao.addIQuad(ii, vi)

    sort(w.children) do (a, b: Widget) -> int: cmp(a.resolvedPosition.z, b.resolvedPosition.z)

    for child in w.children:
      render(ws, child, vao, tb, vi, ii)

    for i in 0 ..< (w.postVertices.len div 4):
      for q in 0 ..< 4:
        vao[vi+q][] = w.postVertices[i*4+q]
      vao.addIQuad(ii, vi)
  else:
    fine &"Not rendering widget {w}, not showing"

proc render*(ws: WindowingSystemRef, vao: VAO[WVertex, uint32], textureBlock: TextureBlock) =
  if vao.revision < ws.renderRevision:
    var vi, ii: int = 0

    ws.render(ws.desktop, vao, textureBlock, vi, ii)

    fine "Swapping ui vao"
    vao.swap()
    vao.revision = ws.renderRevision

proc data*[T](widget: Widget, t: typedesc[T]): ref T =
  widget.windowingSystem.display.data(widget.entity, t)

proc hasData*[T](widget: Widget, t: typedesc[T]): bool =
  widget.windowingSystem.display.hasData(widget.entity, t)

proc attachData*[T](widget: Widget, valueIn: T) =
  var value = valueIn
  when compiles(value.widget):
    value.widget = widget
  # else:
    # echo "could not attach data"
  widget.windowingSystem.display.attachData(widget.entity, value)


proc widgetContainsPosition*(w: Widget, position: Vec2f): bool =
  let px = position.x.int
  let py = position.y.int
  let rp = w.resolvedPosition
  let rd = w.resolvedDimensions

  rp.x <= px and rp.y <= py and rp.x + rd.x >= px and rp.y + rd.y >= py

proc widgetContainsPositionInClientArea*(w: Widget, position: Vec2f): bool =
  let px = position.x.int
  let py = position.y.int
  let rp = w.resolvedPosition + w.clientOffset
  let rd = w.resolvedDimensions - w.clientOffset.xy * 2

  rp.x <= px and rp.y <= py and rp.x + rd.x >= px and rp.y + rd.y >= py

proc effectiveDimensions*(w: Widget): Vec2i =
  vec2i(w.resolvedDimensions.x div w.windowingSystem.pixelScale, w.resolvedDimensions.y div w.windowingSystem.pixelScale)

proc effectiveClientDimensions*(w: Widget): Vec2i =
  vec2i((w.resolvedDimensions.x - w.clientOffset.x*2) div w.windowingSystem.pixelScale,
  (w.resolvedDimensions.y - w.clientOffset.y * 2) div w.windowingSystem.pixelScale)

proc widgetAtPosition*(ws: WindowingSystemRef, w: Widget, position: Vec2f): Widget =
  # Default the result to the widget itself, we've guaranteed at the call of this function that
  # the provided widget does match, this will dive deeper into children, if warranted
  result = w
  var highestZ = -100000

  if widgetContainsPositionInClientArea(w, position):
    # iterate over the children, finding the child that contains the position with the highest Z
    for i in 0 ..< w.children.len:
      let c = w.children[i]
      if c.showing and widgetContainsPosition(c, position):
        if c.resolvedPosition.z > highestZ:
          highestZ = c.resolvedPosition.z
          result = c
  # if we found a child (and therefore updated result) we want to then dive into it to find its
  # highest matching child, but if we didn't find anything we're already done
  if result != w:
    result = widgetAtPosition(ws, result, position)


proc widgetAtPosition*(ws: WindowingSystemRef, position: Vec2f): Widget =
  widgetAtPosition(ws, ws.desktop, position)





# Deserialization and config


proc readFromConfig*(cv: ConfigValue, e: var WidgetArchetypeIdentifier) =
  if cv.isStr:
    let sections = cv.asStr.split('.', 1)
    if sections.len != 2:
      warn &"Widget archetypes should take the form location.identifier: {cv.asStr}"
    else:
      e = WidgetArchetypeIdentifier(location: sections[0], identifier: sections[1])
  else: warn &"only strings may be used for widget archetypes: {cv}"

proc readFromConfig*(cv: ConfigValue, e: var WidgetEdge) =
  if cv.nonEmpty:
    if cv.isStr:
      case cv.asStr.toLowerAscii:
      of "left": e = WidgetEdge.Left
      of "right": e = WidgetEdge.Right
      of "top": e = WidgetEdge.Top
      of "bottom": e = WidgetEdge.Bottom
      else:
        warn &"Invalid widget edge: {cv.asStr}"
    else:
      warn &"Invalid widget edge config: {cv}"

proc parseStr(str: string, t: typedesc[WidgetOrientation]): Option[WidgetOrientation] =
  case str.toLowerAscii.replace(" ", ""):
    of "topleft": some(WidgetOrientation.TopLeft)
    of "left": some(WidgetOrientation.TopLeft)
    of "topright": some(WidgetOrientation.TopRight)
    of "right": some(WidgetOrientation.TopRight)
    of "bottomleft": some(WidgetOrientation.BottomLeft)
    of "bottom": some(WidgetOrientation.BottomLeft)
    of "bottomright": some(WidgetOrientation.BottomRight)
    of "top": some(WidgetOrientation.TopLeft)
    of "center": some(WidgetOrientation.Center)
    else: none(WidgetOrientation)


proc readFromConfig*(cv: ConfigValue, e: var WidgetOrientation) =
  if cv.nonEmpty:
    if cv.isStr:
      let wopt = parseStr(cv.asStr, WidgetOrientation)
      if wopt.isSome:
        e = wopt.get
      else:
        warn &"Invalid widget orientation: {cv.asStr}"
    else:
      warn &"Invalid widget orientation config: {cv}"

const orientedConstantPattern = re"(?i)([0-9]+) from (.*)"
const orientedProportionPattern = re"(?i)([0-9.]+) from (.*)"
const rightLeftPattern = re"(?i)([0-9-]+) (right|left) of ([a-zA-Z0-9]+)"
const belowAbovePattern = re"(?i)([0-9-]+) (below|above) ([a-zA-Z0-9]+)"
const expandToParentPattern = re"(?i)expand\s?to\s?parent(?:\(([0-9]+)\))?"
const expandToWidgetPattern = re"(?i)expand\s?to\s?([a-zA-Z0-9]+)(?:\(([0-9]+)\))?"
const percentagePattern = re"([0-9]+)%"
const centeredPattern = re"(?i)center(ed)?"
const wrapContentPattern = re"(?i)wrap\s?content"
const matchPosPattern = re"(?i)match ([a-zA-Z0-9]+)"

proc readFromConfig*(cv: ConfigValue, e: var WidgetPosition, widget: Widget) =
  if cv.nonEmpty:
    if cv.isNumber:
      let num = cv.asFloat
      if num >= 1.0 or num <= 0.0:
        e = fixedPos(num.int)
      else:
        e = proportionalPos(num)
    elif cv.isStr:
      let str = cv.asStr
      matcher(str):
        extractMatches(orientedConstantPattern, distStr, relativeToStr):
          let relativeTo = parseStr(relativeToStr, WidgetOrientation)
          if relativeTo.isSome:
            e = fixedPos(parseInt(distStr), relativeTo.get)
          else: warn &"failed to parse widget oriented constant position : {distStr}, {relativeToStr}"
        extractMatches(orientedProportionPattern, propStr, relativeToStr):
          let prop = parseFloatOpt(propStr)
          let relativeTo = parseStr(relativeToStr, WidgetOrientation)
          if prop.isSome and relativeTo.isSome:
            e = proportionalPos(prop.get, relativeTo.get)
          warn &"failed to parse widget oriented proportional position : {propStr}, {relativeToStr}"
        extractMatches(rightLeftPattern, distStr, dirStr, targetStr):
          let dir = if dirStr.toLowerAscii == "right": WidgetOrientation.TopRight else: WidgetOrientation.TopLeft
          e = relativePos(targetStr, parseInt(distStr).int32, dir)
        extractMatches(belowAbovePattern, distStr, dirStr, targetStr):
          let dir = if dirStr.toLowerAscii == "below": WidgetOrientation.BottomLeft else: WidgetOrientation.TopLeft
          e = relativePos(targetStr, parseInt(distStr).int32, dir)
          # let target = widget.parent.get.childByIdentifier(targetStr)
          # if target.isSome:
          #   e = relativePos(target.get, parseInt(distStr).int32, dir)
          # else:
          #   warn &"failed to parse widget above/below relative position : {str}"
        extractMatches(matchPosPattern, targetStr):
          e = matchPos(targetStr)
        extractMatches(centeredPattern, distStr):
          e = centered()
        warn &"unsupported position expression: {str}"
    else:
      warn &"Invalid config for widget dimension : {cv}"

proc readFromConfig*(cv: ConfigValue, e: var WidgetDimension) =
  if cv.nonEmpty:
    if cv.isNumber:
      let num = cv.asFloat
      if num > 1.0:
        e = fixedSize(num.int)
      elif num < 0.0:
        e = relativeSize(num.int)
      else:
        e = proportionalSize(num)
    elif cv.isStr:
      let str = cv.asStr
      if str == "intrinsic":
        e = intrinsic()
      else:
        matcher(cv.asStr):
          extractMatches(expandToParentPattern, gapStr):
            if gapStr != "":
              e = expandToParent(parseInt(gapStr))
            else:
              e = expandToParent(0)
          extractMatches(expandToWidgetPattern, widgetStr, gapStr):
            if gapStr != "":
              e = expandToWidget(widgetStr, parseInt(gapStr))
            else:
              e = expandToWidget(widgetStr, 0)
          extractMatches(percentagePattern, percentStr):
            e = proportionalSize(parseInt(percentStr).float / 100.0)
          extractMatches(wrapContentPattern):
            e = wrapContent()

          warn &"unsupported dimension expression: {cv.asStr}"
    else:
      warn &"Invalid config for widget position : {cv}"

proc readFromConfig*(cv: ConfigValue, e: var NineWayImage) =
  readIntoOrElse(cv["image"], e.image, bindable(imageRef("ui/minimalistBorder.png")))
  readIntoOrElse(cv["pixelScale"], e.pixelScale, 1.int32)
  readIntoOrElse(cv["color"], e.color, bindable(rgba(255, 255, 255, 255)))
  readIntoOrElse(cv["edgeColor"], e.edgeColor, bindable(rgba(255, 255, 255, 255)))
  readIntoOrElse(cv["draw"], e.draw, bindable(cv["image"].nonEmpty))
  readIntoOrElse(cv["drawCenter"], e.drawCenter, true)
  readIntoOrElse(cv["drawEdges"], e.drawEdges, AllEdges)
  readIntoOrElse(cv["dimensionDelta"], e.dimensionDelta, vec2i(0, 0))


# proc populateChildren(cv: ConfigValue, e: var Widget) =
#   let childrenCV = cv["children"]
#   if childrenCV.isObj:
#     for k, childCV in cv["children"].fields:
#       let existing = e.childByIdentifier(k)
#       if not existing.isSome:
#         let newChild = e.windowingSystem.createWidget(e)
#         newChild.identifier = k
#         e.children.add(newChild)

proc readFromConfig*(cv: ConfigValue, e: var Widget) =
  let isDiv = cv["type"].asStr("").toLowerAscii == "div"
  if isDiv:
    e.dimensions[0] = wrapContent()
    e.dimensions[1] = wrapContent()

  # populateChildren(cv, e) # no longer doing this, this is now done at archetype hydration time

  readInto(cv["background"], e.background)
  readInto(cv["overlays"], e.overlays)
  if isDiv and (cv["background"].isEmpty or cv["background"]["draw"].isEmpty):
    e.background.draw = bindable(false)
  readFromConfig(cv["x"], e.position[0], e)
  readFromConfig(cv["y"], e.position[1], e)
  readFromConfig(cv["z"], e.position[2], e)
  readInto(cv["width"], e.dimensions[0])
  readInto(cv["height"], e.dimensions[1])
  readInto(cv["padding"], e.padding)
  readIntoOrElse(cv["showing"], e.showing_f, @[bindable(true)])
  readInto(cv["ignoreMissingRelativePosition"], e.ignoreMissingRelativePosition)

  if e.dimensions[0].kind == WidgetDimensionKind.Intrinsic:
    readInto(cv["minWidth"], e.dimensions[0].intrinsicMin)
    readInto(cv["maxWidth"], e.dimensions[0].intrinsicMax)

  if e.dimensions[1].kind == WidgetDimensionKind.Intrinsic:
    readInto(cv["minHeight"], e.dimensions[1].intrinsicMin)
    readInto(cv["maxHeight"], e.dimensions[1].intrinsicMax)

  for comp in e.windowingSystem.components:
    comp.readDataFromConfig(cv, e)

  # let childrenCV = cv["children"]
  # if childrenCV.isObj:
  #   for k, childCV in cv["children"].fields:
  #     var child = e.childByIdentifier(k)
  #     if child.isSome:
  #       readFromConfig(childCV, child.get)
  #     else:
  #       warn "somehow child config did not match identifiers with existing child"

proc readFromConfig*(cv: ConfigValue, e: var WidgetArchetype) =
  cv.readInto(e.widgetData)
  let childrenCV = cv["children"]
  if childrenCV.isEmpty:
    discard
  elif childrenCV.isObj:
    for k, childCV in cv["children"].fields:
      mergeInherit(e.widgetData.windowingSystem.stylesheet, childCV)
      var childArch = WidgetArchetype(widgetData: Widget(windowingSystem: e.widgetData.windowingSystem, entity: e.widgetData.windowingSystem.display.createEntity()))
      childCV.readInto(childArch)
      e.children[k] = childArch
  else:
    warn &"Children config for widget archetypes should be a map with names, was actually:\n{childrenCV}"


proc createWidgetFromConfig*(ws: WindowingSystemRef, identifier: string, cv: ConfigValue, parent: Widget): Widget {.discardable.} =
  let t = relTime()
  if not ws.widgetArchetypes.contains(identifier):
    var arch = WidgetArchetype(widgetData: Widget(windowingSystem: ws, entity: ws.display.createEntity()))
    mergeInherit(ws.stylesheet, cv)
    readInto(cv, arch)
    ws.widgetArchetypes[identifier] = arch

  result = createWidgetFromArchetype(ws, ws.widgetArchetypes[identifier], identifier, parent)


proc createWidget*(ws: WindowingSystemRef, confPath: string, identifier: string, parent: Widget = nil): Widget =
  let effConfPath =
    if confPath.endsWith(".sml"):
      confPath
    else:
      confPath & ".sml"

  var conf = resources.configOpt(ws.rootConfigPath & effConfPath)
  if conf.isNone:
    conf = resources.configOpt("ui/widgets/" & effConfPath)
  if conf.isNone:
    warn &"Trying to create widget from config {confPath}, {identifier}, but no appropriate config found"
    createWidget(ws, parent)
  else:
    createWidgetFromConfig(ws, identifier, (conf.get)[identifier], parent)

proc createChild*(w: Widget, confPath: string, identifier: string): Widget {.discardable.} =
  createWidget(w.windowingSystem, confPath, identifier, w)

proc createChild*(w: Widget, arch: WidgetArchetypeIdentifier): Widget {.discardable.} = createChild(w, arch.location, arch.identifier)

# accumulate all the bindings this widget will use initially by traversing up through parents
# the resulting resolver will be in reverse order since we go child->parent rather than parent->child
proc accumulateBindings(widget: Widget, resolver: var BoundValueResolver) =
  if not widget.bindings.isNil:
    resolver.boundValues.add(widget.bindings)
  if widget.parent_f.isSome:
    accumulateBindings(widget.parent_f.get, resolver)

# Note: currently unused! Does not appear to be needed, but retaining in case we find a need to do this
# explicitly in the future.
proc initializeWidgetBindings(widget: Widget) =
  var resolver = BoundValueResolver()
  accumulateBindings(widget, resolver)
  resolver.boundValues.reverse()

  discard updateBindings(widget[], resolver)
  discard updateBindings(widget.background, resolver)
  for i in 0 ..< widget.overlays.len:
    discard updateBindings(widget.overlays[i], resolver)
  for comp in widget.windowingSystem.components:
    comp.updateBindings(widget, resolver)


proc updateWidgetBindings(widget: Widget, resolver: var BoundValueResolver) =
  if not widget.bindings.isNil:
    resolver.boundValues.add(widget.bindings)
  for b in widget.showing_f.mitems:
    if updateBindings(b, resolver):
      for e in enumValues(RecalculationFlag): widget.markForUpdate(e)
  if updateBindings(widget[], resolver):
    widget.markForUpdate(RecalculationFlag.Contents)
  if updateBindings(widget.background, resolver):
    widget.markForUpdate(RecalculationFlag.Contents)

  for i in 0 ..< widget.overlays.len:
    if updateBindings(widget.overlays[i], resolver):
      widget.markForUpdate(RecalculationFlag.Contents)
  for comp in widget.windowingSystem.components:
    comp.updateBindings(widget, resolver)

  for c in widget.children:
    updateWidgetBindings(c, resolver)

  if not widget.bindings.isNil:
    resolver.boundValues.del(resolver.boundValues.len-1)

proc bindValue*[T](widget: Widget, key: string, value: T) =
  if widget.bindings.isNil:
    widget.bindings = newTable[string, BoundValue]()
  # only run through the binding update process if there are actually any new values being bound
  if bindValueInto(key, value, widget.bindings):
    var resolver = BoundValueResolver()
    if widget.parent_f.isSome:
      accumulateBindings(widget.parent_f.get, resolver)
    updateWidgetBindings(widget, resolver)

proc hasBinding*(widget: Widget, key: string) : bool =
  if widget.bindings.isNil:
    false
  else:
    widget.bindings.contains(key)

proc pixelScale*(widget: Widget): int = widget.windowingSystem.pixelScale

proc destroyWidget*(w: Widget) =
  w.destroyed = true
  let ws = w.windowingSystem
  w.parent = none(Widget)
  ws.display.destroyEntity(w.entity)
  if ws.focusedWidget == some(w):
    ws.focusedWidget = none(Widget)
  if ws.lastWidgetUnderMouse == w:
    ws.lastWidgetUnderMouse = ws.desktop
  ws.pendingUpdates.del(w)

proc containsWidget*(w: Widget, other: Widget): bool =
  if w == other:
    true
  else:
    for c in w.children:
      if containsWidget(c, other):
        return true
    false

proc relativePosition*(w: WidgetMouseMove | WidgetMousePress | WidgetMouseRelease): Vec2i =
  vec2i(w.position.x.int - w.widget.resolvedPosition.x, w.position.y.int - w.widget.resolvedPosition.y)

proc originatingWidget*(w: WidgetEvent): Widget =
  if not w.i_originatingWidget.isNil:
    w.i_originatingWidget
  else:
    w.widget

proc `originatingWidget=`*(w: WidgetEvent, widget: Widget) =
  w.i_originatingWidget = widget

proc handleEvent*[WorldType](ws: WindowingSystemRef, event: WidgetEvent, world: WorldType, display: DisplayWorld): bool

proc giveWidgetFocus*[WorldType](ws: WindowingSystemRef, world: WorldType, widget: Widget) =
  if ws.focusedWidget != some(widget):
    if ws.focusedWidget.isSome:
      let w = ws.focusedWidget.get
      discard ws.handleEvent(WidgetFocusLoss(widget: w), world, ws.display)
    ws.focusedWidget = some(widget)
    discard ws.handleEvent(WidgetFocusGain(widget: widget), world, ws.display)

proc hasFocus*(w: Widget): bool =
  w.windowingSystem.focusedWidget.isSome and w.windowingSystem.focusedWidget.get.containsWidget(w)


proc handleEvent*[WorldType](ws: WindowingSystemRef, event: WidgetEvent, world: WorldType, display: DisplayWorld): bool =
  var propagateToParent = true
  matchType(event):
    if event of WidgetMouseMove:
      let widget = event.WidgetMouseMove.widget
      let originatingWidget = event.WidgetMouseMove.originatingWidget
      let position = event.WidgetMouseMove.position

      if widget == originatingWidget and ws.lastWidgetUnderMouse != widget:
        updateLastWidgetUnderMouse[WorldType](ws, widget, world, display)
      break

    extract(WidgetMouseRelease, widget):
      if widget.acceptsFocus:
        if ws.focusedWidget != some(widget):
          ws.giveWidgetFocus(world, widget)
          propagateToParent = false
    extract(WidgetFocusGain):
      propagateToParent = false
    extract(WidgetFocusLoss):
      propagateToParent = false


  let w = event.widget
  when world is World:
    for callback in w.eventCallbacks:
      callback(event, world, display)
      if event.consumed: return true
  elif world is LiveWorld:
    for callback in w.liveWorldEventCallbacks:
      callback(event, world, display)
      if event.consumed: return true
  elif world is WorldView:
    discard
  else:
    warn &"Unsupported world type for handleEvent in windowing system core: {$WorldType}"


  for comp in ws.components:
    comp.handleEvent(w, event, display)
    if event.consumed: return true

  if w.parent.isSome and propagateToParent and not event.nonPropagating:
    if event.originatingWidget == event.widget:
      event.originatingWidget = event.widget
    event.widget = w.parent.get()
    handleEvent(ws, event, world, display)
  else:
    false


proc updateCursorBasedOnWidgetUnderMouse(ws: WindowingSystemRef, w: Widget) =
  if w.cursor.isSome:
    setCursorShape(w.cursor.get)
  elif w.parent.isNone:
    resetCursorShape()
  else:
    updateCursorBasedOnWidgetUnderMouse(ws, w.parent.get)

proc updateLastWidgetUnderMouse[WorldType](ws: WindowingSystemRef, widget: Widget, world: WorldType, display: DisplayWorld) =
  let prev = ws.lastWidgetUnderMouse
  ws.lastWidgetUnderMouse = widget
  updateCursorBasedOnWidgetUnderMouse(ws, widget)



  var pw = prev
  while not pw.isNil:
    if pw.containsWidget(prev) and not pw.containsWidget(widget):
      discard ws.handleEvent(WidgetMouseExit(widget: pw, nonPropagating: true), world, display)
    pw = pw.parent.get(nil)

  pw = widget
  while not pw.isNil:
    if pw.containsWidget(widget) and not pw.containsWidget(prev):
      discard ws.handleEvent(WidgetMouseEnter(widget: pw, nonPropagating: true), world, display)
    pw = pw.parent.get(nil)

import macros

template onEventOfType*(w: Widget, t: typedesc, name: untyped, body: untyped) =
  when not compiles(`t`().originatingWidget):
    {.error: ("widget.onEvent only makes sense for WidgetEvents)").}

  `w`.eventCallbacks.add(proc (evt: UIEvent, worldArg: World, displayWorldArg: DisplayWorld) {.gcsafe.} =
    let display {.inject used.} = displayWorldArg
    if evt of `t`:
      let `name` {.inject used.} = (`t`)evt
      `body`
  )
  `w`.liveWorldEventCallbacks.add(proc (evt: UIEvent, worldArg: LiveWorld, displayWorldArg: DisplayWorld) {.gcsafe.} =
    let display {.inject used.} = displayWorldArg
    if evt of `t`:
      let `name` {.inject used.} = (`t`)evt
      `body`
  )

template onEventOfTypeLW*(w: Widget, t: typedesc, name: untyped, body: untyped) =
  when not compiles(`t`().originatingWidget):
    {.error: ("widget.onEvent only makes sense for WidgetEvents)").}

  `w`.liveWorldEventCallbacks.add(proc (evt: UIEvent, worldArg: LiveWorld, displayWorldArg: DisplayWorld) {.gcsafe.} =
    let display {.inject used.} = displayWorldArg
    let world {.inject used.} = worldArg
    if evt of `t`:
      let `name` {.inject used.} = (`t`)evt
      `body`
  )


template onEventOfTypeW*(w: Widget, t: typedesc, name: untyped, body: untyped) =
  when not compiles(`t`().originatingWidget):
    {.error: ("widget.onEvent only makes sense for WidgetEvents)").}

  `w`.eventCallbacks.add(proc (evt: UIEvent, worldArg: World, displayWorldArg: DisplayWorld) {.gcsafe.} =
    let display {.inject used.} = displayWorldArg
    let world {.inject used.} = worldArg
    if evt of `t`:
      let `name` {.inject used.} = (`t`)evt
      `body`
  )


template onEvent*(w: Widget, body: untyped) =
  `w`.eventCallbacks.add(proc (evtArg: UIEvent, worldArg: World, displayWorldArg: DisplayWorld) {.gcsafe.} =
    block:
      let event {.inject used.} = evtArg
      let display {.inject used.} = displayWorldArg
      let matchTarget {.inject used.} = evtArg
      `body`
  )

  `w`.liveWorldEventCallbacks.add(proc (evtArg: UIEvent, worldArg: LiveWorld, displayWorldArg: DisplayWorld) {.gcsafe.} =
    block:
      let event {.inject used.} = evtArg
      let display {.inject used.} = displayWorldArg
      let matchTarget {.inject used.} = evtArg
      `body`
  )


template onEventW*(w: Widget, body: untyped) =
  `w`.eventCallbacks.add(proc (evtArg: UIEvent, worldArg: World, displayWorldArg: DisplayWorld) {.gcsafe.} =
    block:
      let event {.inject used.} = evtArg
      let display {.inject used.} = displayWorldArg
      let world {.inject used.} = worldArg
      let matchTarget {.inject used.} = evtArg
      `body`
  )


template onEventLW*(w: Widget, body: untyped) =
  `w`.liveWorldEventCallbacks.add(proc (evtArg: UIEvent, worldArg: LiveWorld, displayWorldArg: DisplayWorld) {.gcsafe.} =
    block:
      let event {.inject used.} = evtArg
      let display {.inject used.} = displayWorldArg
      let world {.inject used.} = worldArg
      let matchTarget {.inject used.} = evtArg
      `body`
  )
