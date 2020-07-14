CardWidget {
   width : 275
   height : 450
   background.image : "ax4/images/ui/card_border.png"
   background.pixelScale : 2
//   consumeMouseButtonEvents: true

   overlays: [
      {
         image : "ax4/images/ui/active_card_overlay.png"
         pixelScale : 2
         color : [1.0,1.0,1.0,1.0]
         draw : %(card.active)
         drawCenter : true
         dimensionDelta: [3,3]
      },
      {
         image : "ax4/images/ui/locked_overlay.png"
         pixelScale : 1
         color : [1.0,1.0,1.0,1.0]
         draw : %(card.locked)
         drawCenter : false
      }
   ]

   children {
      CardName {
         type : TextDisplay

         text : "%(card.name)"
         background.draw : false
         fontSize : 20
         horizontalAlignment : center
         width : 80%
         x : centered
         y : 4
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

         x : 5 from right
         y : 2

         fontSize : 18
      }

      CardSecondaryCost {
         type : TextDisplay

         background.draw : false

         text : "%(card.secondaryCost)"

         x : 5
         y : 2

         fontSize : 18
      }

      CardMainSection {
         type : Div

         x : 5
         y : 0 below CardImage
         width : -10
         height : expand to parent
         background.draw : false

         children : {
            CardEffects {
               type : ListWidget

               y : centered
               width : 100%
               height : wrap content
               background.draw : false

               listItemArchetype : CardWidgets.CardEffect
               listItemBinding: "card.effects -> effect"
               listItemGapSize : 30
               separatorArchetype : "CardWidgets.CardEffectGroupDivider"
               selectable : true
            }
         }
      }

   }

}

CardEffect {
   type : TextDisplay

   background.draw : false

   text : "%(effect)"

   horizontalAlignment : centered
   width : 100%

   fontSize : 20

   padding : [0,5]
}

CardEffectGroupDivider {
   type : ImageDisplay

   image : "ax4/images/ui/card_divider.png"
   scale : scale(100%)
   x : centered

   background.draw : false
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

         background.draw : false

         text: "%(pile.cardCount)"
         fontScale : 3
         fontColor : [0,0,0,1]

         x: 0 from right
         y: 0 from bottom
      }
   }
}