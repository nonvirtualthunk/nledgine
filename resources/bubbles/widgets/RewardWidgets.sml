RewardWidget {
  width : 90%
  height : 90%
  x: centered
  y: centered
  z: 200
  background.image : "ui/fancyBackground.png"
  background.pixelScale : 2
  showing: "%(rewards.showing)"
  //   consumeMouseButtonEvents: true

  children {
    RewardTitle {
      type : TextDisplay

      text : "Choose Reward"
      background.draw : false
      fontSize : 20
      horizontalAlignment : center
      width : 90%
      x : centered
      y : 4
    }

    RewardOptions {
      type: Div
      x: 5
      y: 30
      width: -10
      height: -90
      background.draw : false
    }
  }
}

RewardOptionWidget {
  type: Div
  width : 100%
  height : 200
  background.draw : true
  background.image : "ui/fancyBackground.png"

  children {
    OptionName {
      type: TextDisplay
      y: 5
      fontSize: 20
      text: "%(name)"
      width: 100%
      height: intrinsic
      horizontalAlignment: center
      mulitLine: true
    }
    BubbleModifierDescription {
      type: TextDisplay
      y: 2 below OptionName
      fontSize: 16
      text: "%(bubbleModifiers)"
      color: [45,45,45,255]
      width: 100%
      horizontalAlignment: center
      mulitLine: true
    }
    EffectsDescription {
      type: TextDisplay
      y: 2 below BubbleModifierDescription
      fontSize: 16
      color: [25,25,25,255]
      text: "%(effectsDescription)"
      width: 100%
      horizontalAlignment: center
      mulitLine: true
    }
    ImageDiv {
      type: Div
      x: 0
      y: centered
      children {
        OptionImage {
          type: ImageDisplay
          imageLayers: "%(imageLayers)"
          width: intrinsic
          height: intrinsic
          scale: scale(2)
          y: centered
          x: centered
        }
        NumberImage {
          type: ImageDisplay
          image: "%(numeral)"
          color: [255,255,255,255]
          scale: scale(4)
          x: centered
          y: centered
          z: 2
        }
      }
    }
  }
}