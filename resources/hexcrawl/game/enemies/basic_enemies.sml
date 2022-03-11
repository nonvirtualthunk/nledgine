Enemies {
  Slime {
    name: "Slime"
    actions {
      Slam {
        effects: [[damage, 5]]
        weight: 3
      }
      Weaken {
        effects: [[apply flag, weak, 1]]
        weight: 2
      }
    }
    xp: 4
    health: "5-7"
  }
}