import game_prelude
import engines
import windowingsystem/windowingsystem
import windowingsystem/rich_text
import windowingsystem/ascii_cards
import graphics/color
import sequtils
import noto
import game/cards

import hex_crawl/game/logic
import hex_crawl/game/data


type
  CardBattleUI* = ref object of GraphicsComponent
    captain*: Entity
    worldWatcher*: Watcher[WorldEventClock]
    selectedGroupWatcher: Watcher[int]


  CombatUI* = object
    challenge*: Option[Challenge]

defineDisplayReflection(CombatUI)

method initialize(g: CardBattleUI, world: LiveWorld, display: DisplayWorld) =
  g.name = "CardBattleUI"
  g.initializePriority = 0

  g.captain = toSeq(world.entitiesWithData(Captain))[0]
  g.worldWatcher = watch: world.currentTime
  g.selectedGroupWatcher = watch: display[CardUI].selectedGroup

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
      cb.color = some(rgba(198, 171, 92, 255))

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



method update(g: CardBattleUI, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  let cardUI = display[CardUI]
  let cu = display[CombatUI]
  if cu.challenge.isSome and cu.challenge.get.kind == ChallengeKind.Combat:
    cardUI.active = true
    if g.worldWatcher.hasChanged or g.selectedGroupWatcher.hasChanged:
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
  else:
    cardUI.active = false




method onEvent(g : CardBattleUI, world : LiveWorld, display : DisplayWorld, event : Event) =
  discard