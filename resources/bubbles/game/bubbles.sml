Bubbles {
  Strike {
    name: "Strike"
    image: "bubbles/images/bubble/strike_horizontal.png"
    rarity: None
    maxNumber: 3
    color: Red
    onPopEffects: [attack(3)]
  }
  Defend {
    name: "Defend"
    image: "block.png"
    rarity: None
    maxNumber: 3
    color: Blue
    onPopEffects: [block(3)]
  }
  Bash {
    name: "Bash"
    image: "bubbles/images/bubble/bash.png"
    rarity: None
    maxNumber: 4
    color: Red
    modifiers: [Power(1)]
    onPopEffects: [[Mod, Enemy, Vulnerable, 4]]
  }
  Inflame {
    name: "Inflame"
    image: "bubbles/images/bubble/inflame.png"
    rarity: Uncommon
    maxNumber: 1
    color: Green
    secondaryColors: [Red]
    modifiers: [Exhaust]
    inPlayPlayerMods: [Strength(1)]
  }
  ChainBlock {
    name: "Chain Block"
    image: "bubbles/images/bubble/chain_block_overlay.png"
    rarity: Common
    maxNumber: 4
    color: Blue
    modifiers: [Chain]
    onPopEffects: [block(4)]
  }
  ParryAndThrust {
    name: "Parry and Thrust"
    image: "parry_thrust.png"
    rarity: Common
    maxNumber: 4
    color: Red
    secondaryColors: [Blue]
    modifiers: [Chain]
    onPopEffects: [attack(2), block(2)]
  }
  Footwork {
    name: "Footwork"
    image: "footwork.png"
    rarity: Uncommon
    maxNumber: 1
    color: Green
    secondaryColors: [Blue]
    modifiers: [Exhaust]
    inPlayPlayerMods: [Footwork(1)]
  }
  RecklessStrike {
    name: "Reckless Strike"
    image: "reckless_strike.png"
    rarity: Common
    maxNumber: 3
    color: Red
    modifiers: [Juggernaut]
    onPopEffects: [attack(6)]
    onFireEffects: [[Bubble, Wound, RandomMagazine]]
  }
  TwinStrike {
    name: "Twin Strike"
    image: "twin_strike.png"
    rarity: Common
    maxNumber: 4
    color: Red
    onPopEffects: [attack(6), attack(6)]
  }
  Stalwart {
    name: "Stalwart"
    image: "stalwart.png"
    rarity: Uncommon
    maxNumber: 9
    color: Blue
    modifiers: [Immovable]
    onPopEffects: [block(3)]
    onCollideEffects: [{
      effects: [block(1)]
      conditions: MatchingColor
    }]
  }



  Slime {
    name: "Slime"
    image: "slime.png"
    rarity: None
    maxNumber: 3
    color: Grey
    secondaryColors: Green
    modifiers: [Exchange, Exhaust]
  }

  Wound {
    name: "Wound"
    image: "wound.png"
    maxNumber: 2
    color: Grey
  }
}