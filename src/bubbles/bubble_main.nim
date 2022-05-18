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
  for i in 0 ..< 9:
    let bubble = createBubble(world)
    # bubble[Bubble].color = if i < 3: BubbleColor.Red elif i < 6: BubbleColor.Green else: BubbleColor.Blue
    bubble[Bubble].color = if i mod 2 == 0: BubbleColor.Red else: BubbleColor.Blue
    bubbles.add(bubble)

  let bashBubble = createBubble(world)
  bashBubble[Bubble].color = BubbleColor.Red
  bashBubble[Bubble].modifiers = @[bubbleMod(BubbleModKind.Power), bubbleMod(BubbleModKind.HighNumber)]
  bashBubble[Bubble].secondaryColors = @[BubbleColor.Blue]
  bubbles.add(bashBubble)

  let skillBubble = createBubble(world)
  skillBubble[Bubble].color = BubbleColor.Green
  skillBubble[Bubble].modifiers = @[bubbleMod(BubbleModKind.Potency, 2)]
  skillBubble[Bubble].secondaryColors = @[BubbleColor.Red]
  skillBubble[Bubble].maxNumber = 1
  bubbles.add(skillBubble)

  let chainBubble = createBubble(world)
  chainBubble[Bubble].color = BubbleColor.Blue
  chainBubble[Bubble].modifiers = @[bubbleMod(BubbleModKind.HighNumber), bubbleMod(BubbleModKind.Chain)]
  bubbles.add(chainBubble)

  let powerBubble = createBubble(world)
  powerBubble[Bubble].color = BubbleColor.Green
  powerBubble[Bubble].modifiers = @[bubbleMod(BubbleModKind.Chromophilic)]
  powerBubble[Bubble].maxNumber = 1
  powerBubble[Bubble].inPlayPlayerMods = @[combatantMod(CombatantModKind.Strength)]
  bubbles.add(powerBubble)

  let player = world.createEntity()
  player.attachData(Player(
    bubbles: bubbles,
    actionProgressRequired: {PlayerActionKind.Attack: 2, PlayerActionKind.Block: 2, PlayerActionKind.Skill: 3}.toTable,
    playArea: ClippedPlayArea,
    effects: {PlayerActionKind.Skill : @[PlayerEffect(amount: 1, kind: PlayerEffectKind.Mod, modifier: combatantMod(CombatantModKind.Strength))]}.toTable,
    # pendingRewards: @[Reward(bubbles: @[createRewardBubble(world), createRewardBubble(world), createRewardBubble(world)])]
  ))
  player.attachData(Combatant(
    name: "Player",
    health: reduceable(4),
    image: image("bubbles/images/player.png"),
    modifiers: @[combatantMod(CombatantModKind.Dexterity)]
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