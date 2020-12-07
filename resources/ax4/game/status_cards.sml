CardTypes {
   Slime {
      name : Slime
      isA: StatusCard
      image : ax4/images/card_images/slime.png

      cardEffectGroups : [
         {
            costs : [ActionPoints(-1), StaminaPoints(-1)]
            effects: [Exhaust]
         },
      ]
   }
}