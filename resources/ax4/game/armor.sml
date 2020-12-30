Items {
   RoundShield {
      isA : Shield
      weaponSkills : [Fighter]

      usesBodyParts : {
         gripping : 1
      }

      equipCards : [ShieldBlock, ShieldBlock, ShieldBlock]

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

CardTypes {
   ShieldBlock {
      name: "Shield Block"
      isA: [BlockCard]   
      image : ax4/images/card_images/parry.png

      rarity : item

      xp: Fighter -> 1

      cardEffectGroups : [
         {
            name : "Block"
            costs : [ActionPoints(-1)]
            effects : [Block(5)]
         },
         {
            name : "Shield Bash"
            effects : [{
               kind: SimpleAttack

               attackTypes: [shield bash]
               actionCost: 1
               staminaCost: 1
               accuracy: -1
               strikeCount: 1
               minRange: 1
               maxRange: 1
               damage: 1d2 Bludgeoning
               conditionalEffects: [OnHit(Push(1))]
            }]
         },
      ]
   }
}