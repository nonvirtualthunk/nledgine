import game_prelude
import engines
import windowingsystem/windowingsystem
import windowingsystem/rich_text
import windowingsystem/ascii_cards
import graphics/color
import sequtils
import noto
import game/cards
import glm

import hex_crawl/game/logic
import hex_crawl/game/data

type
  CardBattleUI* = ref object of GraphicsComponent
    captain*: Entity
    worldWatcher*: Watcher[WorldEventClock]
    selectedGroupWatcher: Watcher[int]
    cardBattleWidget: Widget
    boardWidget*: Widget
    topBarWidget*: Widget
    columnWidgets*: Table[(TacticalSide, int), Widget]


  CombatUI* = object
    challenge*: Option[Challenge]

  ColumnB = object
    blockAmount: int
    hasBlock: bool
    characters: seq[CharacterB]

  CharacterB = object
    name: RichText
    health: int
    maxHealth: int
    hasFlags: bool
    flags: RichText
    activatedIndicator: RichText
    intent: RichText
    hasIntent: bool

  CombatChallengeFinished* = ref object of UIEvent
    combatResult*: ChallengeResult


defineDisplayReflection(CombatUI)


let healthColor = rgba(212, 64, 53, 255)
let energyColor = rgba(198, 171, 92, 255)
let activatedColor = rgba(76,184,230,255)

method initialize(g: CardBattleUI, world: LiveWorld, display: DisplayWorld) =
  g.name = "CardBattleUI"
  g.initializePriority = 0

  g.captain = toSeq(world.entitiesWithData(Captain))[0]
  g.worldWatcher = watch: world.currentTime
  g.selectedGroupWatcher = watch: display[CardUI].selectedGroup
  g.cardBattleWidget = display[WindowingSystem].desktop.createChild("CardBattleUI", "CardBattleWidget")
  g.boardWidget = g.cardBattleWidget.descendantByIdentifier("BoardWidget").get
  g.cardBattleWidget.showing = bindable(false)

  g.topBarWidget = g.cardBattleWidget.descendantByIdentifier("TopBar").get

  display.attachData(CombatUI())


proc startCombat*(cu: ref CombatUI, world: LiveWorld, captain: Entity, challenge: Challenge) =
  if challenge.kind != ChallengeKind.Combat:
    warn &"Can only start a combat challenge: {challenge}"
  else:
    cu.challenge = some(challenge)

    var enemies: seq[Entity]
    for enemyForce in challenge.enemies:
      for i in 0 ..< enemyForce.number:
        enemies.add(createEnemy(world, enemyForce.kind))

    setupTacticalBoard(world, captain, enemies)


proc toCardCostB(world: LiveWorld, entity: Entity, card: Entity, cost: CardCost): CardCostB =
  var cb : CardCostB
  case cost.kind:
    of CardCostKind.Energy:
      cb.cost = cost.energyAmount
      cb.symbol = richText("☼")
      cb.color = some(energyColor)

  cb


proc toCardDisplayB(world: LiveWorld, entity: Entity, card: Entity, groupIndex: int) : CardDisplayB =
  let cardD = card[Card]
  let groups = cardD.effectGroups
  let effGroup = groups[groupIndex]
  let name = cardD.effectGroups[groupIndex].name
  var disp : CardDisplayB
  disp.entity = card
  disp.name = richText(name)
  if effGroup.costs.len > 0:
    disp.primaryCost = some(toCardCostB(world, entity, card, effGroup.costs[0]))
  if effGroup.costs.len > 1:
    disp.secondaryCost = some(toCardCostB(world, entity, card, effGroup.costs[1]))

  if card[Card].archetype == † Cards.Strike:
    disp.image = some(image("hexcrawl/test/sword.png"))
  else:
    disp.image = some(image("ax4/images/icons/shield.png"))

  for i in 0 ..< groups.len:
    var t : RichText
    for e in groups[i].effects:
      t.add(toRichText(world, e, entity))
    disp.textOptions.add(t)

  disp

proc updateHand(g: CardBattleUI, world: LiveWorld, cardUI: ref CardUI) =
  var handB : seq[CardDisplayB]
  let deck = g.captain[Captain].deck
  let d = deck[Deck]
  let h = d.hand
  for card in d.hand:
    let cardD = card[Card]
    let groupIndex = if cardUI.tentativeCard == some(card):
      min(cardUI.selectedGroup, cardD.effectGroups.len-1)
    else:
      0

    if cardD.effectGroups.len <= groupIndex:
      warn &"Card had no effect groups? {card}"
      continue

    let disp = toCardDisplayB(world, g.captain, card, groupIndex)

    handB.add(disp)

  cardUI.hand = handB


