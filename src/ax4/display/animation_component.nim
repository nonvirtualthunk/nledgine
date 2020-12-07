import engines
import graphics
import prelude
import tables
import graphics/cameras
import graphics/canvas
import core
import game/library
import ax4/game/ax_events
import noto
import hex
import ax4/game/character_types
import worlds

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
         curView.clear()
         let nextEvent = world.eventAtTime(curView.currentTime)
         var delay = 0.0

         if nextEvent of GameEvent and ((GameEvent)nextEvent).state == GameEventState.PreEvent:

            matchType(nextEvent):
               extract(CharacterMoveEvent, entity, fromHex, toHex):
                  delay = 0.5f
                  let dt = (relTime() - g.lastAdvanced).inSeconds / delay
                  let delta = toHex.asCartVec - fromHex.asCartVec
                  let hopCount = 2.0f
                  let hopHeight = 0.1f
                  let hop = cartVec(0.0f, hopHeight, 0.0f) * abs(sin(dt * PI * hopCount))
                  curView.modify(entity, PhysicalType.offset := (delta * dt + hop))
               extract(AttackEvent, entity, attack, targets):
                  if targets.len == 1:
                     let target = targets[0]
                     let delta = (curView.data(target, Physical).position.asCartVec - curView.data(entity, Physical).position.asCartVec).normalizeSafe
                     delay = 0.35f
                     let dt = (relTime() - g.lastAdvanced).inSeconds / delay
                     let dv = sin(dt * PI) * 0.5f
                     # fine &"dv {dv}, dt {dt}, delta {delta}, entity {entity}, target {target}"
                     curView.modify(entity, PhysicalType.offset := (delta * dv))
                  else:
                     warn &"Animation for attacking multiple enemies not yet done"
               extract(FactionTurnEndEvent):
                  delay = 0.1f


         if relTime() > g.lastAdvanced + delay.seconds:
            curView.advanceBaseView(world, (curView.currentTime.int+1).WorldEventClock)
            g.lastAdvanced = relTime()
         else:
            break
   else:
      g.lastAdvanced = relTime()

   @[]
