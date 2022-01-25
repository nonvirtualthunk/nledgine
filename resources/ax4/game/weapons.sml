Items {
   Longspear : {
      isA: [Spear]
      durability : 25

      weaponSkills : [Fighter]

      usesBodyParts : {
         gripping : 2
      }

      attackCardCount : 4
      attackCard: CardTypes.SpearAttack
      weaponModifiers : {
         minRange: "+1"
         maxRange: "+1"
      }
   }

   LongSword : {
      isA: [Sword]
      durability : 25

      weaponSkills : [Fighter]

      usesBodyParts : {
         gripping : 1
      }

      attackCardCount : 4
      attackCard: CardTypes.SwordAttack
      weaponModifiers : {
         damage: "+1"
      }
   }
}