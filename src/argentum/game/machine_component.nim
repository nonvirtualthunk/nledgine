import worlds
import graphics
import engines
import prelude
import argentum/game/physics_component

type
   MachineComponent* = ref object of GraphicsComponent
      lastDrop*: UnitOfTime



method initialize(g: MachineComponent, world: World, curView: WorldView, display: DisplayWorld) =
   discard

method update(g: MachineComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   let t = relTime()
   if t - g.lastDrop > 2.seconds:
      g.lastDrop = t
      let ent = world.createEntity()

      let physWorld = display[RTPhysicsWorldData]
      physWorld.physicsState[ent] = RTPhysics(
         radius: 0.5,
         position: vec3f(-0.5f, 0.0f, 0.0f),
         elasticity: 0.6f,
         mass: 10.0f
      )
   discard

method onEvent(g: MachineComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   discard
