YouLoseWidget {
  type: Widget

  x: centered
  y: centered
  width: 400
  height: 200
  background.draw: true

  children {
    Text {
      type: TextDisplay

      x: centered
      y: centered

      text: "You have perished"
      color: [100,10,5,255]

      background.draw: false
      fontSize: 28
    }
  }
}