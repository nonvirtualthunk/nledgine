Enemies {
  Goblin {
    name: "Goblin"
    image: "bubbles/images/enemies/goblin.png"
    health: 18
    intents: [{
      effects: ["attack(7)"]
      duration: 8
    },{
      effects: ["attack(3)"]
      duration: 4
    },{
      effects: [[Mod, Enemy, Weak, 3], "block(2)"]
      duration: 4
    }]

  }

  Rat {
    name: "Rat"
    image: "bubbles/images/enemies/rat.png"
    health: 9
    intents: [{
      effects: ["attack(1)"]
      duration: 3
    },{
      effects: ["block(2)"]
      duration: 2
    },{
      effects: [[Mod, Enemy, Vulnerable, 5], "attack(2)"]
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

  Snake {
    name: Snake
    image: "bubbles/images/enemies/snake.png"
    health: 15
    intents: [{
      effects: [[Bubble, Poison, FireFromTop]]
      duration: 3
    }, {
      effects: ["attack(6)"]
      duration: 5
    }]
  }

  Rogue {
    name: Rogue
    image: "bubbles/images/enemies/rogue.png"
    health: 16
    intents: [{
      effects: [[Bubble, Bomb, FireFromTop]]
      duration: 3
    }, {
      effects: ["block(5)"]
      duration: 3
    }, {
      effects: ["attack(4)"]
      duration: 3
    }]
  }
}