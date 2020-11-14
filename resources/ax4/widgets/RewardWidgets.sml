RewardWidget {
   width : 85%
   height : 75%
   x: centered
   y: centered
   z: 200
   background.image : "ui/fancyBackground.png"
   background.pixelScale : 2
//   consumeMouseButtonEvents: true

   children {
      RewardTitle {
         type : TextDisplay

         text : "Choose Reward"
         background.draw : false
         fontSize : 20
         horizontalAlignment : center
         width : 90%
         x : centered
         y : 4
      }

      RewardOptions {
         //type: ListWidget
         type: Div
         x: 5
         y: 30
         width: -10
         height: -90
         background.draw : false

         //listItemArchetype : RewardWidgets.RewardOptionWidget
         //listItemBinding : "reward.rewardOptions -> rewardOption"
      }

      SkipButton {
         type: TextDisplay

         x : centered
         y : 10 below RewardOptions

         text : "Skip"
         fontSize: 20

         padding: [10,2]

         background.draw: true
         background.image: "ui/buttonBackground.png"
      }
   }
}

RewardOptionWidget {
   type: Div
   width : 20
   height : 20
   background.draw : true
   background.image : "ui/fancyBackground.png"
}