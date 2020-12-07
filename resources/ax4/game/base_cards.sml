CardTypes {
   // Movement cards
   Move {
      name : Move
      isA: MoveCard
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
      isA: MoveCard
      rarity: uncommon
      image  : ax4/images/card_images/move.png
      xp : Movement -> 1

      effects: [Move(4)]
      costs: [ActionPoints(-1), StaminaPoints(-1)]
      conditionalEffects: {
         condition : [Self, Damaged]
         effects : [StaminaPoints(+1)]
      }
   }

   Dodge {
      name : "Dodge"
      isA: DefenseCard
      rarity : common
      xp : Movement -> 1

      effects : [Dodge(3)]
      costs : [ActionPoints(-1), StaminaPoints(-1)]
   }

   Sprint {
      name : "Sprint"
      isA: MoveCard
      rarity : common

      effects: [Move(6)]
      costs: [ActionPoints(-1), StaminaPoints(-2)]
   }

   DuckAndWeave {
      name : "Duck and Weave"
      isA: DefenseCard
      rarity : common
      xp : Movement -> 1

      effects : [Move(1), Dodge(2)]
      costs : [ActionPoints(-1), StaminaPoints(-1)]
   }

   DeepBreath {
      name : "Deep Breath"
      isA: SkillCard
      rarity : common
      xp : Movement -> 1
      
      effects : [ActionPoints(-1), StaminaPoints(+3)]
   }

   Sprint {
      name : "Sprint"
      isA: MoveCard
      rarity : common
      xp : Movement -> 1

      effects : [Move(6)]
      costs : [ActionPoints(-1), StaminaPoints(-2)]
   }

   
   // Fighter cards
   PiercingStab {
      name : "Piercing Stab"
      isA: [AttackCard, FighterCard]
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
      isA: [AttackCard, FighterCard]

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
      isA: [AttackCard, FighterCard]

      rarity : common
      xp : Fighter -> 2

      effects : [{
         kind : attack

         attackSelector : [DamageType(Bludgeoning)]
         attackModifier : {
            accuracy : -1
            damage : +5
            derivedModifiers : [damage +1 per Unbalanced on self, damage +1 per Rage on self]
         }
      },Unbalanced(-1)]
   }

   DoubleStrike {
      name : "Double Strike"
      isA: [AttackCard, FighterCard]

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
      isA: [AttackCard, FighterCard]

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
      isA: [AttackCard, FighterCard]
      
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
      isA: [SkillCard, FighterCard]

      rarity : uncommon

      xp {
         Fighter : 1
      }

      effects : [Vengeance(1)]
      costs : [ActionPoints(0), StaminaPoints(-1)]
   }
   
   TirelessFury {
      name : "Tireless Fury"
      isA: [SkillCard, FighterCard]

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