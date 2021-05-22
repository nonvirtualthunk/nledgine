VitalsWidget {
  x : 20
  y : 20
  width : 500
  height : 400
  background.draw : false

  children {
    HealthDisplay {
      type : TextDisplay

      text : "†GameConcepts.Health %(player.health) / %(player.maxHealth)"
      background.draw : false
      font: "ChevyRayThicket.ttf"
      fontSize : 20
      horizontalAlignment : left
    }

  }

}