import tables
import sets
import hex
import prelude
import reflect
import engines
import ax4/game/ax_events
import ax4/game/characters


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


proc recomputeHexesInView(world: World, entity: Entity) =
   withWorld(world):
      let visionRange = 5
      let entityPos = entity[Physical].position

      var hexesInView: HashSet[AxialVec]
      for r in 0 ..< visionRange:
         for hex in hexRing(entityPos, r):
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

method update*(g: VisionComponent, world: World) =
   discard

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

