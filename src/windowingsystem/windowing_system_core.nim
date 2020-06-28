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

export windowing_rendering

type 
   WidgetEdge* = enum
      Left
      Top
      Right
      Bottom

   NineWayImage* = object
      image* : Bindable[ImageLike]
      pixelScale* : int32
      color* : Bindable[RGBA]
      edgeColor* : Bindable[RGBA]
      draw* : Bindable[bool]
      drawCenter* : bool
      drawEdges* : set[WidgetEdge]

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

   WidgetPosition* = object
      case kind : WidgetPositionKind
      of Fixed: 
         fixedOffset : int
         fixedRelativeTo : WidgetOrientation
      of Proportional:
         proportion : float
         proportionalRelativeTo : WidgetOrientation
      of Absolute:
         absoluteOffset: int
      of Centered:
         discard
      of Relative:
         relativeToWidget : Widget
         relativeOffset : int32
         relativeToWidgetAnchorPoint : WidgetOrientation

   WidgetDimensionKind {.pure.} = enum
      Fixed
      Relative
      Proportional
      ExpandToParent
      Intrinsic
      WrapContent
      ExpandTo
      
   WidgetDimension* = object
      case kind : WidgetDimensionKind
      of WidgetDimensionKind.Fixed:
         fixedSize : int
      of WidgetDimensionKind.Relative:
         sizeDelta : int
      of WidgetDimensionKind.Proportional:
         sizeProportion : float
      of WidgetDimensionKind.ExpandToParent:
         parentGap : int
      of WidgetDimensionKind.Intrinsic:
         discard
      of WidgetDimensionKind.WrapContent:
         discard
      of WidgetDimensionKind.ExpandTo:
         expandToWidget : Widget
         expandToGap : int

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
      windowingSystem* : WindowingSystemRef
      entity : DisplayEntity
      children : seq[Widget]
      dependents : HashSet[Dependent]
      parent_f : Option[Widget]
      identifier* : string
      # core attributes
      background* : NineWayImage
      position : array[3, WidgetPosition]
      resolvedPosition* : Vec3i
      clientOffset* : Vec3i
      padding* : Vec3i
      dimensions : array[2, WidgetDimension]
      resolvedDimensions* : Vec2i
      # drawing caches
      preVertices : seq[WVertex]
      postVertices : seq[WVertex]
      #binding
      bindings : ref Table[string, BoundValue]

   DependencyKind = enum
      Position
      Dimensions

   Dependency = tuple
      widget : Widget
      kind : DependencyKind
      axis : Axis

   Dependent = tuple
      dependentWidget : Widget
      dependsOnKind : DependencyKind
      sourceKind : DependencyKind
      dependsOnAxis : Axis
      sourceAxis : Axis



   WindowingSystem* = object
      display* : DisplayWorld
      desktop* : Widget
      pendingUpdates : Table[Widget, set[RecalculationFlag]]
      pixelScale* : int
      dimensions* : Vec2i
      renderRevision : int
      components* : seq[WindowingComponent]
      # event handling
      focusedWidget : Option[Widget]
      lastWidgetUnderMouse : Widget
      
      # optimization metrics tracking
      updateDependentsCount : int
      updateDimensionsCount : int
      updatePositionCount : int
      renderContentsCount : int

   WindowingSystemRef* = ref WindowingSystem

   WindowingComponent* = ref object of RootRef


defineReflection(WindowingSystem)

const AllEdges = {WidgetEdge.Left,WidgetEdge.Top,WidgetEdge.Right,WidgetEdge.Bottom}

proc childByIdentifier*(e : Widget, identifier : string) : Option[Widget] =
   for c in e.children:
      if c.identifier == identifier:
         return some(c)
   none(Widget)

# =========================================================================================

method render*(ws : WindowingComponent, widget : Widget) : seq[WQuad] {.base.} =
   warn "WindowingComponent must implement render"

method intrinsicSize*(ws : WindowingComponent, widget : Widget, axis : Axis) : Option[int] {.base.} =
   none(int)

method readDataFromConfig*(ws : WindowingComponent, cv : ConfigValue, widget : Widget) {.base.} =
   discard

method updateBindings*(ws : WindowingComponent, widget : Widget, resolver : var BoundValueResolver) {.base.} =
   discard


proc renderContents(ws : WindowingSystemRef, w : Widget, tb : TextureBlock)

var imageMetrics {.threadvar.} : Table[Image, ImageMetrics]
proc imageMetricsFor(img : Image) : ImageMetrics =
   if not imageMetrics.contains(img):
      var metrics = ImageMetrics()

      while metrics.outerOffset < img.width and img[metrics.outerOffset,img.height div 2,3] == 0:
         metrics.outerOffset += 1
      metrics.borderWidth = metrics.outerOffset
      while metrics.borderWidth < img.width and img[metrics.borderWidth,img.height div 2,3] > 0:
         metrics.borderWidth += 1
      metrics.centerColor = img[img.width - 1 , 0][]
      imageMetrics[img] = metrics
   imageMetrics[img]


proc isIntrinsic*(dim : WidgetDimension) : bool = dim.kind == WidgetDimensionKind.Intrinsic

