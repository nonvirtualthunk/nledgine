MonsterClasses {
   
   slime {
      health: 1d3+3
      stamina: 3
      sightRange: 5
      xp: 5


      images : ["ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_218.png"]
      actions : {
         charge {
            weight : 1
            conditions : []
            effects : [
               {
                  target : ClosestEnemy
                  effect : Move(3)
               },
               {
                  target : ClosestEnemy
                  effect : +1 1d2 Bludgeoning (SimpleNaturalAttack)
               }
            ]
         },
         slime smoosh {
            weight : 2
            conditions : ["Near(Enemy, 1)"]
            effects : [
               {
                  target : ClosestEnemy
                  effect : {
                     kind : SimpleAttack
                     attackTypes : [MeleeAttack, NaturalAttack, PhysicalAttack]
                     damage : 1d10 Bludgeoning
                     minRange : 0
                     maxRange : 1
                     accuracy : -1
                     strikeCount : 1
                     actionCost : 3
                     staminaCost : 1
                     target : Single
                     conditionalEffects: [OnHit(AddCard(Slime))]
                  }
               }
            ]
         }
      }
   }

}