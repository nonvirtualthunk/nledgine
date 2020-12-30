import tables
import sets
import hex
import prelude
import reflect
import engines
import ax4/game/ax_events
import ax4/game/characters
import glm
import ax4/game/map
import noto

type
   Vision* = object
      hexesInView*: HashSet[AxialVec]
      revealed*: HashSet[AxialVec]

   VisionContext* = object
      visions*: seq[ref Vision]

   VisionComponent* = ref object of GameComponent

   VisionChangedEvent* = ref object of AxEvent

defineReflection(Vision)


method toString*(evt: VisionChangedEvent, view: WorldView): string =
   withView(view):
      var entityIdentifier = $evt.entity
      if evt.entity.hasData(DebugData):
         entityIdentifier = evt.entity[DebugData].name
      return &"VisionChanged({entityIdentifier})"

proc recomputeFactionHexesInView(world: World, faction: Entity) =
   withWorld(world):
      var curVision = faction[Vision]
      var allHexes: HashSet[AxialVec]
      var newRevealed: HashSet[AxialVec]
      for entity in entitiesInFaction(world, faction):
         let hexesInView = entity[Vision].hexesInView
         allHexes.incl(hexesInView)
         for hex in hexesInView:
            if not curVision.revealed.contains(hex):
               newRevealed.incl(hex)

      world.eventStmts(VisionChangedEvent(entity: faction)):
         faction.modify(Vision.hexesInView := allHexes)
         if newRevealed.nonEmpty:
            faction.modify(Vision.revealed.incl(newRevealed))


type VisionState = object
   visionRemaining: int
   elevation: int

proc recomputeHexesInView(world: World, entity: Entity) =
   withWorld(world):
      let visionRange = entity[Character].sightRange
      let entityPos = entity[Physical].position
      let center = entityPos.asCartVec.Vec3f

      let biasDeltas = @[axialVec(0, 0), axialVec(0, 0)]

      let map = mapView(world.view)
      var startingElevation = map.elevationAt(entityPos)
      var hexesInView: HashSet[AxialVec]
      var visionState: Table[AxialVec, VisionState]
      for r in 0 ..< visionRange:
         for hex in hexRing(entityPos, r):
            let elevation = map.elevationAt(hex)
            var adjacentVision = 0
            var visionCost = 0
            if r == 0:
               adjacentVision = visionRange
            else:
               visionCost = 1 + map.totalCoverAt(hex)
               # let hexCenter = hex.asCartVec.Vec3f
               # let delta = hexCenter - center
               for biasDelta in biasDeltas:
                  # let side = sideClosestTo(hex, entityPos, hex + biasDelta)
                  # let adj = hex.neighbor(side)

                  let delta = (entityPos.asCubeVec.asVec3f - hex.asCubeVec.asVec3f).normalize
                  let adjV = (hex.asCubeVec.asVec3f + delta)
                  let adj = roundedCube(adjV.x, adjV.y, adjV.z).asAxialVec


                  fine &"Hex {hex} examining {adj} to get to {entityPos}"
                  stdout.flushFile
                  let adjVS = visionState[adj]
                  if adjVS.visionRemaining > adjacentVision and (elevation <= startingElevation or elevation >= adjVS.elevation):
                     adjacentVision = adjVS.visionRemaining


            visionState[hex] = VisionState(visionRemaining: adjacentVision - visionCost, elevation: elevation)
            if adjacentVision > 0:
               hexesInView.incl(hex)

      world.eventStmts(VisionChangedEvent(entity: entity)):
         entity.modify(Vision.hexesInView := hexesInView)

      recomputeFactionHexesInView(world, faction(world, entity))




method initialize*(g: VisionComponent, world: World) =
   withView(world):
      g.name = "VisionComponent"
      for e in world.entitiesWithData(Vision):
         if e.hasData(Physical):
            recomputeHexesInView(world, e)

method onEvent*(g: VisionComponent, world: World, event: Event) =
   ifOfType(AxEvent, event):
      if event.state == PostEvent:
         matcher(event):
            extract(CharacterMoveEvent, entity):
               recomputeHexesInView(world, entity)
            extract(EntityEnteredWorldEvent, entity):
               recomputeHexesInView(world, entity)


proc playerVisionContext*(view: WorldView): VisionContext =
   withView(view):
      for faction in playerFactions(view):
         result.visions.add(faction[Vision])

proc isVisible*(ctx: VisionContext, vec: AxialVec): bool =
   for vision in ctx.visions:
      if vision.hexesInView.contains(vec):
         return true

proc isRevealed*(ctx: VisionContext, vec: AxialVec): bool =
   for vision in ctx.visions:
      if vision.revealed.contains(vec):
         return true


proc isVisibleTo*(view: WorldView, entity: Entity, hex: AxialVec): bool =
   withView(view):
      entity[Vision].hexesInView.contains(hex)

proc isVisibleTo*(view: WorldView, entity: Entity, other: Entity): bool =
   withView(view):
      isVisibleTo(view, entity, other[Physical].position)