proc nineWayImage*(img : ImageLike, pixelScale : int = 1, color : RGBA = rgba(1.0f,1.0f,1.0f,1.0f), edges : set[WidgetEdge] = AllEdges) : NineWayImage =
   NineWayImage(
      image : bindable(img),
      pixelScale : pixelScale.int32,
      color : bindable(color),
      edgeColor : bindable(color),
      draw: bindable(true),
      drawCenter : true,
      drawEdges : edges
   )

iterator quadToVertices(quad : WQuad, tb : TextureBlock, bounds : Bounds) : WVertex =
    var tc : array[4,Vec2f]
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
        
    
    let pos = vec3f(quad.position)
    let dim = vec2f(quad.dimensions)
    let fwd = vec3f(quad.forward.x, quad.forward.y, 0.0f)
    let oto = vec3f(-fwd.y,fwd.x, 0.0f)

    
    yield WVertex(vertex : pos, color : quad.color, texCoords : tc[3], boundsOrigin : bounds.origin, boundsDirection : bounds.direction, boundsDimensions : bounds.dimensions)
    yield WVertex(vertex : pos + fwd * dim.x, color : quad.color, texCoords : tc[2], boundsOrigin : bounds.origin, boundsDirection : bounds.direction, boundsDimensions : bounds.dimensions)
    yield WVertex(vertex : pos + fwd * dim.x + oto * dim.y, color : quad.color, texCoords : tc[1], boundsOrigin : bounds.origin, boundsDirection : bounds.direction, boundsDimensions : bounds.dimensions)
    yield WVertex(vertex : pos + oto * dim.y, color : quad.color, texCoords : tc[0], boundsOrigin : bounds.origin, boundsDirection : bounds.direction, boundsDimensions : bounds.dimensions)

proc fixedSize*(size : int) : WidgetDimension = WidgetDimension(kind : WidgetDimensionKind.Fixed, fixedSize : size)
proc relativeSize*(sizeDelta : int) : WidgetDimension = WidgetDimension(kind : WidgetDimensionKind.Relative, sizeDelta : sizeDelta)
proc proportionalSize*(proportion : float) : WidgetDimension = WidgetDimension(kind : WidgetDimensionKind.Proportional, sizeProportion : proportion)
proc wrapContent*() : WidgetDimension = WidgetDimension(kind : WidgetDimensionKind.WrapContent)
proc expandToParent*(gap : int = 0) : WidgetDimension = WidgetDimension(kind : WidgetDimensionKind.ExpandToParent, parentGap : gap)
proc intrinsic*() : WidgetDimension = WidgetDimension(kind : WidgetDimensionKind.Intrinsic)

proc centered*() : WidgetPosition = WidgetPosition(kind : WidgetPositionKind.Centered)
proc absolutePos*(pos : int) : WidgetPosition = WidgetPosition(kind : WidgetPositionKind.Absolute, absoluteOffset : pos)
proc fixedPos*(pos : int, relativeTo : WidgetOrientation = WidgetOrientation.TopLeft) : WidgetPosition = WidgetPosition(kind : WidgetPositionKind.Fixed, fixedOffset : pos, fixedRelativeTo : relativeTo)
proc proportionalPos*(proportion : float, relativeTo : WidgetOrientation = WidgetOrientation.TopLeft) : WidgetPosition = 
   WidgetPosition(kind : WidgetPositionKind.Proportional, proportion : proportion, proportionalRelativeTo : relativeTo)
proc relativePos*(relativeTo : Widget, offset : int32, anchorPoint : WidgetOrientation = WidgetOrientation.TopLeft): WidgetPosition =
   WidgetPosition(kind : WidgetPositionKind.Relative, relativeToWidget : relativeTo, relativeOffset : offset, relativeToWidgetAnchorPoint : anchorPoint)

proc hash*(w : Widget) : Hash = w.entity.hash
proc `==`*(a,b : Widget) : bool = a.entity == b.entity

proc markForUpdate*(ws : WindowingSystemRef, w : Widget, r : RecalculationFlag) =
   fine "marking for update : " , $w.entity , " ", $r
   ws.pendingUpdates.mgetOrPut(w,{}).incl(r)

proc markForUpdate*(w : Widget, r : RecalculationFlag) =
   if w.windowingSystem != nil:
      w.windowingSystem.markForUpdate(w, r)

proc isFarSide(axis : Axis, relativeTo : WidgetOrientation) : bool =
   (axis == Axis.X and (relativeTo == TopRight or relativeTo == BottomRight)) or
   (axis == Axis.Y and (relativeTo == BottomRight or relativeTo == BottomLeft))


