CardWidget {
   width : 250
   height : 500
   background.image : "ax4/images/ui/card_border.png"
   background.pixelScale : 2
//   consumeMouseButtonEvents: true

   children {
      CardName {
         type : TextDisplay

         text : "%(card.name)"
         background.draw : false
         fontSize : 30
         textAlignment : center
         width : 80%
         x : centered
         y : 0
      }

      CardImage {
         type : ImageDisplay

         image : "%(card.image)"
         scale : scale(200%)
         positionStyle : center

         x : centered
         y : 5 below CardName

         width : 175
         height : 125

         background.image : "ui/fancyBackgroundWhite.png"
         background.pixelScale : 1
         background.color : [0.9,0.88,0.85,1.0]
      }

      CardMainCost {
         type : TextDisplay

         background.draw : false

         text : "%(card.mainCost)"

         x : 0 from right
         y : 0

         fontSize : 20
      }

      CardSecondaryCost {
         type : TextDisplay

         background.draw : false

         text : "%(card.secondaryCost)"

         x : 5
         y : 0

         fontSize : 10
      }

   }

}

CardEffect {
   type : TextDisplayWidget

   drawBackground : false

   text : "%(effect)"

   textAlignment : centered
   width : 100%

   fontScale : 2
}

CardEffectGroupDivider {
   type : ImageDisplayWidget

   image : "graphics/ui/card_divider.png"
   scalingStyle : scale(200%)
   x : centered

   drawBackground : false
}



CardPileWidget {
   type : ImageDisplayWidget

   drawBackground : false

   image : "%(pile.icon)"
   showing : "%(pile.showing)"

   scalingStyle : scale(200%)

   children {
      CardCountWidget: {
         type: TextDisplayWidget

         drawBackground : false

         text: "%(pile.cardCount)"
         fontScale : 3
         fontColor : [0,0,0,1]

         x: 0 from right
         y: 0 from bottom
      }
   }
}