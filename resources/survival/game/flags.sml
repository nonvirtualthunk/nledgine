Flags {
  # General characteristics of objects
  Sharp {
    description: "Has an edge that could be used to cut or carve other items"
  }
  Pointed {
    description: "Comes to a point that could puncture or scrape"
  }
  Hard {
    description: "Solid and rigid, resists deformation"
  }
  Sturdy {
    description: "Strong and durable enough to withstand rough use"
  }
  Flat {
    description: "Shaped into an uninterrupted surface"
  }
  Pole {
    description: "Long straight object, suitable for tools and construction"
  }
  Fine {
    description: "Delicate, suitable for small or intricate uses"
  }
  Compostable {
    description: "Organic matter that could be composted and broken down"
  }
  Tinder {
    description: "Easily flammable material that can help start a larger fire"
    countsAs: [Fuel, Inflammable]
  }
  Seed {
    description: "The seed of a plant that can grow into a new mature one"
    boolean: true
  }
  Stone {
    description: "Made of a hard mineral"
    boolean: true
  }
  Metal {
    description: "Made of a hard metallic mineral"
    boolean: true
  }
  Liquid {
    description: "A liquid substance"
    boolean: true
  }
  Vegetable {
    description: "The body of a plant"
    boolean: true
  }
  Fruit {
    description: "The tasty container for the seeds of a plant"
    boolean: true
  }
  Meat {
    description: "The body of an animal"
    boolean: true
    countsAs: AnimalProduct
  }
  AnimalProduct {
    description: "A part or product of an animal"
    boolean: true
    countsAs: NonVegan
  }
  NonVegan {
    description: "Has in some way been derived from an animal"
    boolean: true
  }
  Root {
    description: "The water absorbing root of a plant"
    boolean: true
  }
  Wood {
    description: "Made of the hard material from the trunk or branch of a tree"
    boolean: true
  }
  Powder {
    description: "A fine substance made of small particles"
    boolean: true
  }
  Edible {
    description: "Can be eaten by living creatures"
  }
  Crafting {
    description: "Surface and tools that make crafting more complex items possible"
  }
  HeatSource {
    description: "A source of heat"
  }
  Inflammable {
    description: "Can be ignited into a long burning flame"
    countsAs: Fuel
  }
  Fuel {
    description: "A source of fuel for combustion"
  }
  Cordage {
    description: "Long straight, flexible material suitable for weaving or braiding"
  }
  Tannin {
    description: "A chemical that can be used in the tanning of leather"
  }
  Bait {
    description: "Something a fish might want to eat"
  }
  Soil {
    description: "Earth that plants could grow in"
  }
  Tool {
    description: "An item that can assist in gathering or crafting"
  }
  Weapon {
    description: "An item that can be used in combat"
  }
  Axe {
    description: "A bladed tool or weapon used for chopping"
  }
  Tongs {
    description: "A tool that can grip and hold things from a distance to keep your hands safe"
  }
  CookingImplement {
    description: "A tool used for cooking and preparing food"
  }
  Fire {
    description: "A light in the dark, a friend in the cold places of the world"
  }
  Cooked {
    description: "Food that has been prepared and heated into a more pleasntly edible form"
  }
  All {
    description: "Special flag indicating that all flags should be included in some consideration"
  }
  Binding {
    description: "An item that can bind two things together"
  }
  Ash {
    description: "The remnants of a burned thing"
  }
  Roasted {
    description: "Roasted in a fire"
  }
  AxeHead {
    description: "Sturdy blade suitable for attaching to a handle to make a rough cutting tool"
  }
  PickaxeHead {
    description: "A sturdy spike, suitable for attaching to a handle to make a mining tool"
  }
  Pickaxe {
    description: "A sturdy spike mounted on a handle, useful for mining and breaking hard substances"
  }
  Material {
    description: "A raw material used to create more complex items"
  }
  Debris {
    description: "Broken remains of something more useful"
  }
  Bowl {
    description: "A concave container for holding objects or liquids"
  }
  Grass {
    description: "Grass"
  }
  Water {
    description: "Water, the foundation of life"
  }
  Corpse {
    description: "A mortal coil bereft of its animating force"
    countsAs: AnimalProduct
  }
  Needle {
    description: "A strong, sharp, thin tool that can pull a binding through other materials"
  }
}