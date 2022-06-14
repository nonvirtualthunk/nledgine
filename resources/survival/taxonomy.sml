Taxonomy {
  UnknownThing: []


  GameConcept: []
  GameConcepts {
    Vital: GameConcept
    Health : Vital
    Stamina : Vital
    Hydration : Vital
    Hunger: Vital
    Sanity: Vital
  }

  Building: []
  Burrow: [Building]

  DamageType: []
  DamageTypes {
    BiologicalNecessity: DamageType
    Hunger: BiologicalNecessity
    Thirst: BiologicalNecessity

    Physical: DamageType
    Bludgeoning: Physical
    Piercing: Physical
    Slashing: Physical

    Elemental: DamageType
    Fire: Elemental
    Cold: Elemental
    Acid: Elemental
  }

  BodyCapability: []
  BodyCapabilities {
    Manipulate: BodyCapability
    Move: BodyCapability
    Think: BodyCapability

  }

  EquipmentLayer: []
  EquipmentLayers {
    Clothing: EquipmentLayer
    Armor: EquipmentLayer
    Trinkets: EquipmentLayer
  }

  EquipmentGrouping: []
  EquipmentGroupings {
    Head: EquipmentGrouping
    Neck: EquipmentGrouping
    Body: EquipmentGrouping
    Hands: EquipmentGrouping
    Legs: EquipmentGrouping
    Feet: EquipmentGrouping
  }
}

TaxonomySources : [
  survival/game/tile_kinds.sml
  survival/game/actions.sml
  survival/game/items.sml
  survival/game/growth_stages.sml
  survival/game/plant_kinds.sml
  survival/game/flags.sml
  survival/game/body_parts.sml
  survival/game/equipment_slots.sml
  survival/game/recipe_templates.sml
  survival/game/recipes.sml
  [survival/game/creatures.sml, Creatures, Items]
  survival/game/burrows.sml
  survival/game/attacks.sml
]