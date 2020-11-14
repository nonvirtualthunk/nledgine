import engines
import graphics
import prelude
import tables
import ax4/game/characters
import strformat
import options
import ax4/game/ax_events
import windowingsystem/windowingsystem
import ax4/display/tactical_ui_component
import noto
import ax4/game/cards
import math
import patty
import graphics/core
import ax4/game/effects
import ax4/game/effect_types
import ax4/game/card_display
import ax4/game/characters
import game/library
import worlds

type
   RewardUIComponent* = ref object of GraphicsComponent
      worldWatcher: Watcher[WorldEventClock]
      selectedWatcher: Watcher[Option[Entity]]
      rewardsWidget: Widget
      cardRewardChoiceWidgets: seq[Widget]
      chosenReward: Option[int]
      skipReward: bool

method initialize(g: RewardUIComponent, world: World, curView: WorldView, display: DisplayWorld) =
   g.name = "RewardUIComponent"
   g.eventPriority = 10

   g.selectedWatcher = watch: display[TacticalUIData].selectedCharacter
   g.worldWatcher = watch: curView.currentTime

   let ws = display[WindowingSystem]
   g.rewardsWidget = ws.desktop.createChild("RewardWidgets", "RewardWidget")
   g.rewardsWidget.childByIdentifier("SkipButton").get.onEvent(WidgetMouseRelease, release):
      g.skipReward = true



method onEvent(g: RewardUIComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
   discard


proc cardRewardChoiceWidget(g: RewardUIComponent, i: int): Widget =
   if g.cardRewardChoiceWidgets.len > i:
      result = g.cardRewardChoiceWidgets[i]
   else:
      result = g.rewardsWidget.childByIdentifier("RewardOptions").get.createChild("CardWidgets", "CardWidget")
      g.cardRewardChoiceWidgets.add(result)
      result.onEvent(WidgetMouseRelease, release):
         g.chosenReward = some(i)


method update(g: RewardUIComponent, world: World, curView: WorldView, display: DisplayWorld, df: float): seq[DrawCommand] =
   withView(curView):
      let selCopt = display[TacticalUIData].selectedCharacter
      if g.worldWatcher.hasChanged or g.selectedWatcher.hasChanged or g.chosenReward.isSome or g.skipReward:
         var showRewardsScreen = false
         matcher(selCopt):
            caseSome(selC):
               let rewardChoices = selC[Character].pendingRewards
               if rewardChoices.nonEmpty:
                  let cardLib = library(CardArchetype)
                  let rewardChoice = rewardChoices[0]

                  if g.skipReward:
                     g.skipReward = false
                     world.eventStmts(RewardSkipEvent(entity: selC, choices: rewardChoice)):
                        selC.modify(Character.pendingRewards.popFront())
                  elif g.chosenReward.isSome:
                     let chosenIndex = g.chosenReward.get
                     if chosenIndex >= rewardChoice.options.len:
                        warn &"Out of bounds chosen reward?"
                     else:
                        let chosen = rewardChoice.options[chosenIndex]
                        match chosen:
                           CardReward(cardType):
                              let arch = cardLib[cardType]
                              let newCard = arch.createCard(world)
                              # TODO: [Card, Deck, DeckKind] this is locked to just combat deck atm, should select based on card type
                              addCard(world, selC, newCard, DeckKind.Combat, CardLocation.DrawPile)
                        world.eventStmts(RewardChosenEvent(entity: selC, reward: chosen, choices: rewardChoice)):
                           selC.modify(Character.pendingRewards.popFront())
                        g.chosenReward = none(int)
                  else:
                     showRewardsScreen = true

                     var i = 0
                     var numOptions = rewardChoice.options.len
                     var gapBetween = 1.0f / numOptions.float
                     for option in rewardChoice.options:
                        match option:
                           CardReward(cardType):
                              let cardWidget = g.cardRewardChoiceWidget(i)
                              let cardInfo = cardInfoFor(curView, SentinelEntity, cardLib[cardType], 0)
                              cardWidget.bindValue("card", cardInfo)
                              cardWidget.showing = bindable(true)
                              cardWidget.x = proportionalPos(gapBetween * (i.float + 0.5f), WidgetOrientation.TopLeft, WidgetOrientation.Center)
                              cardWidget.y = centered()
                        i.inc

         g.rewardsWidget.showing = bindable(showRewardsScreen)
         if not showRewardsScreen:
            for w in g.cardRewardChoiceWidgets:
               w.showing = bindable(false)
      @[]