iterator dependentOn(p : WidgetPosition, axis : Axis, widget : Widget, parent : Widget) : Dependency =
   case p.kind:
   of WidgetPositionKind.Fixed:  
      yield (widget : parent, kind : DependencyKind.Position, axis : axis)
      if isFarSide(axis, p.fixedRelativeTo):
         yield (widget : widget, kind : DependencyKind.Dimensions, axis : axis)
   of WidgetPositionKind.Proportional:
      yield (widget : parent, kind : DependencyKind.Dimensions, axis : axis)
      yield (widget : parent, kind : DependencyKind.Position, axis : axis)
      if isFarSide(axis, p.proportionalRelativeTo):
         yield (widget : widget, kind : DependencyKind.Dimensions, axis : axis)
   of WidgetPositionKind.Centered:
      yield (widget : parent, kind : DependencyKind.Dimensions, axis : axis)
      yield (widget : parent, kind : DependencyKind.Position, axis : axis)
      yield (widget : widget, kind : DependencyKind.Dimensions, axis : axis)
   of WidgetPositionKind.Relative: 
      yield (widget : p.relativeToWidget, kind : DependencyKind.Position, axis : axis)
      yield (widget : p.relativeToWidget, kind : DependencyKind.Dimensions, axis : axis)
      if not isFarSide(axis, p.relativeToWidgetAnchorPoint):
         yield (widget : widget, kind : DependencyKind.Dimensions, axis : axis)

   of WidgetPositionKind.Absolute: 
      discard

iterator dependentOn(p : WidgetDimension, axis : Axis, widget : Widget, parent : Widget, children : seq[Widget]) : Dependency =
   case p.kind:
      of WidgetDimensionKind.Fixed: 
         discard
      of WidgetDimensionKind.Proportional,WidgetDimensionKind.Relative:
         yield (widget: parent, kind : DependencyKind.Dimensions, axis : axis)
      of WidgetDimensionKind.ExpandToParent: 
         yield (widget: parent, kind : DependencyKind.Dimensions, axis : axis)
         yield (widget: widget, kind : DependencyKind.Position, axis : axis)
      of WidgetDimensionKind.Intrinsic:
         if not widget.dimensions[axis.oppositeAxis2d().ord].isIntrinsic:
            yield (widget : widget, kind : DependencyKind.Dimensions, axis : axis.oppositeAxis2d())
      of WidgetDimensionKind.WrapContent: 
         for c in children:
            yield (widget : c, kind : DependencyKind.Position, axis : axis)
            yield (widget : c, kind : DependencyKind.Dimensions, axis : axis)
      of WidgetDimensionKind.ExpandTo: 
         yield (widget : p.expandtoWidget, kind : DependencyKind.Position, axis : axis)
         yield (widget : p.expandtoWidget, kind : DependencyKind.Dimensions, axis : axis) # todo: this could probably be tightened up a little bit

proc toDependent(w : Widget, srcAxis : Axis, srcKind : DependencyKind, dep : Dependency) : Dependent =
   (dependentWidget : w, dependsOnKind : dep.kind, sourceKind : srcKind, dependsOnAxis : dep.axis, sourceAxis : srcAxis)


proc parent*(w : Widget) : Option[Widget] = w.parent_f
proc `parent=`*(w : Widget, parent : Widget) =
   if w.parent_f.isSome:
      let oldP = w.parent_f.get
      for i in 0 ..< oldP.children.len:
         if oldP.children[i] == w:
            oldP.children.del(i)
            break

   w.parent_f = some(parent)
   parent.children.add(w)
   for e in enumValues(RecalculationFlag):
      w.markForUpdate(e)
   

proc createWidget*(ws : WindowingSystemRef, parent : Widget = nil) : Widget =
   result = new Widget
   result.windowingSystem = ws
   result.entity = ws.display.createEntity()
   result.dimensions = [WidgetDimension(kind : WidgetDimensionKind.Intrinsic), WidgetDimension(kind : WidgetDimensionKind.Intrinsic)]
   if parent.isNil:
      result.parent = ws.desktop
   else:
      result.parent = parent


proc `x=`*(w : Widget, p : WidgetPosition) =
   w.position[0] = p
   w.markForUpdate(RecalculationFlag.PositionX)
   w.markForUpdate(RecalculationFlag.DependentX)
   # w.markForUpdate(Axis.X)

proc `y=`*(w : Widget, p : WidgetPosition) =
   w.position[1] = p
   w.markForUpdate(RecalculationFlag.PositionY)
   w.markForUpdate(RecalculationFlag.DependentY)
   # w.markForUpdate(Axis.Y)

proc `z=`*(w : Widget, p : WidgetPosition) =
   w.position[2] = p
   w.markForUpdate(RecalculationFlag.PositionZ)
   w.markForUpdate(RecalculationFlag.DependentZ)
   # w.markForUpdate(Axis.Z)

proc `width=`*(w : Widget, p : WidgetDimension) =
   w.dimensions[0] = p
   w.markForUpdate(RecalculationFlag.DimensionsX)
   w.markForUpdate(RecalculationFlag.DependentX)
   # w.markForUpdate(Axis.X)

proc `height=`*(w : Widget, p : WidgetDimension) =
   w.dimensions[1] = p
   w.markForUpdate(RecalculationFlag.DimensionsY)
   w.markForUpdate(RecalculationFlag.DependentY)
   # w.markForUpdate(Axis.Y)

proc width*(w : Widget) : WidgetDimension = w.dimensions[0]
proc height*(w : Widget) : WidgetDimension = w.dimensions[1]

