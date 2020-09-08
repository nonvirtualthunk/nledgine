Terrains {
   Flatland: {
      fertility : 0
      cover : 0
      elevation : 0
      moveCost : 1

      graphics {
         default : {
            textures: {
               basePath: "ax4/images/zeshioModified/03 Dirt/01 Solid Tiles/"
               primary: "PixelHex_zeshio_tile-032.png"
               variantChance: 0.33
               variants: [
                  "PixelHex_zeshio_tile-030.png",
                  "PixelHex_zeshio_tile-031.png"
               ]
            }
         }
      }
   }

   Hills: {
      fertility : 0
      cover : 0
      elevation : 1
      moveCost : 2
      graphics {
         default : {
            textures: {
               basePath: "ax4/images/zeshioModified/05 Mountains/01 Solid Tiles/"
               primary: "PixelHex_zeshio_tile-168.png"
            }
         }
      }
   }

   Mountains: {
      fertility : -1
      cover : 0
      elevation : 2
      moveCost : 3

      graphics {
         default : {
            textures : {
               basePath: "ax4/images/zeshioModified/05 Mountains/01 Solid Tiles/"
               primary: "PixelHex_zeshio_tile-165.png"
               variantChance : 0.5
               variants: [
                  "PixelHex_zeshio_tile-167.png"
                  "PixelHex_zeshio_tile-1191.png"
                  "PixelHex_zeshio_tile-1193.png"
               ]
            }
         }
      }
   }

   Plateaus : {
      fertility : 0
      cover : 0
      elevation : 1
      moveCost : 2
      kind : plateaus
   }
}