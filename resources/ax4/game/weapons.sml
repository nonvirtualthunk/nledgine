Items {
   Longspear : {
      durability : 25

      weaponSkills : [Fighter]

      usesBodyParts : {
         gripping : 2
      }

      attackCardCount : 4

      attacks : {
         primary : {
            name : stab
            attackTypes : [physical attack, reach attack, melee attack]
            actionCost : 2
            accuracy : 1
            strikeCount : 1
            staminaCost : 2
            minRange : 2
            maxRange : 2
            damage : 1d3 + 4 Piercing
         }

         secondary : {
            name : slam
            attackTypes : [physical attack, melee attack]
            actionCost : 2
            staminaCost : 1
            accuracy : -1
            strikeCount : 1
            minRange : 1
            maxRange : 1
            damage : 1d2 + 1 Bludgeoning
         }
      }
   }
}