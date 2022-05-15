import engines
import graphics
import prelude
import tables
import strformat
import options
import windowingsystem/windowingsystem
import noto
import math
import patty
import graphics/core as gfx_core
import game/library
import worlds
import bubbles/game/logic
import bubbles/game/entities
import bubble_graphics
import core
import strutils

type
   RewardUIComponent* = ref object of GraphicsComponent
      rewardsWatcher: Watcher[seq[Reward]]
      rewardsWidget: Widget
      rewardChoiceWidgets: seq[Widget]

   RewardInfo* = object
     rewardIndex*: int


defineDisplayReflection(RewardInfo)

method initialize(g: RewardUIComponent, world: LiveWorld, display: DisplayWorld) =
   g.name = "RewardUIComponent"
   g.eventPriority = 10

   # g.selectedWatcher = watch: display[TacticalUIData].selectedCharacter
   # g.worldWatcher = watch: curView.currentTime
   g.rewardsWatcher = watch: player(world)[Player].pendingRewards

   let ws = display[WindowingSystem]
   g.rewardsWidget = ws.desktop.descendantByIdentifier("PlayArea").get.createChild("RewardWidgets", "RewardWidget")
   # g.rewardsWidget.childByIdentifier("SkipButton").get.onEventOfTypeW(WidgetMouseRelease, release):
   #    g.skipReward = true

method update(g: RewardUIComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.rewardsWatcher.hasChanged:
    for w in g.rewardChoiceWidgets: w.destroyWidget()
    g.rewardChoiceWidgets.clear()

    let rewards = g.rewardsWatcher.currentValue()
    g.rewardsWidget.bindValue("rewards.showing", rewards.nonEmpty)
    if rewards.nonEmpty:
      let ws = display[WindowingSystem]
      let optionsDiv = g.rewardsWidget.descendantByIdentifier("RewardOptions").get
      for b in rewards[0].bubbles:
        let w = optionsDiv.createChild("RewardWidgets", "RewardOptionWidget")
        w.identifier = &"RewardOption[{g.rewardChoiceWidgets.len}]"
        w.bindValue("name", "Bubble")
        var descriptorString = ""
        for m in b[Bubble].modifiers:
          if descriptorString.nonEmpty: descriptorString.add(", ")
          descriptorString.add(descriptor(m))
        w.bindValue("descriptors", descriptorString)
        if b[Bubble].radius == 24.0f32:
          w.bindValue("image", image("bubbles/images/bubble_2.png"))
        else:
          w.bindValue("image", image("bubbles/images/large_bubble_2.png"))
        w.bindValue("imageColor", rgba(b[Bubble].color))
        w.bindValue("numeral", display[NumberGraphics].numerals[b[Bubble].maxNumber])
        w.attachData(RewardInfo(rewardIndex: g.rewardChoiceWidgets.len))
        if g.rewardChoiceWidgets.nonEmpty:
          w.position[Axis.Y.ord] = relativePos(g.rewardChoiceWidgets[^1].identifier, 4, WidgetOrientation.BottomLeft)
        g.rewardChoiceWidgets.add(w)


  discard

method onEvent(g: RewardUIComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(WidgetMouseRelease, originatingWidget):
      for i in 0 ..< g.rewardChoiceWidgets.len:
        if originatingWidget.isDescendantOf(g.rewardChoiceWidgets[i]):
          info &"Choosing reward {i}"
          chooseReward(world, i)





type
  MainUIComponent* = ref object of GraphicsComponent
    infoArea*: Widget
    needsUpdate*: bool

method initialize(g: MainUIComponent, world: LiveWorld, display: DisplayWorld) =
   g.name = "MainUIComponent"
   g.needsUpdate = true


   let ws = display[WindowingSystem]
   g.infoArea = ws.desktop.descendantByIdentifier("InfoArea").get

method update(g: MainUIComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.needsUpdate:
    for stage in activeStages(world):
      let sd = stage[Stage]
      let ed = sd.enemy[Enemy]
      let ecd = sd.enemy[Combatant]
      g.infoArea.bindValue("enemyName", ecd.name)
      g.infoArea.bindValue("enemyImage", ecd.image)
      g.infoArea.bindValue("enemyIntentIcon", icon(ed.activeIntent))
      g.infoArea.bindValue("enemyIntentText", ed.activeIntent.amount)
      g.infoArea.bindValue("enemyIntentColor", color(ed.activeIntent))
      g.infoArea.bindValue("enemyIntentTime", ed.activeIntent.duration.currentValue)
      g.infoArea.bindValue("enemyHealth", ecd.health.currentValue)
      g.infoArea.bindValue("enemyMaxHealth", ecd.health.maxValue)
      g.infoArea.bindValue("enemyBlock", ecd.blockAmount)
      g.infoArea.bindValue("enemyBlockShowing", ecd.blockAmount > 0)

    let p = player(world)
    let pcd = p[Combatant]
    let pd = p[Player]

    g.infoArea.bindValue("playerName", pcd.name)
    g.infoArea.bindValue("playerImage", pcd.image)
    g.infoArea.bindValue("playerHealth", pcd.health.currentValue)
    g.infoArea.bindValue("playerMaxHealth", pcd.health.maxValue)
    g.infoArea.bindValue("playerBlock", pcd.blockAmount)
    g.infoArea.bindValue("playerBlockShowing", pcd.blockAmount > 0)

    for action in enumValues(PlayerActionKind):
      let str = ($action).toLowerAscii
      g.infoArea.bindValue(&"{str}Progress", pd.actionProgress.getOrDefault(action))
      g.infoArea.bindValue(&"{str}ProgressRequired", pd.actionProgressRequired.getOrDefault(action, 1))

method onEvent(g: MainUIComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  if event of CharacterEvent:
    g.needsUpdate = true
  discard