# converter toEntity* (w : Widget) : DisplayEntity = w.entity
proc `$`*(w : Widget) : string = "Widget(" & $w.entity.int & ")"

proc recalculateDependents(w : Widget, axis : Axis) =
   if w.parent.isSome:
      fine "recalculating dependents for widget ", w.entity, " ", axis

      for dep in dependentOn(w.position[axis.ord], axis, w, w.parent.get):
         dep.widget.dependents.incl(toDependent(w, axis, DependencyKind.Position, dep))
      if axis == Axis.X or axis == Axis.Y:
         for dep in dependentOn(w.dimensions[axis.ord], axis, w, w.parent.get, w.children):
            dep.widget.dependents.incl(toDependent(w, axis, DependencyKind.Dimensions, dep))



   

proc posFlag(axis : Axis) : RecalculationFlag =
   case axis:
   of Axis.X : RecalculationFlag.PositionX
   of Axis.Y : RecalculationFlag.PositionY
   of Axis.Z : RecalculationFlag.PositionZ

proc dimFlag(axis : Axis) : RecalculationFlag =
   case axis:
   of Axis.X : RecalculationFlag.DimensionsX
   of Axis.Y : RecalculationFlag.DimensionsY
   of Axis.Z : 
      warn "no z dimension flag"
      RecalculationFlag.DimensionsY

proc depFlag(axis : Axis) : RecalculationFlag =
   case axis:
   of Axis.X : RecalculationFlag.DependentX
   of Axis.Y : RecalculationFlag.DependentY
   of Axis.Z : RecalculationFlag.DependentZ

proc ensureDependency(dep : Dependency, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency])
proc updateDependent(dep : Dependent, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency])

proc recalculatePosition(w : Widget, axis : Axis, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency]) =
   let completedKey = (widget:w,kind:DependencyKind.Position,axis:axis)
   if completedSet.containsOrIncl(completedKey):
      return
   fine "recalculating position for widget ", w.entity, " ", axis
   w.resolvedPosition[axis.ord] = 0

   let pos = w.position[axis.ord]
   
   if w.background.draw:
      w.clientOffset[axis] = imageMetricsFor(w.background.image.value).borderWidth * w.background.pixelScale + w.padding[axis] * 2

   if w.parent.isSome:
      for dep in dependentOn(pos, axis, w, w.parent.get):
         if dirtySet.contains(dep):
            ensureDependency(dep, dirtySet, completedSet)

      let parentV = w.parent.get.resolvedPosition[axis] + w.parent.get.clientOffset[axis]
      let parentD = w.parent.get.resolvedDimensions[axis] - w.parent.get.clientOffset[axis] * 2
      w.resolvedPosition[axis] = case pos.kind:
      of WidgetPositionKind.Fixed:  
         if isFarSide(axis, pos.fixedRelativeTo):
            parentV + parentD - pos.fixedOffset - w.resolvedDimensions[axis]
         else:
            parentV + pos.fixedOffset
      of WidgetPositionKind.Proportional:
         if isFarSide(axis, pos.proportionalRelativeTo):
            parentV + parentD - (parentD.float * pos.proportion).int - w.resolvedDimensions[axis]
         else:
            parentV + (parentD.float * pos.proportion).int
      of WidgetPositionKind.Centered:
         echo fmt"own dim {w.resolvedDimensions[axis]}, parent dim {parentD}"
         parentV + (parentD - w.resolvedDimensions[axis]) div 2
      of WidgetPositionKind.Relative: 
         if isFarSide(axis, pos.relativeToWidgetAnchorPoint):
            pos.relativeToWidget.resolvedPosition[axis] + pos.relativeToWidget.resolvedDimensions[axis] + pos.relativeOffset
         else:
            pos.relativeToWidget.resolvedPosition[axis] - pos.relativeOffset - w.resolvedDimensions[axis]
      of WidgetPositionKind.Absolute: 
         pos.absoluteOffset
         
   

