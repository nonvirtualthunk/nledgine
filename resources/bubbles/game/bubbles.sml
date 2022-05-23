Bubbles {
  Strike {
    name: "Strike"
    maxNumber: 3
    color: Red
    onPopEffects: [attack(3)]
  }
  Defend {
    name: "Defend"
    maxNumber: 3
    color: Blue
    onPopEffects: [block(3)]
  }
  Bash {
    name: "Bash"
    maxNumber: 4
    color: Red
    modifiers: [Power(2)]
    onPopEffects: [[Enemy, Vulnerable, 4]]
  }
  Inflame {
    name: "Inflame"
    maxNumber: 1
    color: Green
    modifiers: [Chromophilic]
    inPlayPlayerMods: [Strength(1)]
  }
  ChainBlock {
    name: "Chain Block"
    maxNumber: 4
    color: Blue
    modifiers: [Chain]
  }
}