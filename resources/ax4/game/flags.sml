Flags {
   Parry {
      mechanicalDescription: "increases defense by 1 per point"
      description : "Parry incoming attacks, reducing their chance to hit"
      vagueDescription : "You will weave a maze of steel between you and your enemies"
      tickDown : OnMissed
      resetAtStartOfTurn : true
      hidden : false
      countsAs : DefenseDelta
   }

   Block {
      mechanicalDescription: "reduces instead of health when damage is taken"
      description : "Block incoming attacks, reducing the damage they deal"
      vagueDescription : "Their blows crash like waves on the cliff, but even stone crumbles in the end"
      resetAtStartOfTurn : true
      limitToZero : true
      hidden : false
   }

   Tiring {
      mechanicalDescription: "increases stamina cost by 1 per point every time this card is played"
      description : "Becomes increasingly tiring the more it is used in a turn. Costs [N] additional stamina each time it is used."
      vaugeDescription : "Do not judge the height of the mountain from the plains below"
      resetAtEndOfTurn : true
      hidden : false
      countsAs : StaminaCostDelta
   }

   Slow {
      mechanicalDescription: "reduces move points gained by move cards by 1 per point"
      description : "Slowed down, each point reduces the amount of move gained by move cards by one"
      vagueDescription : "A thickness in the air, a softness in the ground, a weakness in your legs"
      tickDownOn : EndOfTurn
      hidden : false
      countsAsNegativeOne : MovementGainDelta
   }

   Stunned {
      mechanicalDescription: "reduces the number of action points each turn by one, reduces by one each turn"
      description : "Stunned and disoriented, reduces the number of action points each turn by one"
      vagueDescription : "The blow lays heavy on your mind, the shock in your limbs, the catch in your breath"
      hidden : false
      countsAsNegative : ApGainDelta
      tickDownOn : EndOfTurn
   }

   FlashingPoints {
      mechanicalDescription: "attacks apply 2 [flags.dazzled]"
      description : "Your swift disorienting attacks dazzle your enemies, aggravating them and applying 2 [flags.dazzled]"
      vagueDescription : "A flash at the eyes, a jab at the chest, they see only your blade. And you."
      resetAtEndOfTurn : false
      hidden : false
      tickDownOn : EndOfTurn

      attackModifiers : {
         conditionalEffects : [
            {
               kind: OnHit
               target : target
               effect : Dazzled(2)
            }
         ]
      }
   }

   Dazzled {
      description : "Dazzled by light or distraction, each point reduces accuracy by one until end of turn"
      vagueDescription : "The light is in your eyes, the colors still burn when it is gone"
      resetAtEndOfTurn : true
      hidden : false
      countsAsNegative : AccuracyDelta
   }

   TurtleStance {
      description : "You take cover behind your shield, gaining 4 armor and 4 block, so long as you do not attack"
      vagueDescription : "Your shield is a shell, the blows skip away like stones on the water."
      resetAtStartOfTurn : false // you stay in turtle stance until you attack, it does not end itself
      binary : true
      hidden : false

      countsAs : [
         Armor(4),
         EndOfTurnBlockGain(4)
      ]

      tickDownOn : Attack
   }

   HedgehogStance {
      description : "You ready your weapon against any that might come to close, so long as you do not move"
      vagueDescription : "Iron quills at the ready. Your adversaries may approach, but not unhindered"
      resetAtStartOfTurn : false
      binary : true
      hidden : false

      countsAs : OnApproachAttack

      tickDownOn : Move
   }

   Armor {
      description : "Armor protects you, reducing physical damage by one for every point of armor"
      vagueDescription: ""

      countsAs: ArmorDelta
   }


   OnApproachAttack {
      description : "OnApproachAttack"
      hidden : true
   }

   MovementGainDelta {
      description : "Movement Gain Delta"
      hidden : true
   }

   ApCostDelta {
      description : "AP Cost delta"
      hidden : true
   }

   StaminaCostDelta {
      description : "Stamina Cost delta"
      hidden : true
   }

   AccuracyDelta {
      description : "Accuracy delta"
      hidden : true
   }

   DefenseDelta {
      description : "Defense delta"
      hidden : true
   }

   ArmorDelta {
      description : "Armor delta"
      hidden : true
   }

   ApGainDelta {
      description : "AP Gain Delta"
      hidden : true
   }

   ZoneOfControlRange {
      description : "Zone of Control Range"
      hidden : true
   }

   EndOfTurnBlockGain {
      description : "End of Turn Block Gain"
      hidden : true
   }
}