proc recalculateDimensions(w : Widget, axis : Axis, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency]) =
   # let pixelScale = w.windowingSystem.pixelScale

   let completedKey = (widget:w,kind:DependencyKind.Dimensions,axis:axis)
   if completedSet.containsOrIncl(completedKey):
      return
   fine "recalculating dimensions for widget ", w.entity, " ", axis
   w.resolvedDimensions[axis.ord] = 0

   let dim = w.dimensions[axis.ord]

   if w.background.draw:
      w.clientOffset[axis] = imageMetricsFor(w.background.image.value).borderWidth * w.background.pixelScale + w.padding[axis] * 2

   if w.parent.isSome:
      for dep in dependentOn(dim, axis, w, w.parent.get, w.children):
         if dirtySet.contains(dep):
            ensureDependency(dep, dirtySet, completedSet)

      let parentV = w.parent.get.resolvedPosition[axis] + w.parent.get.clientOffset[axis]
      let parentD = w.parent.get.resolvedDimensions[axis] - w.parent.get.clientOffset[axis] * 2
      w.resolvedDimensions[axis] = case dim.kind:
      of WidgetDimensionKind.Fixed: 
         dim.fixedSize
      of WidgetDimensionKind.Relative:
         parentD + dim.sizeDelta
      of WidgetDimensionKind.Proportional:
         (parentD.float * dim.sizeProportion).int
      of WidgetDimensionKind.ExpandToParent:
         let relativePos = w.resolvedPosition[axis] - parentV
         parentD - dim.parentGap - relativePos
      of WidgetDimensionKind.Intrinsic: 
         var intrinsicSize : Option[int] = none(int)
         for renderer in w.windowingSystem.components:
            intrinsicSize = renderer.intrinsicSize(w, axis)
            if intrinsicSize.isSome: break

         if intrinsicSize.isSome:
            intrinsicSize.get + w.clientOffset[axis] * 2
         else:
            warn "intrinsic sized widget with no intrinsic qualities", w.identifier
            10
      of WidgetDimensionKind.WrapContent: 
         var min : int = 0
         var max : int = 0
         let selfP = w.resolvedPosition[axis]
         for c in w.children:
            min = min.min(c.resolvedPosition[axis] - selfP)
            max = max.max(c.resolvedPosition[axis] - selfP + c.resolvedDimensions[axis])
         if max > min:
            max - min + w.clientOffset[axis] * 2
         else:
            0
      of WidgetDimensionKind.ExpandTo: 
         dim.expandToWidget.resolvedPosition[axis] - dim.expandToGap - w.resolvedPosition[axis]
   else:
      w.resolvedDimensions[axis] = w.windowingSystem.dimensions[axis]

proc ensureDependency(dep : Dependency, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency]) =
   if not completedSet.contains(dep):
      case dep.kind:
      of DependencyKind.Position: 
         dep.widget.windowingSystem.updatePositionCount.inc
         dep.widget.recalculatePosition(dep.axis, dirtySet, completedSet)
      of DependencyKind.Dimensions: 
         fine "Updating dimensions(", dep.axis, ") for widget ", dep.widget.identifier
         dep.widget.windowingSystem.updateDimensionsCount.inc
         dep.widget.recalculateDimensions(dep.axis, dirtySet, completedSet)
      completedSet.incl(dep)

proc updateDependent(dep : Dependent, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency]) =
   case dep.sourceKind:
   of DependencyKind.Position: dep.dependentWidget.recalculatePosition(dep.sourceAxis, dirtySet, completedSet)
   of DependencyKind.Dimensions: dep.dependentWidget.recalculateDimensions(dep.sourceAxis, dirtySet, completedSet)

proc collectDirty(dep : Dependency, dirty : var HashSet[Dependency]) =
   for dependent in dep.widget.dependents:
      if dependent.dependsOnAxis == dep.axis and dependent.dependsOnKind == dep.kind:
         let newDep = (widget:dependent.dependentWidget, kind : dependent.sourceKind, axis : dependent.sourceAxis)
         if not dirty.containsOrIncl(newDep):
            collectDirty(newDep, dirty)


# proc recursivelyCollectDependents(w : )

proc update*(ws : WindowingSystemRef, tb : TextureBlock) =
   ws.updateDependentsCount = 0
   ws.updateDimensionsCount = 0
   ws.updatePositionCount = 0
   ws.renderContentsCount = 0

   let expectedDimensions = ws.display[GraphicsContextData].framebufferSize div ws.pixelScale + 1
   if ws.dimensions != expectedDimensions:
      ws.dimensions = expectedDimensions
      ws.desktop.markForUpdate(RecalculationFlag.DimensionsX)
      ws.desktop.markForUpdate(RecalculationFlag.DimensionsY)

   fine "Pending updates: ", ws.pendingUpdates
   for w,v in ws.pendingUpdates:
      for axis in axes():
         if v.contains(depFlag(axis)):
            ws.updateDependentsCount.inc
            w.recalculateDependents(axis)
   
   var dirtySet : HashSet[Dependency]
   var completedSet : HashSet[Dependency]
   var rerenderSet : HashSet[Widget]
   for w,v in ws.pendingUpdates:
      if v.contains(RecalculationFlag.Contents):
         rerenderSet.incl(w)
      for axis in axes2d():
         if v.contains(dimFlag(axis)) or v.contains(depFlag(axis)):
            # w.recalculateDimensions(axis, completedSet)
            dirtySet.incl((widget:w, kind: DependencyKind.Dimensions, axis : axis))
            collectDirty((widget:w, kind: DependencyKind.Dimensions, axis : axis), dirtySet)
         if v.contains(posFlag(axis)) or v.contains(depFlag(axis)):
            # w.recalculatePosition(axis, completedSet)
            dirtySet.incl((widget:w, kind: DependencyKind.Position, axis : axis))
            collectDirty((widget:w, kind: DependencyKind.Position, axis : axis), dirtySet)

   for dsDep in dirtySet:
      ensureDependency(dsDep, dirtySet, completedSet)

   for completed in completedSet:
      rerenderSet.incl(completed.widget)

   if rerenderSet.len != 0:
      for widget in rerenderSet:
         ws.renderContentsCount.inc
         renderContents(ws, widget, tb)
      ws.renderRevision.inc
      info "Re-rendered"

   ws.pendingUpdates.clear()

   if ws.renderContentsCount + ws.updateDependentsCount + ws.updateDimensionsCount + ws.updatePositionCount > 0:
      info "contents renders: ", ws.renderContentsCount
      info "dependents recalc: ", ws.updateDependentsCount
      info "dimensions recalc: ", ws.updateDimensionsCount
      info "position recalc: ", ws.updatePositionCount


