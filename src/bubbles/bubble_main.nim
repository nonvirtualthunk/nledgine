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
import core
import resources

const WindowSize = vec2f(1200,1000)
const FullPlayAreaSize = vec2f(WindowSize.x - 400.0f32, WindowSize.y)
const PlayAreaSize = vec2f(FullPlayAreaSize.x - 50, FullPlayAreaSize.y - 50)
const ClippedPlayArea = rectf(PlayAreaSize.x * -0.5f, PlayAreaSize.y * -0.5f, PlayAreaSize.x, PlayAreaSize.y)

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
    actionProgressRequired: {PlayerActionKind.Attack: 2, PlayerActionKind.Block: 2, PlayerActionKind.Skill: 3}.toTable,
    playArea: ClippedPlayArea
  ))
  player.attachData(Combatant(
    name: "Player",
    health: reduceable(4),
    image: image("bubbles/images/player.png"),
  ))

  let stageDesc = StageDescription(
                      linearDrag: 90.0f32,
                      cannonPosition: vec2f(0.5f, 0.1f),
                      cannonVelocity: 700.0f32,
                      progressRequired: some(1),
                      makeActive: true
                    )
  let stage = createStage(world, player, stageDesc)
  world.postEvent(WorldInitializedEvent())




main(GameSetup(
  windowSize: vec2i(WindowSize),
  resizeable: false,
  windowTitle: "Bubbles",
  clearColor: rgba(0.35,0.35,0.35,1.0),
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
    createCameraComponent(createPixelCamera(2, vec2f(-200, 0))),
    createWindowingSystemComponent("bubbles/widgets/")
      .withMainWidget("MainUI", "MainUI"),
    BubbleGraphics(),
    RewardUIComponent(),
    MainUIComponent()
  ],
  useLiveWorld: true,
))