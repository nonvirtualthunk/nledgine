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

  Dandy {
    name: "Dandy"
    actions {
      Punch {
        effects: [[damage, 2]]
        weight: 3
      }
      Tackle {
        effects: [[damage, 1], [apply flag, slow, 1]]
        weight: 1
      }
    }
    xp: 2
    health: 4-6
  }
}
