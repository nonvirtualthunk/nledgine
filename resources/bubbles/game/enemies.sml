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
      effects: [[Enemy, Weak, 3], "block(2)"]
      duration: 4
    }]

  }
}