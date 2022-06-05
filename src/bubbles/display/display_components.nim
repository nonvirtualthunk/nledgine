import engines
import graphics
import prelude
import tables
import strformat
import options
import windowingsystem/windowingsystem
import windowingsystem/image_widget
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

proc effectDescription(eff: PlayerEffect): string =
  case eff.kind:
    of PlayerEffectKind.Attack: &"Deal {eff.amount} damage"
    of PlayerEffectKind.Block: &"Gain {eff.amount} block"
    of PlayerEffectKind.EnemyMod: &"Apply {eff.modifier.number} {$eff.modifier.kind}"
    of PlayerEffectKind.Mod: &"Gain {eff.modifier.number} {$eff.modifier.kind}"
    of PlayerEffectKind.Bubble: &"Add a {eff.bubbleArchetype.displayName} bubble"
    of PlayerEffectKind.LoseHealth: &"Lose {eff.amount} health"
    of PlayerEffectKind.TakeDamage: &"Take {eff.amount} damage"

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
        w.bindValue("name", b[Bubble].name)
        var descriptorString = ""
        for m in b[Bubble].modifiers:
          if descriptorString.nonEmpty: descriptorString.add(", ")
          descriptorString.add(descriptor(m))
        w.bindValue("bubbleModifiers", descriptorString)


        var effectsDescription = ""
        proc addEffDesc(str: string) =
          if effectsDescription.nonEmpty:
            effectsDescription.add("\n")
          effectsDescription.add(str)

        for eff in b[Bubble].onPopEffects:
          for subEff in eff.effects:
            addEffDesc(effectDescription(subEff))

        if b[Bubble].inPlayPlayerMods.nonEmpty:
          addEffDesc("While in play:")
          for modifier in b[Bubble].inPlayPlayerMods:
            addEffDesc(&"Gain {modifier.number} {modifier.kind}")

        w.bindValue("effectsDescription", effectsDescription)

        w.bindValue("imageLayers", bubbleImageLayers(b[Bubble]))
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
        if originatingWidget.isSelfOrDescendantOf(g.rewardChoiceWidgets[i]):
          chooseReward(world, i)





type
  MainUIComponent* = ref object of GraphicsComponent
    infoArea*: Widget
    needsUpdate*: bool

  ModifierB = object
    image: Image
    number: int

  EnemyB = object
    name: string
    image: Image
    intentIcon: Image
    intentText: string
    intentColor: RGBA
    intentTime: int
    health: int
    maxHealth: int
    `block`: int
    blockShowing: bool
    modifiers: seq[ModifierB]


method initialize(g: MainUIComponent, world: LiveWorld, display: DisplayWorld) =
   g.name = "MainUIComponent"
   g.needsUpdate = true


   let ws = display[WindowingSystem]
   g.infoArea = ws.desktop.descendantByIdentifier("InfoArea").get


proc computeModifiers*(world: LiveWorld, entity: Entity): seq[ModifierB] =
  let pcd = entity[Combatant]
  var modifiers: seq[ModifierB]
  for mk in enumValues(CombatantModKind):
    let v = sumModifiers(pcd, mk)
    if v > 0:
      modifiers.add(ModifierB(image: icon(mk), number: v))
  modifiers

method update(g: MainUIComponent, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.needsUpdate:
    var hasStage = false
    for stage in activeStages(world):
      let sd = stage[Stage]
      hasStage = true
      var enemyBindings: seq[EnemyB]
      for enemy in sd.enemies:
        let ed = enemy[Enemy]
        let ecd = enemy[Combatant]
        if ecd.health.currentValue > 0:
          enemyBindings.add(EnemyB(
            name: ecd.name,
            image: ecd.image,
            intentIcon: icon(ed.activeIntent),
            intentText: text(ed.activeIntent),
            intentColor: color(ed.activeIntent),
            intentTime: ed.activeIntent.duration.currentValue,
            health: ecd.health.currentValue,
            maxHealth: ecd.health.maxValue,
            `block`: ecd.blockAmount,
            blockShowing: ecd.blockAmount > 0,
            modifiers: computeModifiers(world, enemy)
          ))
      g.infoArea.bindValue("enemies", enemyBindings)

    g.infoArea.bindValue("enemy.showing", hasStage)

    let p = player(world)
    let pcd = p[Combatant]
    let pd = p[Player]

    g.infoArea.bindValue("playerName", pcd.name)
    g.infoArea.bindValue("playerImage", pcd.image)
    g.infoArea.bindValue("playerHealth", pcd.health.currentValue)
    g.infoArea.bindValue("playerMaxHealth", pcd.health.maxValue)
    g.infoArea.bindValue("playerBlock", pcd.blockAmount)
    g.infoArea.bindValue("playerBlockShowing", pcd.blockAmount > 0)
    g.infoArea.bindValue("playerModifiers", computeModifiers(world, p))

    for action in enumValues(PlayerActionKind):
      let str = ($action).toLowerAscii
      g.infoArea.bindValue(&"{str}Progress", pd.actionProgress.getOrDefault(action))
      g.infoArea.bindValue(&"{str}ProgressRequired", pd.actionProgressRequired.getOrDefault(action, 1))

method onEvent(g: MainUIComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  if event of CharacterEvent:
    g.needsUpdate = true
  discard