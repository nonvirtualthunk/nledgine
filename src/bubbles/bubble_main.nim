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
import display/display_components
import core
import resources

const WindowSize = vec2f(1200,1200)
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
  for i in 0 ..< 8:
    let bubbleType = if i mod 2 == 0: † Bubbles.Strike else: † Bubbles.Defend
    let bubble = createBubble(world, bubbleType)
    bubbles.add(bubble)

  bubbles.add(createBubble(world, † Bubbles.Bash))

  # bubbles.add(createBubble(world, † Bubbles.Inflame))
  # bubbles.add(createBubble(world, † Bubbles.RecklessStrike))
  bubbles.add(createBubble(world, † Bubbles.Stalwart))

  let player = world.createEntity()
  player.attachData(Player(
    bubbles: bubbles,
    actionProgressRequired: {PlayerActionKind.Attack: 2, PlayerActionKind.Block: 2, PlayerActionKind.Skill: 3}.toTable,
    playArea: ClippedPlayArea,
    effects: {PlayerActionKind.Skill : @[PlayerEffect(amount: 1, kind: PlayerEffectKind.Mod, modifier: combatantMod(CombatantModKind.Strength))]}.toTable,
    # pendingRewards: @[Reward(bubbles: @[createRandomizedRewardBubble(world), createRandomizedRewardBubble(world), createRandomizedRewardBubble(world)])]
  ))
  player.attachData(Combatant(
    name: "Player",
    health: reduceable(30),
    image: image("bubbles/images/player.png"),
    modifiers: @[]
  ))

  let stageDesc = StageDescription(
                      linearDrag: 90.0f32,
                      cannonPosition: vec2f(0.5f, 0.25f),
                      cannonVelocity: 600.0f32,
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
    createCameraComponent(createPixelCamera(2, vec2f(-200, 0)).withMoveSpeed(0.0)),
    createWindowingSystemComponent("bubbles/widgets/")
      .withMainWidget("MainUI", "MainUI"),
    BubbleGraphics(),
    RewardUIComponent(),
    MainUIComponent()
  ],
  useLiveWorld: true,
))