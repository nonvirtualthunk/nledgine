Flags {
   Parry {
      isA: PositiveFlag
      mechanicalDescription: "increases defense by 1 per point"
      description : "Parry incoming attacks, reducing their chance to hit"
      vagueDescription : "You will weave a maze of steel between you and your enemies"
      tickDown : OnMissed
      resetAtStartOfTurn : true
      hidden : false
      countsAs : DefenseDelta
   }

   Block {
      isA: PositiveFlag
      mechanicalDescription: "reduces instead of health when damage is taken"
      description : "Block incoming attacks, reducing the damage they deal"
      vagueDescription : "Their blows crash like waves on the cliff, but even stone crumbles in the end"
      resetAtStartOfTurn : true
      limitToZero : true
      hidden : false
   }

   Tiring {
      isA: NegativeFlag
      mechanicalDescription: "increases stamina cost by 1 per point every time this card is played"
      description : "Becomes increasingly tiring the more it is used in a turn. Costs [N] additional stamina each time it is used."
      vaugeDescription : "Do not judge the height of the mountain from the plains below"
      resetAtEndOfTurn : true
      hidden : false
      countsAs : StaminaCostDelta
   }

   Slow {
      isA: NegativeFlag
      mechanicalDescription: "reduces move points gained by move cards by 1 per point"
      description : "Slowed down, each point reduces the amount of move gained by move cards by one"
      vagueDescription : "A thickness in the air, a softness in the ground, a weakness in your legs"
      tickDown : OnEndOfTurn
      hidden : false
      countsAsNegativeOne : MovementGainDelta
   }

   Weak {
      isA: NegativeFlag
      description: "Weakened, reduces damage dealt by 25%, reduced by 1 each turn"
      tickDown : OnEndOfTurn
      countsAs25: DamageDealtReductionPercent
   }

   Vulnerable {
      isA: NegativeFlag
      description : "Vulnerable, increases damage taken by 50%, reduced by 1 each turn"
      tickDown: OnEndOfTurn
      countsAs50: DamageTakenIncreasePercent
   }

   Stunned {
      isA: NegativeFlag
      mechanicalDescription: "reduces the number of action points each turn by one, reduces by one each turn"
      description : "Stunned and disoriented, reduces the number of action points each turn by one"
      vagueDescription : "The blow lays heavy on your mind, the shock in your limbs, the catch in your breath"
      hidden : false
      countsAsNegative : ApGainDelta
      tickDown : OnEndOfTurn
   }

   FlashingPoints {
      isA: PositiveFlag
      mechanicalDescription: "attacks apply 2 [flags.dazzled]"
      description : "Your swift disorienting attacks dazzle your enemies, aggravating them and applying 2 [flags.dazzled]"
      vagueDescription : "A flash at the eyes, a jab at the chest, they see only your blade. And you."
      resetAtEndOfTurn : false
      hidden : false
      tickDown : OnEndOfTurn

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
      isA: NegativeFlag
      description : "Dazzled by light or distraction, each point reduces accuracy by one until end of turn"
      vagueDescription : "The light is in your eyes, the colors still burn when it is gone"
      resetAtEndOfTurn : true
      hidden : false
      countsAsNegative : AccuracyDelta
   }

   TurtleStance {
      isA: PositiveFlag
      description : "You take cover behind your shield, gaining 4 armor and 4 block, so long as you do not attack"
      vagueDescription : "Your shield is a shell, the blows skip away like stones on the water."
      resetAtStartOfTurn : false // you stay in turtle stance until you attack, it does not end itself
      binary : true
      hidden : false

      countsAs : [
         Armor(4),
         EndOfTurnBlockGain(4)
      ]

      tickDown : OnAttack
   }

   HedgehogStance {
      isA: PositiveFlag
      description : "You ready your weapon against any that might come to close, so long as you do not move"
      vagueDescription : "Iron quills at the ready. Your adversaries may approach, but not unhindered"
      resetAtStartOfTurn : false
      binary : true
      hidden : false

      countsAs : OnApproachAttack

      tickDown : OnMove
   }

   Armor {
      isA: PositiveFlag
      description : "Armor protects you, reducing physical damage by one for every point of armor"
      vagueDescription: ""

      countsAs: ArmorDelta
   }

   Poison {
      isA: NegativeFlag
      description : "Poison deals poison damage to you at the end of every turn then decreases by 1"
      vagueDescription: ""

      countsAs: "EndOfTurnDamage[DamageTypes.Poison](1)"
   }

   Rage {
      isA: PositiveFlag
      description : "Rage increases your dmage dealt and damage taken by 1"
      
      tickDown : OnStartOfTurn

      countsAsOne : [DamageBonus, ExtraDamageTaken]
   }

   Vengeance {
      isA: PositiveFlag
      description : "Vengeance increases your Rage by 2 each time you are attacked"

      tickDown : OnStartOfTurn
      behaviors : [{
         trigger : OnAttacked
         effect : changeFlag(Rage, +2)
      }]
   }

   Dodge {
      isA: PositiveFlag
      description : "Dodge increases your defense by 1 per point this turn, reduced by 1 each time you are attacked"

      resetAtStartOfTurn : true
      tickDown: OnAttacked

      countsAsOne : [DefenseDelta]
   }

   Unbalanced {
      isA: NegativeFlag
      description : "Unbalanced reduces your defense by 1 per point, reduced by 1 at the start of each turn"

      resetAtStartOfTurn : false
      tickDown: OnStartOfTurn
      countsAsNegativeOne : [DefenseDelta]
   }


   OnApproachAttack {
      isA: InternalFlag
      description : "OnApproachAttack"
      hidden : true
   }

   MovementGainDelta {
      isA: InternalFlag
      description : "Movement Gain Delta"
      hidden : true
   }

   ApCostDelta {
      isA: InternalFlag
      description : "AP Cost delta"
      hidden : true
   }

   StaminaCostDelta {
      isA: InternalFlag
      description : "Stamina Cost delta"
      hidden : true
   }

   AccuracyDelta {
      isA: InternalFlag
      description : "Accuracy delta"
      hidden : true
   }

   DefenseDelta {
      isA: InternalFlag
      description : "Defense delta"
      hidden : true
   }

   ArmorDelta {
      isA: InternalFlag
      description : "Armor delta"
      hidden : true
   }

   ApGainDelta {
      isA: InternalFlag
      description : "AP Gain Delta"
      hidden : true
   }

   ZoneOfControlRange {
      isA: InternalFlag
      description : "Zone of Control Range"
      hidden : true
   }

   EndOfTurnBlockGain {
      isA: InternalFlag
      description : "End of Turn Block Gain"
      hidden : true
   }

   EndOfTurnDamage {
      isA: InternalFlag
      description : "End of Turn Damage"
      hidden : true
      keyed : true
   }

   DamageReduction {
      isA: InternalFlag
      description : "Damage Reduction"
      hidden : true
      keyed : true
   }

   ExtraDamageTaken {
      isA: InternalFlag
      description : "Extra Damage Taken"
      hidden : true
      keyed : false
   }

   DamageBonus {
      isA: InternalFlag
      description: "Extra Damage Dealt"
      hidden : true
      keyed : false
   }

   DamageDealtReductionPercent {
      isA: InternalFlag
      description: "Damage Dealt Reduction Percent"
      hidden: true
   }

   DamageTakenIncreasePercent {
      isA: InternalFlag
      description: "Damage Dealt Reduction Percent"
      hidden: true
   }

   DamageAbsorption {
      isA: InternalFlag
      description : "Damage Absorption"
      hidden : true
      keyed : true
   }

   SightRangeDelta {
      isA: InternalFlag
      description: "Sight Range Delta"
      hidden: true
      keyed: false
   }
}