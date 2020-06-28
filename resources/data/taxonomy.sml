Taxonomy {
  UnknownThing : []
  Material : []
  Materials {
    Wood : Material
    Stone : Material
    Metal : Material

    Ironwood : Wood

    Hay : Material

  }

  LivingThing : []

  Species : []
  Specieses {
    Humanoid : Species
    Monstrous : Species

    Human : Humanoid
    MudMonster : Monstrous
    Slime : Monstrous
  }

  Item : []
  Items {
    RawMaterial : Item
    RefinedMaterial : Item

    Foodstuff : Item
    HumanFoodstuff : Foodstuff
    AnimalFoodstuff : Foodstuff

    Consumable : Item
    Potion : [Consumable]

    Tool : Item
    FineCuttingTool : Tool
    SturdyCuttingTool : Tool

    Log : RawMaterial
    Plank : RefinedMaterial

    IronwoodLog : Log
    IronwoodPlank : Plank

    HayBushel : [RawMaterial, AnimalFoodstuff]

    StaminaPotion : Potion

    Weapon : Item
    Axe : [Item, SturdyCuttingTool]

    Weapons {
      MeleeWeapon : Weapon

      BattleAxe: [MeleeWeapon, Axe]
      Sword: MeleeWeapon
      Longsword: Sword
      Shortsword: Sword

      Spear : MeleeWeapon
      Longspear : Spear
      Shortspear : Spear

      Scythe : [MeleeWeapon, Tool, SturdyCuttingTool]
    }
  }

  AttackType : []
  AttackTypes {
    PhysicalAttack : AttackType
    SlashingAttack : PhysicalAttack
    PiercingAttack : PhysicalAttack
    BludgeoningAttack : PhysicalAttack

    NaturalAttack : AttackType

    MeleeAttack : AttackType
    RangedAttack : AttackType
    ReachAttack : AttackType
  }

  Terrain : []
  Terrains {
    Flatland : Terrain
    Hills : Terrain
    Mountains : Terrain

    Plateaus : Hills
  }

  Vegetation : []
  Vegetations {
    Grass : Vegetation
    Forest : Vegetation
    DeciduousForest : Forest
    EvergreenForest : Forest
    Jungle : Forest
  }

  CharacterClass : []
  CharacterClasses {
    CombatClass : CharacterClass
    MeleeCombatClass : CombatClass
    RangedCombatClass : CombatClass
    MagicClass : CharacterClass
  }

  Action : []
  Actions {
    DoNothing : Action
    MoveAction : Action
    AttackAction : Action
    GatherAction : Action
    SwitchSelectedCharacterAction : Action
  }

  Sex : []
  Sexes {
    Ungendered : Sex
    Male : Sex
    Female : Sex
  }

  Reaction : []
  Reactions {
    Parry : Reaction
    Defend : Reaction
    Block : Reaction
    Counter : Reaction
    Dodge : Reaction
  }


  GameConcept : []
  GameConcepts {
    Accuracy : GameConcept
    Defense : GameConcept
    Armor : GameConcept
    MinimumRange : GameConcept
    MaximumRange : GameConcept
    SkillLevelUp : GameConcept
    Range : GameConcept
    Damage : GameConcept
    Attach : GameConcept
    SpecialAttack : GameConcept
    Attack : GameConcept
    Strike : GameConcept

    DrawPile : GameConcept
    DiscardPile : GameConcept
    ExhaustPile : GameConcept
    ExpendedPile : GameConcept
    Hand : GameConcept
    NotInDeck : GameConcept
  }

  ResourcePool : []
  ResourcePools {
    ActionPoints : ResourcePool
    StaminaPoints : ResourcePool
    ManaPoints : ResourcePool
  }

  DamageType : []
  DamageTypes {
    Physical : DamageType

    Piercing : Physical
    Bludgeoning : Physical
    Slashing : Physical
    Unknown : DamageType
  }

  BodyPart : []
  BodyParts {
    Gripping : BodyPart
    Thinking : BodyPart
    Appendage : BodyPart
    Dextrous : BodyPart

    Hand : Gripping
    Pseudopod : [Gripping, Dextrous, Appendage]
    Arm : [Dextrous, Appendage]
    Leg : Appendage
    Head : Thinking
  }

  CardType : []
  CardTypes {
    AttackCard : CardType
    SkillCard : CardType
    ItemCard : CardType
    SpellCard : CardType
    ActionCard : CardType
    MoveCard : CardType
    GatherCard : CardType
    DefenseCard : SkillCard
    StanceCard : SkillCard

    NaturalAttackCard : AttackCard

    Harvest : GatherCard
    Gather : GatherCard
    Move : MoveCard
    Slash : AttackCard

    SwiftStrike : AttackCard
    PiercingStab : AttackCard
    FlurryOfBlows : AttackCard
    SweepingLegStrike : AttackCard
    RingingBlow : AttackCard
    DoubleStrike : AttackCard
    ChargingStrike : AttackCard
    FlashingPoints : SkillCard

    Parry : DefenseCard
    Block : DefenseCard

    TurtleStance : StanceCard
    HedgehogStance : StanceCard


    MonsterCard : CardType
    StatusCard : CardType

    SlimeSmash : [MonsterCard, AttackCard]

    Slime : StatusCard
  }

  Skill : []
  Skills {
    AttackSkill : Skill
    DefenseSkill : Skill
    MoveSkill : Skill

    MeleeSkill : AttackSkill

    WeaponSkill : AttackSkill
    ArmorSkill : DefenseSkill

    SpearSkill : [WeaponSkill, MeleeSkill]
    SwordSkill : [WeaponSkill, MeleeSkill]
    AxeSkill : [WeaponSkill, MeleeSkill]
    ShieldSkill : [ArmorSkill, MeleeSkill]

    UnarmedSkill : [WeaponSkill, MeleeSkill]

    Parry : DefenseSkill
    Block : DefenseSkill
    Move : MoveSkill

    Gather : Skill
  }

  Perk : []
  Perks {
    UnknownPerk : Perk
    AddCard : Perk
    SpearProficiency : Perk
    SpearMastery : Perk
    CloseRangeSpearFighter : Perk
    MeleeFighter : Perk
  }


  Flag : []
  Flags {
    PositiveFlag : Flag
    NegativeFlag : Flag

    InternalFlag : Flag

    Harvester : Flag
    Miner : Flag

    Block : PositiveFlag
    Parry : PositiveFlag

    Tiring : NegativeFlag
    Slow : NegativeFlag

    Stunned : NegativeFlag
    Dazzled : NegativeFlag

    FlashingPoints : PositiveFlag

    Stance : PositiveFlag

    HedgehogStance : Stance
    TurtleStance : Stance


    ApCostDelta : InternalFlag
    ApGainDelta : InternalFlag
    StaminaCostDelta : InternalFlag
    DefenseDelta : InternalFlag
    AccuracyDelta : InternalFlag
    ArmorDelta : InternalFlag
    MovementGainDelta : InternalFlag
    BlockDelta : InternalFlag
    OnApproachAttack : InternalFlag
    ZoneOfControlRange : InternalFlag
  }

  Tag : []
  Tags {
    Tool : Tag

    Unplayable : Tag
    Expend : Tag
    Exhaust : Tag
    Plant : Tag
  }

  Rarity : []
  Rarities {
    Common : Rarity
    Uncommon : Rarity
    Rare : Rarity
    Epic : Rarity
  }
}