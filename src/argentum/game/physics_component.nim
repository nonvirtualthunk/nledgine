import engines
import graphics/canvas
import game/grids
import glm
import tables
import windowingsystem/windowing_system_core
import graphics/images
import graphics/color
import resources
import patty
import prelude
import noto


variantp StaticShape:
   Square
   RightTriangle(right: bool, down: bool)


type
   PhysicsComponent* = ref object of GraphicsComponent
      canvas: SimpleCanvas

   RTPhysics* = object
      acceleration*: Vec2f
      velocity*: Vec2f
      position*: Vec3f
      radius*: float
      elasticity*: float
      mass*: float

   Edge* = object
      p1*: Vec3f
      p2*: Vec3f
      n*: Vec2f

   RTStaticPhysics* = object
      edges*: seq[Edge]
      shape*: StaticShape
      position*: Vec3f
      elasticity*: float


   RTPhysicsWorldData* = object
      physicsState*: Table[Entity, RTPhysics]
      staticPhysicsState*: seq[RTStaticPhysics]
      gravity*: Vec2f
      occupancyGrid*: FiniteGrid3D[100, 100, 8, int]


defineRealtimeReflection(RTPhysicsWorldData)


method initialize(g: PhysicsComponent, world: World, curView: WorldView, display: DisplayWorld) =
   display.attachData(RTPhysicsWorldData())
   g.canvas = createCanvas[SimpleVertex, uint16]("shaders/simple")
   g.canvas.drawOrder = 200
   display[WindowingSystem].desktop.background = nineWayImage("ui/buttonBackground.png")

   let ent = world.createEntity()

   let physWorld = display[RTPhysicsWorldData]
   physWorld.physicsState[ent] = RTPhysics(
      radius: 0.5,
      position: vec3f(-0.5f, 0.0f, 0.0f),
      elasticity: 0.6f,
      mass: 10.0f
   )

   for i in -1 .. 10:
      physWorld.staticPhysicsState.add(RTStaticPhysics(
         edges: @[
            Edge(p1: vec3f(-1.0f, -10.0f, 0.0f), p2: vec3f(1.0f, -10.0f, 0.0f), n: vec2f(0.0f, 1.0f)),
         ],
         shape: Square(),
         position: vec3f(i.float, -10.0f, 0.0f),
         elasticity: 0.6f
      ))
   # physWorld.staticPhysicsState.add(RTStaticPhysics(
   #    edges: @[
   #       Edge(p1: vec3f(-1.0f, -10.0f, 0.0f), p2: vec3f(1.0f, -10.0f, 0.0f), n: vec2f(0.0f, 1.0f)),
   #    ],
   #    shape: Square(),
   #    position: vec3f(10.0f, -9.0f, 0.0f),
   #    elasticity: 0.6f
   # ))

   physWorld.staticPhysicsState.add(RTStaticPhysics(
      edges: @[
         Edge(p1: vec3f(-1.0f, -10.0f, 0.0f), p2: vec3f(1.0f, -10.0f, 0.0f), n: vec2f(0.0f, 1.0f)),
      ],
      shape: RightTriangle(false, false),
      position: vec3f(-1.0f, -9.0f, 0.0f),
      elasticity: 0.6f
   ))


proc resolveCollision(physWorld: ref RTPhysicsWorldData, a: var RTPhysics, b: RTStaticPhysics, normal: Vec2f, depth: float) =
   let rv = a.velocity # would incorporate b here, if it were non-static
   let velAlongNormal = rv.dot(normal)
   if velAlongNormal > 0:
      return

   let e = min(a.elasticity, b.elasticity)
   var j = -(1.0f + e) * velAlongNormal
   j /= (1.0f / a.mass) # use b.mass as well
   let impulse = normal * j
   a.velocity += impulse * (1.0f / a.mass) # apply to be too
   a.position.xy += normal * depth * 1.0f

