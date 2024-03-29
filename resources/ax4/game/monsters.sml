MonsterClasses {
   
   GreenSlime {
      health: 10-13
      stamina: 3
      sightRange: 5
      xp: 5


      images : ["ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_218.png"]
      actions : {
         charge {
            weight : 2
            conditions : []
            effects : [
               {
                  target : ClosestEnemy
                  effect : Move(3)
               },
               {
                  target : ClosestEnemy
                  effect : +0 2 Bludgeoning (SimpleNaturalAttack)
               }
            ]
         },
         slime spray {
            weight : 1
            conditions : [Enemy, InRange(2)]
            effects : [
               {
                  target {
                     preference: Closest
                     filters : [Enemy, InRange(2)]
                  }
                  effect : Weak(2)
               }
            ]
         },
         slime smoosh {
            weight : 4
            conditions : [Enemy, InRange(1)]
            effects : [
               {
                  target : ClosestEnemy
                  effect : {
                     kind : attack
                     attackTypes : [MeleeAttack, NaturalAttack, PhysicalAttack]
                     damage : 4 Bludgeoning
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

   PurpleSlime {
      health: 12-15
      stamina: 3
      sightRange: 5
      xp: 5

      images : ["ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_235.png"]

      actions : {
         charge {
            weight : 2
            conditions : []
            effects : [
               {
                  target : ClosestEnemy
                  effect : Move(3)
               },
               {
                  target : ClosestEnemy
                  effect : +0 3 Bludgeoning (SimpleNaturalAttack)
               }
            ]
         },
         sticky slime spray {
            weight : 1
            conditions : [Enemy, InRange(2)]
            effects : [
               {
                  target {
                     preference: Closest
                     filters : [Enemy, InRange(2)]
                  }
                  effect : Slow(2)
               }
            ]
         },
         slime smoosh {
            weight : 4
            conditions : [Enemy, InRange(1)]
            effects : [
               {
                  target : ClosestEnemy
                  effect : {
                     kind : attack
                     attackTypes : [MeleeAttack, NaturalAttack, PhysicalAttack]
                     damage : 5 Bludgeoning
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

   GreyRat {
      health: 3-6
      stamina: 3
      sightRange: 5
      xp: 5

      images: ["ax4/images/oryx/creatures_24x24/oryx_16bit_fantasy_creatures_224.png"]

      actions : {
         scurry {
            weight : 2
            conditions : []
            effects : [
               {
                  target : ClosestEnemy
                  effect : Move(4)
               },
               {
                  target : ClosestEnemy
                  effect : +0 1 Piercing (SimpleNaturalAttack)
               }
            ]
         },
         flee {
            weight : 4
            conditions : [Self, IsDamaged]
            effects : [
               {
                  target : {
                     preference: Random
                     filters: ["HexInRange(4,4)"]
                  }
                  effect : Move(4)
               }
            ]
         }
      }
   }  
}