type Corner = object
   enabled : bool
   dimensions : Vec2i


const edgeAxes : array[4,Axis] = [Axis.Y,Axis.X,Axis.Y,Axis.X]
# const cornerRects : array[4,Rectf] = [
#    rect(vec2f(0.0f,0.0f), rectf)
# ]

iterator nineWayImageQuads(nwi : NineWayImage, dim : Vec2i, pixelScale : int) : WQuad =
   let img = nwi.image.asImage
   let imgLike = imageLike(img)
   let imgMetrics = imageMetricsFor(img)
   
   let fwd = vec3f(1,0,0)
   let oto = vec3f(0,1,0)
   let basis = [fwd, oto]

   var cornerDim : Vec2i = (img.dimensions div 2) * nwi.pixelScale * pixelScale
   var cornerPercents : Vec2f = vec2f(1.0,1.0)
   for axis in axes2d():
      if cornerDim[axis] > dim[axis] div 2:
         cornerPercents[axis] = (dim[axis] / 2) / cornerDim[axis].float
         cornerDim[axis] = (dim[axis] div 2) + 1

   let farDims = dim - cornerDim
   let ctcPos = vec2f(0.0f, 1.0f - 0.5f * cornerPercents.y)
   let ctcDim = cornerPercents * 0.5f
   let cornerSubRect = rect(ctcPos, ctcDim)

   var corners : array[4,Corner]
   for q in 0 ..< 4:
      corners[q].enabled = nwi.drawEdges.contains(q.WidgetEdge) and nwi.drawEdges.contains(((q+1) mod 4).WidgetEdge)
      if corners[q].enabled:
         corners[q].dimensions = cornerDim
   
   if nwi.drawCenter:
      let centerOffset = imgMetrics.borderWidth * nwi.pixelScale * pixelScale - 1
      let startX = if nwi.drawEdges.contains(WidgetEdge.Left) : centerOffset else: 0
      let startY = if nwi.drawEdges.contains(WidgetEdge.Top) : centerOffset else: 0
      let endX = if nwi.drawEdges.contains(WidgetEdge.Right) : dim.x - centerOffset else: 0
      let endY = if nwi.drawEdges.contains(WidgetEdge.Bottom) : dim.y - centerOffset else: 0
      let pos = fwd * startX.float32 + oto * startY.float32
      yield WQuad(position : pos, dimensions : vec2i(endX-startX+1, endY-startY+1), forward : fwd.xy, texCoords : noImageTexCoords(), color : nwi.color * imgMetrics.centerColor, beforeChildren : true)

   for q in 0 ..< 4:
      if corners[q].enabled:
         let pos = fwd * farDims.x.float32 * UnitSquareVertices[q].x + oto * farDims.y.float32 * UnitSquareVertices[q].y
         let tc = subRectTexCoords(cornerSubRect, q mod 3 != 0, q >= 2)
         yield WQuad(position : pos, dimensions : cornerDim, forward : fwd.xy, image : imgLike, color : nwi.edgeColor, texCoords : tc, beforeChildren : false)

      if nwi.drawEdges.contains(q.WidgetEdge):
         let primaryAxis = edgeAxes[q].ord
         let secondaryAxis = 1 - primaryAxis
         if dim[primaryAxis] > cornerDim[primaryAxis] * 2:
            var pos = basis[primaryAxis] * cornerDim[primaryAxis].float + 
                     basis[secondaryAxis] * farDims[secondaryAxis].float * UnitSquareVertices2d[q][secondaryAxis]
            var edgeDim : Vec2i
            edgeDim[primaryAxis] = dim[primaryAxis] - corners[(q+3) mod 4].dimensions[primaryAxis] - corners[q].dimensions[primaryAxis]
            edgeDim[secondaryAxis] = cornerDim[secondaryAxis]
            
            var imgSubRect : Rectf
            imgSubRect.position[primaryAxis] = 0.5f - ctcPos[primaryAxis]
            imgSubRect.position[secondaryAxis] = ctcPos[secondaryAxis]
            imgSubRect.dimensions[secondaryAxis] = ctcDim[secondaryAxis]

            yield WQuad(position : pos, dimensions : edgeDim, forward : fwd.xy, image : imgLike, color : nwi.edgeColor, texCoords : subRectTexCoords(imgSubRect, q >= 2, q >= 2), beforeChildren : false)
            
            

   
proc addQuadToWidget(w : Widget, tb : TextureBlock, quad : WQuad, offset : Vec2i) =
   for vertex in quadToVertices(quad, tb, Bounds()):
      if quad.beforeChildren:
         w.preVertices.add(vertex)
         w.preVertices[w.preVertices.len-1].vertex.x += offset.x.float
         w.preVertices[w.preVertices.len-1].vertex.y += offset.y.float
      else:
         w.postVertices.add(vertex)
         w.postVertices[w.postVertices.len-1].vertex.x += offset.x.float
         w.postVertices[w.postVertices.len-1].vertex.y += offset.y.float

