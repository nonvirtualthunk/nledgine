Cards {
  Strike {
    name: "Strike"
    costs: [[energy,1]]
    effects: [[damage,6]]
  }

  Defend {
    name: "Defend"
    effectGroups: [
      {
        name: "Defend"
        costs: [[energy,1]]
        effects: [[block, 5]]
      },
      {
        name: "Move Left"
        costs: [[energy,1]]
        effects: [[move,left]]
      },
      {
        name: "Move Right"
        costs: [[energy,1]]
        effects: [[move,right]]
      },
    ]
  }

  FightDirty {
    name: "Fight Dirty"
    costs: [[energy, 1]]
    effects: [
      [damage, 8]
      [applyFlag, enemy, weak, 1]
      [move, back]
    ]
  }

  Bowshot {
    name: "Bowshot"
    costs: [[energy, 1]]
    effects: [[damage, 7, ranged]]
  }

  SweepingBlow {
    name: "Sweeping Blow"
    costs: [[energy, 2]]
    effects: [[damage, 5, enemies]]
  }

  Bastion {
    name: "Bastion"
    costs: [[energy, 2]]
    effects: [[block, 6], [block, 4, allies]]
  }
}