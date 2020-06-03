import worlds
import prelude
import options
import graphics
import sets
import hashes
import tables
import noto
import arxmath

type 
    WidgetEdge* = enum
        Left
        Top
        Right
        Bottom

    NineWayImage* = object
        image* : ImageLike
        pixelScale* : int32
        color* : RGBA
        edgeColor* : RGBA
        draw* : bool
        drawCenter* : bool
        drawEdges* : set[WidgetEdge]

    WidgetOrientation = enum
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

    RecalculationFlag = enum
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
        windowingSystem : WindowingSystem
        entity : DisplayEntity
        children : seq[Widget]
        dependents : HashSet[Dependent]
        parent_f : Option[Widget]
        background* : NineWayImage
        position : array[3, WidgetPosition]
        resolvedPosition : Vec3i
        clientOffset : Vec3i
        dimensions : array[2, WidgetDimension]
        resolvedDimensions : Vec2i
        preVertices : seq[WVertex]
        postVertices : seq[WVertex]

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



    WindowingSystem* = ref object
        display : DisplayWorld
        desktop* : Widget
        pendingUpdates : Table[Widget, set[RecalculationFlag]]
        pixelScale* : int
        dimensions : Vec2i
        renderRevision : int

    Bounds* = object
        origin : Vec2f
        direction : Vec2f
        dimensions : Vec2f

    WVertex* = object
        vertex* : Vec3f
        color* : RGBA
        texCoords* : Vec2f
        boundsOrigin* : Vec2f
        boundsDirection* : Vec2f
        boundsDimensions* : Vec2f

    WTexCoordKind = enum
        NoImage
        Simple
        SubRect
        RawTexCoords
        NormalizedTexCoords
        

    WTexCoords* = object
        case kind: WTexCoordKind
        of NoImage:
            discard
        of Simple: 
            flip : Vec2b
        of RawTexCoords: 
            rawTexCoords : array[4,Vec2f]
        of NormalizedTexCoords:
            texCoords : array[4,Vec2f]
        of SubRect: 
            subRect : Rectf
            flipSubRect : Vec2b

    WQuad* = object
        position* : Vec3f
        dimensions* : Vec2i
        forward* : Vec2f
        image* : ImageLike
        texCoords* : WTexCoords
        color* : RGBA
        beforeChildren* : bool

    ImageMetrics = object
        borderWidth : int
        centerColor : RGBA
        outerOffset : int


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

const AllEdges = {WidgetEdge.Left,WidgetEdge.Top,WidgetEdge.Right,WidgetEdge.Bottom}

proc simpleTexCoords*(flipX : bool, flipY : bool) : WTexCoords =
    WTexCoords(kind : Simple, flip : vec2(flipX, flipY))
proc rawTexCoords*(tc : array[4,Vec2f]) : WTexCoords =
    WTexCoords(kind : RawTexCoords, rawTexCoords : tc)
proc normTexCoords*(tc : array[4,Vec2f]) : WTexCoords =
    WTexCoords(kind : NormalizedTexCoords, texCoords : tc)
proc subRectTexCoords*(sr : Rectf, flipX : bool = false, flipY : bool = false) : WTexCoords =
    WTexCoords(kind : SubRect, subRect : sr, flipSubRect : vec2(flipX,flipY))
proc noImageTexCoords*() : WTexCoords =
    WTexCoords(kind : NoImage)

