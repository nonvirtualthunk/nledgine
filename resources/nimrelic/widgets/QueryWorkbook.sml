WorkbookWidget {
   width : 100%
   height: 100%
   background.draw: true

   children {
      queryInput : {
         type: TextInput

         width: 100%
         height: 150

         #textData : "SELECT count(*) FROM NrqlParser SINCE 10 minute ago TIMESERIES 1 minute"
         fontSize : 20

         background.image: "ui/singlePixelBorderDark.png"
         background.color: [255,255,255,255]
         color : [200,200,200,255]
         font : "Consolas.ttf"

         padding : [5,5]
      }

      resultsArea : {
         width : 100%
         height: -150
         y : "0 below queryInput"

         background.draw: true
         background.color: [255,255,255,255]
         background.image: "ui/singlePixelBorderDark.png"
         color : [200,200,200,255]

         children {
            listResults: {
               type: ListWidget

               width : 100%
               height : 100%

               horizontal: true
               background.draw: false
               listItemArchetype: QueryWorkbook.ListResultColumn
               listItemBinding: "results.columns -> column"
               gapSize: -1

               selectable: false
               showing: %(active.grid)
            }

            errorResult: {
               type : TextDisplay

               width: 100%
               height: 100%
               
               text : "Error: %(error.message)"
               font : "Consolas.ttf"
               color : [250,200,200,255]
               fontSize: 18
               padding: [5,5]
               showing : %(active.error)
            }

            chartResult: {
               type: ChartDisplay

               width: 100%
               height: 100%

               chartBackgroundColor: [35,35,35,255]

               showing: %(active.chart)
            }
         }
      }
   }
}

ListResultColumn {
   type : Widget

   width : wrapContent
   height : 100%
   background.draw: true
   background.image: "ui/singlePixelBorderDark.png"
   background.color: [255,255,255,255]

   children {
      heading {
         type: TextDisplay
         background.draw: false
         text: "%(column.heading)"

         fontSize : 20
         font : "Consolas.ttf"
         color : [210,210,210,255]

         padding : [2,2]

         
      }

      values {
         type: ListWidget

         width : wrapContent
         height : wrapContent
         background.draw: false

         y : "10 below heading"

         horizontal: false
         listItemArchetype: QueryWorkbook.ResultCell
         listItemBinding: "column.values -> value"

         selectable: false
      }
   }
}

ResultCell {
   type : TextDisplay

   maxWidth : 600

   background.draw: false
   text : %(value)

   fontSize : 14
   font : "Consolas.ttf"
   color : [210,210,210,255]

   padding : [5,0]
}