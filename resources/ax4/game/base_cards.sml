Cards {
   Move {
      name : Move
      image : ax4/images/card_images/move.png
      xp {
         MoveSkill : 1
      }

      cardEffectGroups : [
         {
            costs : [ActionPoints(1), StaminaPoints(0)]
            effects: [Move(3)]
         },
         {
            name : Hurry
            costs : [ActionPoints(2), StaminaPoints(1)]
            effects: [Move(5)]
         }
      ]
   }

   PiercingStab {
      name : "Piercing Stab"
      
      xp {
         WeaponSkill : 2
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
}