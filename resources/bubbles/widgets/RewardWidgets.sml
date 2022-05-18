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
      text: "%(name)\n %(descriptors)"
      width: 100%
      height: 40
      horizontalAlignment: center
      mulitLine: true
    }
    ImageDiv {
      type: Div
      width: 100%
      height: expandToParent
      y: 0 below OptionName
      children {
        OptionImage {
          type: ImageDisplay
          image: "%(image)"
          color: "%(imageColor)"
          width: intrinsic
          height: intrinsic
          scale: scale(2)
          y: centered
          x: centered
        }
        OptionOverlayImage {
          type: ImageDisplay
          showing: "%(imageOverlayShowing)"
          image: "%(imageOverlay)"
          color: "%(imageOverlayColor)"
          width: intrinsic
          height: intrinsic
          scale: scale(2)
          x: centered
          y: centered
          z: 1
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