proc nineWayImage*(img : ImageLike, pixelScale : int = 1, color : RGBA = rgba(1.0f,1.0f,1.0f,1.0f), edges : set[WidgetEdge] = AllEdges) : NineWayImage =
    NineWayImage(
        image : img,
        pixelScale : pixelScale.int32,
        color : color,
        edgeColor : color,
        draw: true,
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

proc fixedPos*(pos : int) : WidgetPosition = WidgetPosition(kind : WidgetPositionKind.Fixed, fixedOffset : pos)
proc proportionalPos*(proportion : float, relativeTo : WidgetOrientation = 
    WidgetOrientation.TopLeft) : WidgetPosition = WidgetPosition(kind : WidgetPositionKind.Proportional, proportion : proportion, proportionalRelativeTo : relativeTo)


proc hash*(w : Widget) : Hash = w.entity.hash
proc `==`*(a,b : Widget) : bool = a.entity == b.entity

proc markForUpdate(ws : WindowingSystem, w : Widget, r : RecalculationFlag) =
    fine "marking for update : " , $w.entity , " ", $r
    ws.pendingUpdates.mgetOrPut(w,{}).incl(r)
    ws.renderRevision.inc

proc markForUpdate(w : Widget, r : RecalculationFlag) =
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
        if not isFarSide(axis, p.fixedRelativeTo):
            yield (widget : widget, kind : DependencyKind.Dimensions, axis : axis)

    of WidgetPositionKind.Absolute: 
        discard

iterator dependentOn(p : WidgetDimension, axis : Axis, widget : Widget, parent : Widget, children : seq[Widget]) : Dependency =
    case p.kind:
        of WidgetDimensionKind.Fixed: 
            discard
        of WidgetDimensionKind.Relative,WidgetDimensionKind.Proportional,WidgetDimensionKind.ExpandToParent,WidgetDimensionKind.Intrinsic: 
            yield (widget: parent, kind : DependencyKind.Dimensions, axis : axis)
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

converter toEntity* (w : Widget) : DisplayEntity = w.entity

proc recalculateDependents(w : Widget, axis : Axis) =
    if w.parent.isSome:
        fine "recalculating dependents for widget ", w.entity, " ", axis

        for dep in dependentOn(w.position[axis.ord], axis, w, w.parent.get):
            dep.widget.dependents.incl(toDependent(w, axis, DependencyKind.Position, dep))
        if axis == Axis.X or axis == Axis.Y:
            for dep in dependentOn(w.dimensions[axis.ord], axis, w, w.parent.get, w.children):
                dep.widget.dependents.incl(toDependent(w, axis, DependencyKind.Dimensions, dep))


proc createWindowingSystem*(display : DisplayWorld) : WindowingSystem =
    result = new WindowingSystem
    result.desktop = new Widget
    result.desktop.windowingSystem = result
    result.display = display
    result.dimensions = display[GraphicsContextData].framebufferSize
    result.pixelScale = 1
    for e in enumValues(RecalculationFlag):
        result.desktop.markForUpdate(e)

proc createWidget*(ws : WindowingSystem) : Widget =
    result = new Widget
    result.windowingSystem = ws
    result.entity = ws.display.createEntity()
    result.dimensions = [WidgetDimension(kind : WidgetDimensionKind.Intrinsic), WidgetDimension(kind : WidgetDimensionKind.Intrinsic)]
    result.parent = ws.desktop
    

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
        w.clientOffset[axis] = imageMetricsFor(w.background.image).borderWidth * w.background.pixelScale

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
    info "recalculating dimensions for widget ", w.entity, " ", axis
    w.resolvedDimensions[axis.ord] = 0

    let dim = w.dimensions[axis.ord]

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
            10 # todo: calculate intrinsic sizes
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
        echo "SETTING to ", w.windowingSystem.dimensions[axis]
        w.resolvedDimensions[axis] = w.windowingSystem.dimensions[axis]

proc ensureDependency(dep : Dependency, dirtySet : HashSet[Dependency], completedSet : var HashSet[Dependency]) =
    case dep.kind:
    of DependencyKind.Position: dep.widget.recalculatePosition(dep.axis, dirtySet, completedSet)
    of DependencyKind.Dimensions: dep.widget.recalculateDimensions(dep.axis, dirtySet, completedSet)

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

proc update*(ws : WindowingSystem) =
    let expectedDimensions = ws.display[GraphicsContextData].framebufferSize div ws.pixelScale
    if ws.dimensions != expectedDimensions:
        ws.dimensions = expectedDimensions
        ws.desktop.markForUpdate(RecalculationFlag.DimensionsX)
        ws.desktop.markForUpdate(RecalculationFlag.DimensionsY)
        echo "MARKING"

    fine "Pending updates: ", ws.pendingUpdates
    for w,v in ws.pendingUpdates:
        for axis in axes():
            if v.contains(depFlag(axis)):
                w.recalculateDependents(axis)
    
    var dirtySet : HashSet[Dependency]
    var completedSet : HashSet[Dependency]
    var rerenderSet : set[int16] = {}
    for w,v in ws.pendingUpdates:
        if v.contains(RecalculationFlag.Contents):
            rerenderSet.incl(w.entity.int16)
        for axis in axes2d():
            if v.contains(dimFlag(axis)) or v.contains(depFlag(axis)):
                # w.recalculateDimensions(axis, completedSet)
                dirtySet.incl((widget:w, kind: DependencyKind.Dimensions, axis : axis))
            if v.contains(posFlag(axis)) or v.contains(depFlag(axis)):
                # w.recalculatePosition(axis, completedSet)
                dirtySet.incl((widget:w, kind: DependencyKind.Position, axis : axis))

    for dsDep in dirtySet:
        ensureDependency(dsDep, dirtySet, completedSet)

    ws.pendingUpdates.clear()



type Corner = object
    enabled : bool
    dimensions : Vec2i


const edgeAxes : array[4,Axis] = [Axis.Y,Axis.X,Axis.Y,Axis.X]
# const cornerRects : array[4,Rectf] = [
#     rect(vec2f(0.0f,0.0f), rectf)
# ]

iterator nineWayImageQuads(nwi : NineWayImage, pos : Vec3i, dim : Vec2i, pixelScale : int) : WQuad =
    let posf = vec3f(pos)
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
            cornerDim[axis] = dim[axis] div 2

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
        let centerOffset = imgMetrics.borderWidth-1
        let startX = if nwi.drawEdges.contains(WidgetEdge.Left) : centerOffset else: 0
        let startY = if nwi.drawEdges.contains(WidgetEdge.Top) : centerOffset else: 0
        let endX = if nwi.drawEdges.contains(WidgetEdge.Right) : dim.x - centerOffset else: 0
        let endY = if nwi.drawEdges.contains(WidgetEdge.Bottom) : dim.y - centerOffset else: 0
        let pos = posf + fwd * startX.float32 + oto * startY.float32
        yield WQuad(position : pos, dimensions : vec2i(endX-startX, endY-startY), forward : fwd.xy, texCoords : noImageTexCoords(), color : nwi.color * imgMetrics.centerColor, beforeChildren : true)

    for q in 0 ..< 4:
        if corners[q].enabled:
            let pos = posf + fwd * farDims.x.float32 * UnitSquareVertices[q].x + oto * farDims.y.float32 * UnitSquareVertices[q].y
            let tc = subRectTexCoords(cornerSubRect, q mod 3 != 0, q >= 2)
            yield WQuad(position : pos, dimensions : cornerDim, forward : fwd.xy, image : imgLike, color : nwi.edgeColor, texCoords : tc, beforeChildren : false)

        if nwi.drawEdges.contains(q.WidgetEdge):
            let primaryAxis = edgeAxes[q].ord
            let secondaryAxis = 1 - primaryAxis
            if dim[primaryAxis] > cornerDim[primaryAxis] * 2:
                var pos = posf + 
                    basis[primaryAxis] * cornerDim[primaryAxis].float + 
                    basis[secondaryAxis] * farDims[secondaryAxis].float * UnitSquareVertices2d[q][secondaryAxis]
                var edgeDim : Vec2i
                edgeDim[primaryAxis] = dim[primaryAxis] - corners[(q+3) mod 4].dimensions[primaryAxis] - corners[q].dimensions[primaryAxis]
                edgeDim[secondaryAxis] = cornerDim[secondaryAxis]
                
                var imgSubRect : Rectf
                imgSubRect.position[primaryAxis] = 0.5f - ctcPos[primaryAxis]
                imgSubRect.position[secondaryAxis] = ctcPos[secondaryAxis]
                imgSubRect.dimensions[secondaryAxis] = ctcDim[secondaryAxis]

                yield WQuad(position : pos, dimensions : edgeDim, forward : fwd.xy, image : imgLike, color : nwi.edgeColor, texCoords : subRectTexCoords(imgSubRect, q >= 2, q >= 2), beforeChildren : false)
                
                

    

proc render(ws : WindowingSystem, w : Widget, vao : VAO[WVertex,uint32], tb : TextureBlock, vi,ii : var int) =
    echo ws.desktop.resolvedDimensions
    fine "Rendering widget ", w
    w.preVertices.setLen(0)
    w.postVertices.setLen(0)

    if w.background.draw:
        for quad in w.background.nineWayImageQuads(w.resolvedPosition, w.resolvedDimensions, 1):
            for vertex in quadToVertices(quad, tb, Bounds()):
                if quad.beforeChildren:
                    w.preVertices.add(vertex)
                else:
                    w.postVertices.add(vertex)

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

proc render*(ws : WindowingSystem, vao : VAO[WVertex,uint32], textureBlock : TextureBlock) =
    if vao.revision < ws.renderRevision:
        var vi,ii : int = 0

        ws.render(ws.desktop, vao, textureBlock, vi, ii)

        vao.swap()
        vao.revision = ws.renderRevision

when isMainModule:
    let display = createDisplayWorld()
    display.attachData(GraphicsContextData)
    display[GraphicsContextData].framebufferSize = vec2i(800, 600)
    let ws = createWindowingSystem(display)

    ws.update()

    let widget = ws.createWidget()

    ws.update()

    echoAssert widget.resolvedPosition.x == 0
    echoAssert widget.resolvedPosition.y == 0
    echoAssert widget.resolvedDimensions.x == 10
    echoAssert widget.resolvedDimensions.y == 10

    widget.x = fixedPos(12)
    widget.y = proportionalPos(0.1)
    widget.width = fixedSize(20)
    widget.height = proportionalSize(0.5)
    
    ws.update()

    echoAssert widget.resolvedPosition.x == 12
    echoAssert widget.resolvedPosition.y == 60
    echoAssert widget.resolvedDimensions.x == 20
    echoAssert widget.resolvedDimensions.y == 300

    let childWidget = ws.createWidget()
    childWidget.parent = widget

    childWidget.width = relativeSize(-5)
    childWidget.height = wrapContent()


    let subChildWidget = ws.createWidget()
    subChildWidget.parent = childWidget
    subChildWidget.x = fixedPos(5)
    subChildWidget.y = fixedPos(7)
    subChildWidget.width = fixedSize(20)
    subChildWidget.height = fixedSize(30)

    ws.update()

    echoAssert childWidget.resolvedPosition.x == 12
    echoAssert subChildWidget.resolvedPosition.x == 17
    echoAssert childWidget.resolvedDimensions.x == 15
    echoAssert childWidget.resolvedDimensions.y == 37
    
    info "====================="
    subChildWidget.x = fixedPos(6)

    ws.update()

    import windowing_main