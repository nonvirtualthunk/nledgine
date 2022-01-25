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

   SpearAttack {
      name: "Spear Attack"
      isA: AttackCard
      image: ax4/images/card_images/slash.png
      rarity: starter

      xp: Fighter -> 1
      cardEffectGroups: [
         {
            name: "stab"
            effects: [{
               kind: attack
               attackTypes: [reach attack]
               actionCost : 2
               staminaCost : 2

               damage: 8
               strikeCount : 1
               minRange : 2
               maxRange : 2
            }]
         },
         {
            name: "slam"
            effects: [{
              kind: attack
               actionCost: 1
               staminaCost: 1

               damage: 4
               strikeCount: 1
               minRange: 0
               maxRange: 0

            }]
         }
      ]
   }

   SwordAttack {
      name: "Sword Attack"
      isA: AttackCard
      image: ax4/images/card_images/slash.png
      rarity: starter

      xp: Fighter -> 1
      cardEffectGroups: [
         {
            name: "slash"
            effects: [{
               kind: attack

               actionCost : 1
               staminaCost : 1

               damage: 6 Slashing
               strikeCount : 1
               minRange : 1
               maxRange : 1
            }]
         },
         {
            name: "stab"
            effects: [{
               kind: attack
               actionCost: 1
               staminaCost: 1

               damage: 4 Piercing
               strikeCount: 1
               minRange: 1
               maxRange: 1

            }]
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

   
   // Fighter cards
   PowerAttack {
      name: "Power Attack"
      isA: [AttackCard, FighterCard]   
      image : ax4/images/card_images/slash.png

      rarity : starter

      xp: Fighter -> 2

      effects: [{
         kind: attack


         actionCost: 2
         staminaCost: 2
         target: single
         damage: 8
         minRange: 1
         maxRange: 1
         strikeCount: 1
         conditionalEffects : [{
            kind: OnHit
            target: target
            effect: Vulnerable(2)
         }]
      }]
   }

   PiercingStab {
      name : "Piercing Strike"
      isA: [AttackCard, FighterCard]
      image : ax4/images/card_images/piercingStab.png
      
      rarity : common

      xp: Fighter -> 2

      effects : [{
         kind : attack

         actionCost: 1
         staminaCost: 2
         target: "line(1,2)"
         damage: 8
         minRange: 1
         maxRange: 1
      }]
   }

   PinpointStab {
      name : "Pinpoint Strike"
      isA: [AttackCard, FighterCard]

      rarity : common
      xp : Fighter -> 2

      effects : [{
         kind : attack

         actionCost: 1
         staminaCost: 0
         target: single
         damage: 5
         strikeCount: 1

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

      effects : [
         {
            kind : attack

            target: single
            damage: 5
            accuracy: -1
            derivedModifiers: [
               "damage +1 per Unbalanced on self",
               "damage +1 per Rage on self"
            ]
         },
         "Unbalanced(+1)"
      ]
   }

   DoubleStrike {
      name : "Double Strike"
      isA: [AttackCard, FighterCard]

      rarity : common

      xp : Fighter -> 2

      effects : [{
         kind : attack

         actionCost: 1
         staminaCost: 1
         target: single
         damage: 5
         strikeCount: 2
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

            actionCost: 1
            staminaCost: 2
            target: single
            damage: 6
            strikeCount: 1
         }
      ]
   }

   SwiftStrike {
      name : "Swift Strike"
      isA: [AttackCard, FighterCard]
      
      rarity : common

      xp : Fighter -> 2

      effects : [{
         kind : attack

         actionCost: 0
         staminaCost: 2
         damage: 7
         strikeCount: 1
      }]
   }

   Vengeance {
      name : "Vengeance"
      isA: [SkillCard, FighterCard]

      rarity : uncommon

      xp : Fighter -> 1

      ap: 0
      stamina: 1
      effects : [Vengeance(1)]
   }
   
   TirelessFury {
      name : "Tireless Fury"
      isA: [SkillCard, FighterCard]

      rarity : uncommon

      xp : Fighter -> 2


      ap: 0
      effects : [StaminaPoints(1)]
      conditionalEffects : {
         condition : NoFlagValue(Rage)
         effects: [Rage(1)]
      }
      costs : [ActionPoints(0)]
   }

   

}