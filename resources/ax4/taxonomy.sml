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

   MonsterClass : []
   MonsterClasses {
      
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

      MeleeWeapon : Weapon

      BattleAxe: [MeleeWeapon, Axe]
      Sword: MeleeWeapon

      Spear : MeleeWeapon

      Shield : Item

      Scythe : [MeleeWeapon, Tool, SturdyCuttingTool]
   }

   AttackType : []
   AttackTypes {
      PhysicalAttack : AttackType

      NaturalAttack : AttackType

      MeleeAttack : AttackType
      RangedAttack : AttackType
      ReachAttack : AttackType

      SimpleNaturalAttack : [MeleeAttack, NaturalAttack, PhysicalAttack]

      ShieldBash : [PhysicalAttack, MeleeAttack]
   }

   Terrain : []
   Terrains {
      
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
      Fighter : CharacterClass
      Rogue : CharacterClass

      FighterSubclass : CharacterClass
      FighterSpecialization : CharacterClass
      RogueSubclass : CharacterClass
      RogueSpecialization : CharacterClass

      Barbarian : FighterSubclass
      Tactician : FighterSubclass
      Assassin : [FighterSubclass, RogueSubclass]

      General : FighterSpecialization
      Berserker : FighterSpecialization
      GiantSlayer : FighterSpecialization
      Guardian : FighterSpecialization

      Thief : RogueSubclass
      Hunter : RogueSubclass

      Tinkerer : RogueSpecialization
      Alchemist : RogueSpecialization
      Trapper : RogueSpecialization
      Ranger : RogueSpecialization


      Movement : CharacterClass
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
      Move : GameConcept

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
      Chemical : DamageType
      Elemental : DamageType

      Piercing : Physical
      Bludgeoning : Physical
      Slashing : Physical

      Poison : Chemical

      Fire : Elemental
      Ice : Elemental

      WeaponDamageType: DamageType

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

   Scenario : []

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

      FighterCard : CardType
      RogueCard : CardType

      NaturalAttackCard : AttackCard

      BlockCard: SkillCard

      MonsterCard : CardType
      StatusCard : CardType
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
      Starter : Rarity
      Item : Rarity
      Common : Rarity
      Uncommon : Rarity
      Rare : Rarity
      Epic : Rarity
   }
}

TaxonomySources : [
   ax4/game/base_cards.sml, 
   ax4/game/status_cards.sml, 
   ax4/game/flags.sml, 
   ax4/game/monsters.sml, 
   ax4/game/terrains.sml,
   ax4/game/weapons.sml,
   ax4/game/armor.sml,
   ax4/game/scenarios.sml,
]