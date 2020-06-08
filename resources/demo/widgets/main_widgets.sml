
widget : {
   background.image : ui/minimalistBorder.png
   x : 50
   y : 50
   width : 500
   height : 500
   children {
      child {
         background.image : ui/buttonBackground.png
         x : 10
         y : 10
         width : 0.5
         height : -20
      }

      rightChild {
         background.image : ui/buttonBackground.png
         x : "10 right of child"
         y : "0.1 from bottom right"
         width : expandToParent(10)
         height : 100
      }

      textChild {
         type : TextDisplay
         background.image : ui/minimalistBorder.png
         x : "10 right of child"
         y : 10
         padding : [2,2,0]
         text : "test text"
         fontSize : 16
         color : [0,0,0,1]
      }

      textChild2 {
         type : TextDisplay
         text : %(text2)
         fontSize : 16
         color : [0,0,0,1]

         x : 10 right of textChild
         y : 10
         width : expandToParent(10)
         background.image : ui/minimalistBorder.png
         padding : [2,2,0]
      }

      imageChild {
         type : ImageDisplay
         image : images/hammer.png
         x : "10 right of textChild"
         y : "10 below textChild2"
         padding : [4,4]
      }
   }

}