Cards {
   // Movement cards
   Move {
      name : Move
      image : ax4/images/card_images/move.png
      xp : Movement -> 1

      cardEffectGroups : [
         {
            costs : [ActionPoints(-1), StaminaPoints(0)]
            effects: [Move(3)]
         },
         {
            name : Hurry
            costs : [ActionPoints(-2), StaminaPoints(-1)]
            effects: [Move(5)]
         }
      ]
   }

   FightAnotherDay {
      name : "Fight Another Day"
      image  : ax4/images/card_images/move.png
      xp : Movement -> 1

      effects: [Move(4)]
      costs: [ActionPoints(-1), StaminaPoints(-1)]
      conditionalEffects: {
         condition : damaged
         effects : [StaminaPoints(+1)]
      }
   }

   Dodge {
      name : "Dodge"
      rarity : common
      xp : Movement -> 1

      effects : [Dodge(2)]
      costs : [ActionPoints(-1), StaminaPoints(-1)]
   }

   DuckAndWeave {
      name : "Duck and Weave"
      rarity : common
      xp : Movement -> 1

      effects : []
      costs : [ActionPoints(0), StaminaPoints(-1)]
   }

   DeepBreath {
      name : "Deep Breath"
      rarity : common
      xp : Movement -> 1
      
      effects : [ActionPoints(-1), StaminaPoints(+3)]
   }

   Sprint {
      name : "Sprint"
      rarity : common
      xp : Movement -> 1

      effects : [Move(6)]
      costs : [ActionPoints(-1), StaminaPoints(-2)]
   }

   
   // Fighter cards
   PiercingStab {
      name : "Piercing Stab"
      image : ax4/images/card_images/piercingStab.png
      
      rarity : common

      xp {
         Fighter : 2
      }

      effects : [{
         kind : attack

         attackSelector : [AttackType(ReachAttack), DamageType(Piercing)]
         attackModifier : {
            accuracy : -1
            target : "setTo line(1,2)"
            minRange : "setTo 1"
            maxRange : "setTo 1"
         }
      }]
   }

   PinpointStab {
      name : "Pinpoint Stab"

      rarity : common
      xp : Fighter -> 2

      effects : [{
         kind : attack

         attackSelector : [DamageType(Piercing)]
         attackModifier : {
            accuracy : +3
         }
         conditionalEffects : [{
            kind: OnHit
            target: target
            effect: Dodge(-1)
         }]
      }]  
   }

   RecklessSmash {
      name : "Reckless Smash"

      rarity : common
      xp : Fighter -> 2

      effects : [{
         kind : attack

         attackSelector : [DamageType(Bludgeoning)]
         attackModifier : {
            accuracy : -1
            damage : +5
         }
      },Unbalanced(-1)]
   }

   DoubleStrike {
      name : "Double Strike"

      rarity : common

      xp {
         Fighter : 2
      }

      effects : [{
         kind : attack

         attackModifier : {
            strikeCount : "setTo 2"
            damage : -1
            staminaCost : +1
         }
      }]
   }

   ChargingStrike {
      name : "Charging Strike"

      rarity : common

      xp {
         Fighter : 2
      }

      effects : [
         "Move(2)",
         {
            kind : attack

            attackModifier {
               staminaCost : +1
            }
         }
      ]
   }

   SwiftStrike {
      name : "Swift Strike"
      
      rarity : common

      xp {
         Fighter : 2
      }

      effects : [{
         kind : attack

         attackModifier {
            actionCost : -1
            staminaCost : +1
         }
      }]
   }

   Vengeance {
      name : "Vengeance"

      rarity : uncommon

      xp {
         Fighter : 1
      }

      effects : [Vengeance(1)]
      costs : [ActionPoints(0), StaminaPoints(-1)]
   }
   
   TirelessFury {
      name : "Tireless Fury"

      rarity : uncommon

      xp : Fighter -> 2


      effects : [StaminaPoints(1)]
      conditionalEffects : {
         condition : NoFlagValue(Rage)
         effects: [Rage(1)]
      }
      costs : [ActionPoints(0)]
   }

   

}