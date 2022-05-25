Enemies {
  Goblin {
    name: "Goblin"
    image: "bubbles/images/enemies/goblin.png"
    health: 10
    intents: [{
      effects: ["attack(4)"]
      duration: 8
    },{
      effects: ["attack(2)"]
      duration: 4
    },{
      effects: [[Mod, Enemy, Weak, 3], "block(2)"]
      duration: 4
    }]

  }

  Rat {
    name: "Rat"
    image: "bubbles/images/enemies/rat.png"
    health: 6
    intents: [{
      effects: ["attack(1)"]
      duration: 3
    },{
      effects: ["block(1)"]
      duration: 2
    },{
      effects: ["attack(2)", [Mod, Enemy, Vulnerable, 5]]
      duration: 5
    }]
  }

  Slime {
    name: "Slime"
    image: "bubbles/images/enemies/slime.png"
    health: 8
    intents: [{
      effects: [[Bubble, Slime, FireFromTop]]
      duration: 1
    },{
      effects: [[Mod, Enemy, Weak, 4]]
      duration: 3
    },{
      effects: ["attack(3)"]
      duration: 6
    }]
  }
}