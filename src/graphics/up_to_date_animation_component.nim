import engines
import graphics
import prelude
import tables
import graphics/cameras
import worlds

type
   UpToDateAnimationComponent* = ref object of GraphicsComponent


method initialize(g: UpToDateAnimationComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "UpToDateAnimationComponent"

method onEvent(g: UpToDateAnimationComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) = discard

method update(g: UpToDateAnimationComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   if world.currentTime > curView.currentTime:
      while world.currentTime > curView.currentTime:
         curView.clear()
         curView.advanceBaseView(world, (curView.currentTime.int+1).WorldEventClock)

   @[]