method update(g: PhysicsComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   let metersPerUnit = 0.25f
   let pixelsPerUnit = 64.0f

   let physWorld = display[RTPhysicsWorldData]
   let dt = df * 0.016667

   for entity, physics in physWorld.physicsState.mpairs:
      let accelerationX = physics.acceleration.x
      let accelerationY = physics.acceleration.y - 9.8f / metersPerUnit
      physics.velocity.x += accelerationX * dt
      physics.velocity.y += accelerationY * dt

      physics.position.x += physics.velocity.x * dt
      physics.position.y += physics.velocity.y * dt

      for staticPhysics in physWorld.staticPhysicsState:
         var intersectionDistance = 0.0f
         var normal = vec2f(0.0f, 1.0f)
         match staticPhysics.shape:
            Square:
               let xi = clamp(physics.position.x, staticPhysics.position.x, staticPhysics.position.x + 1)
               let yi = clamp(physics.position.y, staticPhysics.position.y, staticPhysics.position.y + 1)
               let d = distance(xi, yi, physics.position.x, physics.position.y)
               if d < physics.radius:
                  intersectionDistance = physics.radius - d
                  # normal = vec2f(0.0f, 1.0f)
                  normal = vec2f(physics.position.x - xi, physics.position.y - yi).normalizeSafe
                  # let extraDist = physics.radius - d
                  # let normV = physics.velocity.normalizeSafe
                  # physics.position.x += extraDist * normV.x * -1.0f
                  # physics.position.y += extraDist * normV.y * -1.0f
                  # physics.velocity.x = 0.0f
                  # physics.velocity.y *= -1.0f * physics.elasticity * staticPhysics.elasticity
            RightTriangle(right, down):
               # equation: x + y - py - px + 1 = 0, shifted
               # x + y + 9 - 1 + 1 = 0

               let a = 1.0f
               let b = 1.0f
               let c = -staticPhysics.position.y + staticPhysics.position.x + 1.0f
               let d = abs(a * physics.position.x + b * physics.position.y + c) / sqrt(a*a+b*b)

               if d < physics.radius:
                  intersectionDistance = physics.radius - d
                  normal = vec2f(a, b).normalizeSafe
                  # let extraDist = physics.radius - d
                  # let normV = physics.velocity.normalizeSafe
                  # let normal = vec2f(a, b).normalizeSafe
                  # let newV = physics.velocity - normal * 2.0 * dot(normal, physics.velocity)
                  # physics.position.x += extraDist * normV.x * -1.0f
                  # physics.position.y += extraDist * normV.y * -1.0f
                  # physics.velocity = newV

         if intersectionDistance > 0.0f:
            resolveCollision(physWorld, physics, staticPhysics, normal, intersectionDistance)
            # let normV = physics.velocity.normalizeSafe
            # let newV = physics.velocity - normal * 2.0 * dot(normal, physics.velocity)
            # physics.position.x += intersectionDistance * normV.x * -1.0f
            # physics.position.y += intersectionDistance * normV.y * -1.0f
            # physics.velocity = newV * physics.elasticity * staticPhysics.elasticity





   var qb = QuadBuilder()
   qb.color = rgba(1.0f, 1.0f, 1.0f, 1.0f)
   for physics in physWorld.staticPhysicsState:
      qb.position = physics.position * pixelsPerUnit
      qb.dimensions = vec2f(pixelsPerUnit, pixelsPerUnit)

      match physics.shape:
         Square:
            qb.texture = image("argentum/tiles/square.png")
         RightTriangle:
            qb.texture = image("argentum/tiles/triangle.png")

      qb.drawTo(g.canvas)

   qb.centered()
   for entity, physics in physWorld.physicsState:
      qb.position = physics.position * pixelsPerUnit
      qb.dimensions = vec2f(physics.radius * pixelsPerUnit * 2.0f, physics.radius * pixelsPerUnit * 2.0f)
      qb.texture = image("argentum/entities/rock.png")
      qb.drawTo(g.canvas)
      # info &"Drawing : {qb}"
   g.canvas.swap()

   @[g.canvas.drawCommand(display)]
