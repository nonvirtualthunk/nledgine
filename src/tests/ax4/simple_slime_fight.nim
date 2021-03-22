import ax4/game/game_logic
import tests/ax4/test_harness
import hex
import prelude
import worlds/taxonomy
import ax4/game/characters
import ax4/game/vision
import core
import ax4/game/items
import ax4/game/cards
import prelude
import sequtils
import noto
import ax4/game/effects
import ax4/game/targeting_types
import options
import game/library
import ax4/game/turns
import ax4/game/enemies
import patty

proc simpleSlimeFight() =
   let (engine, world, worldInfo) = testEngine()
   withWorld(world):
      createBasicMap(world)

      let tobold = createCharacter(world, worldInfo.playerFaction)
      placeCharacterInWorld(world, tobold, axialVec(0, 0, 0))

      let slime = createMonster(world, worldInfo.enemyFaction, taxon("MonsterClasses", "slime"))
      placeCharacterInWorld(world, slime, axialVec(2, 0, 0))
      # give the slime a bunch of xp so we can test the leveling
      slime.modify(Monster.xp += 20)

      let vengeance = library(CardArchetype)[taxon("card types", "vengeance")].createCard(world)
      addCard(world, tobold, vengeance, DeckKind.Combat, CardLocation.Hand)

      endTurn(world)

      let spear = createItem(world, taxon("items", "longspear"))
      equipItem(world, tobold, spear)

      # Check basic preconditions are working as expected
      assert areEnemies(world, tobold, slime), "tobold and slime should be enemies"

      assert isVisibleTo(world, tobold, slime), "tobold should be able to see slime"
      assert isVisibleTo(world, slime, tobold), "slime should be able to see tobold"

      assert slime[Character].health.currentValue > 0, "slime should have an actual health value"

      let hand = cardsInLocation(world, tobold, DeckKind.Combat, CardLocation.Hand)

      assert hand.nonEmpty

      let vengeanceCard = hand.findIt(it[Identity].kind == taxon("card types", "vengeance"))
      assert vengeanceCard.isSome
      playCard(world, tobold, vengeanceCard.get, 0, (selKey: SelectorKey, selector: Selector) => SelectedEntity(@[tobold]))

      let attackCard = hand.findIt(it[Identity].kind == taxon("card types", "attack card"))
      assert attackCard.isSome
      playCard(world, tobold, attackCard.get, 0, (selKey: SelectorKey, selector: Selector) => SelectedEntity(@[slime]))

      assert tobold[Character].xp[taxon("Character Classes", "Fighter")] == slime[Monster].xp
      assert tobold[Character].pendingRewards.len == 1
      assert tobold[Character].pendingRewards[0].options.len == 3
      match tobold[Character].pendingRewards[0].options[0]:
         CardReward(card):
            info &"Possible card reward: {card}"




simpleSlimeFight()




