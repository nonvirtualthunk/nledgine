import engines
import graphics
import prelude
import tables
import graphics/cameras
import graphics/canvas
import core
import game/library
import ax4/game/ax_events

type
   AnimationComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas
      worldWatcher: Watcher[WorldEventClock]
      lastAdvanced: UnitOfTime


method initialize(g: AnimationComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "AnimationComponent"
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.canvas.drawOrder = 20
   g.worldWatcher = watcher(() => curView.currentTime())


proc render(g: AnimationComponent, view: WorldView, display: DisplayWorld) =
   g.canvas.swap()

method onEvent(g: AnimationComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   discard

method update(g: AnimationComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   # @[g.canvas.drawCommand(display)]
   if world.currentTime > curView.currentTime:
      while world.currentTime > curView.currentTime:
         let nextEvent = world.eventAtTime(curView.currentTime)
         var delay = 0.0
         if nextEvent of GameEvent and ((GameEvent)nextEvent).state == GameEventState.PostEvent:
            matchType(nextEvent):
               extract(CharacterMoveEvent):
                  delay = 0.25


         if relTime() > g.lastAdvanced + delay.seconds:
            curView.advance(world, (curView.currentTime.int+1).WorldEventClock)
            g.lastAdvanced = relTime()
         else:
            break
   else:
      g.lastAdvanced = relTime()

   @[]
