CharacterClasses {

   Fighter {
      startingCards : [PowerAttack]
      startingEquipment: [LongSword, RoundShield]
      cardRewards : [PiercingStab, DoubleStrike, SwiftStrike, PinpointStab]
   }

   Barbarian {
      specializationOf: Fighter
      cardRewards : [Vengeance, TirelessFury]
   }

   Tactician {
      specializationOf: Fighter
      
   }


   Movement {
      cardRewards: [FightAnotherDay, DuckAndWeave, Dodge, Sprint, DeepBreath]
   }

}