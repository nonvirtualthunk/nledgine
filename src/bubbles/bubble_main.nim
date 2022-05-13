import main
import application
import glm
import engines/debug_components
import windowingsystem/windowingsystem_component
import graphics/color
import worlds
import graphics/camera_component
import graphics/cameras
import options
import prelude
import engines
import display/bubble_graphics
import game/entities
import game/logic
import game/components
import arxmath
import display/components as display_components

type
  InitComponent = ref object of LiveGameComponent

proc initComponent(): InitComponent =
  result = new InitComponent
  result.initializePriority = 100

method initialize(g: InitComponent, world: LiveWorld) =
  var bubbles: seq[Entity]
  for i in 0 ..< 10:
    let bubble = createBubble(world)
    bubble[Bubble].color = if i < 3: BubbleColor.Red elif i < 6: BubbleColor.Green else: BubbleColor.Blue
    bubbles.add(bubble)

  let player = world.createEntity()
  player.attachData(Player(
    bubbles: bubbles,
    # pendingRewards: @[Reward(bubbles: @[createRewardBubble(world), createRewardBubble(world), createRewardBubble(world)])]
  ))

  let stageDesc = StageDescription(
                      linearDrag: 90.0f32,
                      cannonPosition: vec2f(0, -500),
                      cannonVelocity: 700.0f32,
                      progressRequired: some(1),
                      makeActive: true
                    )
  let stage = createStage(world, player, stageDesc)
  world.postEvent(WorldInitializedEvent())




main(GameSetup(
  windowSize: vec2i(800, 1200),
  resizeable: false,
  windowTitle: "Bubbles",
  clearColor: rgba(0.15,0.15,0.15,1.0),
  liveGameComponents: @[
    BasicLiveWorldDebugComponent()
      .ignoringEventType(BubbleMovedEvent)
      .ignoringEventType(BubbleStoppedEvent),
    physicsComponent(),
    bubbleComponent(),
    stageComponent(),
    initComponent(),
  ],
  graphicsComponents: @[
    createCameraComponent(createPixelCamera(2)),
    createWindowingSystemComponent("bubbles/widgets/"),
    BubbleGraphics(),
    RewardUIComponent()
  ],
  useLiveWorld: true,
))