proc intentText(world: LiveWorld, e: Entity) : RichText =
  let ec = e[EnemyCombatant]
  if not ec.actions.contains(ec.intent):
    richText("???")
  else:
    var t = richText()
    let action = ec.actions[ec.intent]
    for eff in action.effects:
      let section = case eff.kind:
        of CardEffectKind.Damage: richText(&"{eff.damageAmount} ♠", color = some(healthColor))
        of CardEffectKind.Activate: richText(&"§", color = some(activatedColor))
        of CardEffectKind.ApplyFlag: richText(&"○↓○↓○", color = some(rgba(175,175,175,255)))
        of CardEffectKind.Move:
          let str = if eff.direction == TacticalDirection.Left: "◄-"
          elif eff.direction == TacticalDirection.Right: "-►"
          elif eff.direction == TacticalDirection.Forward: "▼"
          else: "▲"
          richText(&"str", color = some(rgba(225,225,25,255)))
        of CardEffectKind.Block: richText("↑◘↑")
        of CardEffectKind.WorldEffect: richText("WorldEffect?")
      if t.nonEmpty:
        t.add(richText(" "))
      t.add(section)
    t


proc updateBoard(g: CardBattleUI, world: LiveWorld) =
  let board: ref TacticalBoard = tacticalBoard(world)
  for side in enumValues(TacticalSide):
    for x, col in board.sides[side]:
      if not g.columnWidgets.contains((side, x)):
        g.columnWidgets[(side,x)] = g.boardWidget.descendantByIdentifier("ColumnContainer").get.createChild("CardBattleUI", "ColumnWidget")
      let cw = g.columnWidgets[(side,x)]
      cw.x = fixedPos(x * 30)
      cw.y = if side == TacticalSide.Friendly:
        fixedPos((g.boardWidget.resolvedDimensions.y div 3) * 2)
      else:
        fixedPos((g.boardWidget.resolvedDimensions.y div 3))

      var colB: ColumnB
      colB.blockAmount = col.blockAmount
      colB.hasBlock = col.blockAmount != 0
      for e in col.combatants:
        var charB : CharacterB
        charB.name = richText(e[Character].name)
        charB.health = e[Character].health.currentValue
        charB.maxHealth = e[Character].health.maxValue
        charB.activatedIndicator = if board.activated == e: richText("§ ", color = some(activatedColor)) else: richText()
        if e.hasData(EnemyCombatant):
          charB.intent = intentText(world, e)
          charB.hasIntent = true

        # todo: flags
        colB.characters.add(charB)
      # info &"Colb: {colB}"
      cw.bindValue("column", colB)


method update(g: CardBattleUI, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let cardUI = display[CardUI]
  let cu = display[CombatUI]
  if cu.challenge.isSome and cu.challenge.get.kind == ChallengeKind.Combat:
    g.cardBattleWidget.showing = bindable(true)
    cardUI.active = true
    if g.worldWatcher.hasChanged or g.selectedGroupWatcher.hasChanged:
      updateHand(g, world, cardUI)
      updateBoard(g, world)
  else:
    cardUI.active = false
    g.cardBattleWidget.showing = bindable(false)




method onEvent(g : CardBattleUI, world : LiveWorld, display : DisplayWorld, event : Event) =
  matcher(event):
    extract(CardChosenEvent, card, activeGroup):
      playCard(world, g.captain, card, activeGroup)
    extract(KeyPress, key):
      if key == KeyCode.E:
        endCaptainTurn(world, g.captain)
        startEnemyTurn(world)
        performEnemyTurn(world)
        startCaptainTurn(world, g.captain)

  ifOfType(GameEvent, event):
    if event.state == GameEventState.PostEvent:
      let cu = display[CombatUI]
      if cu.challenge.isSome and cu.challenge.get.kind == ChallengeKind.Combat:
        let board: ref TacticalBoard = tacticalBoard(world)
        if entitiesOnSide(board, TacticalSide.Enemy).isEmpty:
          info &"VICTORY"
          resetTacticalBoard(world)
          cu.challenge = none(Challenge)
          display.addEvent(CombatChallengeFinished(combatResult: ChallengeResult.Success))
        elif entitiesOnSide(board, TacticalSide.Friendly).isEmpty:
          info &"DEFEAT"
          resetTacticalBoard(world)
          cu.challenge = none(Challenge)
          display.addEvent(CombatChallengeFinished(combatResult: ChallengeResult.Failure))