proc renderContents(ws : WindowingSystemRef, w : Widget, tb : TextureBlock) =
   fine "Rendering widget ", w
   w.preVertices.setLen(0)
   w.postVertices.setLen(0)

   if w.background.draw:
      for quad in w.background.nineWayImageQuads(w.resolvedDimensions, 1):
         addQuadToWidget(w, tb, quad, w.resolvedPosition.xy)

   for renderer in ws.components:
      let quads = renderer.render(w)
      for quad in quads:
         addQuadToWidget(w, tb, quad, w.resolvedPosition.xy + w.clientOffset.xy)

proc render(ws : WindowingSystemRef, w : Widget, vao : VAO[WVertex,uint32], tb : TextureBlock, vi,ii : var int) =
   fine "Rendering widget ", w
   for i in 0 ..< (w.preVertices.len div 4):
      for q in 0 ..< 4:
         vao[vi+q][] = w.preVertices[i*4+q]
      vao.addIQuad(ii, vi)

   for child in w.children:
      render(ws, child, vao, tb, vi, ii)

   for i in 0 ..< (w.postVertices.len div 4):
      for q in 0 ..< 4:
         vao[vi+q][] = w.postVertices[i*4+q]
      vao.addIQuad(ii, vi)

proc render*(ws : WindowingSystemRef, vao : VAO[WVertex,uint32], textureBlock : TextureBlock) =
   if vao.revision < ws.renderRevision:
      var vi,ii : int = 0

      ws.render(ws.desktop, vao, textureBlock, vi, ii)

      info "Swapping ui vao"
      vao.swap()
      vao.revision = ws.renderRevision



proc data*[T](widget : Widget, t : typedesc[T]) : ref T =
   widget.windowingSystem.display.data(widget.entity, t)

proc hasData*[T](widget : Widget, t : typedesc[T]) : bool =
   widget.windowingSystem.display.hasData(widget.entity, t)

proc attachData*[T](widget : Widget, valueIn : T) =
   var value = valueIn
   when compiles(value.widget):
      value.widget = widget
   # else:
      # echo "could not attach data"
   widget.windowingSystem.display.attachData(widget.entity, value)



proc readFromConfig*(cv : ConfigValue, e : var WidgetEdge) =
   if cv.nonEmpty:
      if cv.isStr:
         case cv.asStr.toLowerAscii:
         of "left": e = WidgetEdge.Left
         of "right": e = WidgetEdge.Right
         of "top": e = WidgetEdge.Top
         of "bottom": e = WidgetEdge.Bottom
         else: 
            warn "Invalid widget edge: ", cv.asStr
      else:
         warn "Invalid widget edge config: ", cv

proc parseStr(str: string, t : typedesc[WidgetOrientation]) : Option[WidgetOrientation] =
   case str.toLowerAscii.replace(" ",""):
      of "topleft": some(WidgetOrientation.TopLeft)
      of "left" : some(WidgetOrientation.TopLeft)
      of "topright": some(WidgetOrientation.TopRight)
      of "right" : some(WidgetOrientation.TopRight)
      of "bottomleft": some(WidgetOrientation.BottomLeft)
      of "bottom" : some(WidgetOrientation.BottomLeft)
      of "bottomright": some(WidgetOrientation.BottomRight)
      of "top" : some(WidgetOrientation.TopLeft)
      of "center": some(WidgetOrientation.Center)
      else: none(WidgetOrientation)
            

proc readFromConfig*(cv : ConfigValue, e : var WidgetOrientation) =
   if cv.nonEmpty:
      if cv.isStr:
         let wopt = parseStr(cv.asStr, WidgetOrientation)
         if wopt.isSome:
            e = wopt.get
         else:
            warn "Invalid widget orientation: ", cv.asStr
      else:
         warn "Invalid widget orientation config: ", cv

const orientedConstantPattern = re"(?i)([0-9]+) from (.*)"
const orientedProportionPattern = re"(?i)([0-9.]+) from (.*)"
const rightLeftPattern = re"(?i)([0-9]+) (right|left) of ([a-zA-Z0-9]+)"
const belowAbovePattern = re"(?i)([0-9]+) (below|above) ([a-zA-Z0-9]+)"
const expandToParentPattern = re"(?i)expand\s?to\s?parent\(([0-9]+)\)"
const percentagePattern = re"([0-9]+)%"
const centeredPattern = re"(?i)center(ed)?"

proc readFromConfig*(cv : ConfigValue, e : var WidgetPosition, widget : Widget) =
   if cv.nonEmpty:
      if cv.isNumber:
         let num = cv.asFloat
         if num > 1.0 or num < 0.0:
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
               else: warn fmt"failed to parse widget oriented constant position : {distStr}, {relativeToStr}"
            extractMatches(orientedProportionPattern, propStr, relativeToStr):
               let prop = parseFloatOpt(propStr)
               let relativeTo = parseStr(relativeToStr, WidgetOrientation)
               if prop.isSome and relativeTo.isSome:
                  e = proportionalPos(prop.get, relativeTo.get)
               warn fmt"failed to parse widget oriented proportional position : {propStr}, {relativeToStr}"
            extractMatches(rightLeftPattern, distStr, dirStr, targetStr):
               let dir = if dirStr.toLowerAscii == "right": WidgetOrientation.TopRight else: WidgetOrientation.TopLeft
               let target = widget.parent.get.childByIdentifier(targetStr)
               if target.isSome:
                  e = relativePos(target.get, parseInt(distStr).int32, dir)
               else:
                  warn fmt"failed to parse widget right/left relative position : {distStr}, {dirStr}, {targetStr}"
            extractMatches(belowAbovePattern, distStr, dirStr, targetStr):
               let dir = if dirStr.toLowerAscii == "below": WidgetOrientation.BottomLeft else: WidgetOrientation.TopLeft
               let target = widget.parent.get.childByIdentifier(targetStr)
               if target.isSome:
                  e = relativePos(target.get, parseInt(distStr).int32, dir)
               else:
                  warn "failed to parse widget above/below relative position : ", str
            extractMatches(centeredPattern, distStr):
               e = centered()
            warn "unsupported position expression: ", str
      else:
         warn "Invalid config for widget dimension : ", cv

proc readFromConfig*(cv : ConfigValue, e : var WidgetDimension) =
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
         matcher(cv.asStr):
            extractMatches(expandToParentPattern, gapStr):
               e = expandToParent(parseInt(gapStr))
            extractMatches(percentagePattern, percentStr):
               e = proportionalSize(parseInt(percentStr).float / 100.0)
            warn "unsupported dimension expression: ", cv.asStr
      else:
         warn "Invalid config for widget position : ", cv

proc readFromConfig*(cv : ConfigValue, e : var NineWayImage) =
   readIntoOrElse(cv["image"], e.image, bindable(imageLike("ui/minimalistBorder.png")))
   readIntoOrElse(cv["pixelScale"], e.pixelScale, 1.int32)
   readIntoOrElse(cv["color"], e.color, bindable(rgba(255,255,255,255)))
   readIntoOrElse(cv["edgeColor"], e.edgeColor, bindable(rgba(255,255,255,255)))
   readIntoOrElse(cv["draw"], e.draw, bindable(true))
   readIntoOrElse(cv["drawCenter"], e.drawCenter, true)
   readIntoOrElse(cv["drawEdges"], e.drawEdges, AllEdges)


proc populateChildren(cv : ConfigValue, e : var Widget) = 
   let childrenCV = cv["children"]
   if childrenCV.isObj:
      for k,childCV in cv["children"].fields:
         let existing = e.childByIdentifier(k)
         if not existing.isSome:
            let newChild = e.windowingSystem.createWidget(e)
            newChild.identifier = k
            e.children.add(newChild)

proc readFromConfig*(cv : ConfigValue, e : var Widget) =
   populateChildren(cv, e)

   readFromConfig(cv["background"], e.background)
   readFromConfig(cv["x"], e.position[0], e)
   readFromConfig(cv["y"], e.position[1], e)
   readFromConfig(cv["z"], e.position[2], e)
   readFromConfig(cv["width"], e.dimensions[0])
   readFromConfig(cv["height"], e.dimensions[1])
   readFromConfig(cv["padding"], e.padding)

   for comp in e.windowingSystem.components:
      comp.readDataFromConfig(cv, e)

   let childrenCV = cv["children"]
   if childrenCV.isObj:
      for k,childCV in cv["children"].fields:
         var child = e.childByIdentifier(k)
         if child.isSome:
            readFromConfig(childCV, child.get)
         else:
            warn "somehow child config did not match identifiers with existing child"

proc createWidgetFromConfig*(ws : WindowingSystemRef, identifier : string, cv : ConfigValue, parent : Widget) : Widget =
   result = ws.createWidget(parent)
   readInto(cv, result)


proc createWidget*(ws : WindowingSystemRef, confPath : string, identifier : string, parent : Widget = nil) : Widget =
   createWidgetFromConfig(ws, identifier, resources.config(confPath)[identifier], parent)

proc updateWidgetBindings(widget : Widget, resolver : var BoundValueResolver) =
   if not widget.bindings.isNil:
      resolver.boundValues.add(widget.bindings)
   if updateBindings(widget[], resolver):
      widget.markForUpdate(RecalculationFlag.Contents)
   for comp in widget.windowingSystem.components:
      comp.updateBindings(widget, resolver)

   for c in widget.children:
      updateWidgetBindings(c, resolver)

   if not widget.bindings.isNil:
      resolver.boundValues.del(resolver.boundValues.len-1)

proc bindValue*[T](widget : Widget, key : string, value : T) =
   if widget.bindings.isNil:
      widget.bindings = newTable[string, BoundValue]()
   bindValueInto(key, value, widget.bindings[])
   var resolver = BoundValueResolver()
   updateWidgetBindings(widget, resolver)