Vegetations {
   Grass {
      layer : 0
      cover : 0
      moveCost : 0
      graphics {
         default {
            replaces : true
            textures {
               basePath: "ax4/images/zeshioModified/01 Grass/01 Solid Tiles/"
               primary: "PixelHex_zeshio_tile-001.png"
               variantChance: 0.3
               variants: [
                  "PixelHex_zeshio_tile-002.png",
                  "PixelHex_zeshio_tile-003.png",
                  "PixelHex_zeshio_tile-004.png",
                  "PixelHex_zeshio_tile-005.png",
                  "PixelHex_zeshio_tile-006.png"
               ]
            }
         }
         hills {
            replaces : true
            textures: {
               basePath: "ax4/images/zeshioModified/01 Grass/03 Hills/"
               primary: "PixelHex_zeshio_tile-020.png"
               variantChance: 0.2
               variants: [
                  "PixelHex_zeshio_tile-019.png",
                  "PixelHex_zeshio_tile-021.png",
                  "PixelHex_zeshio_tile-022.png"
               ]
            }
         }
      }
   }

   Forest : {
      layer : 2
      cover : 2
      moveCost : 1
      graphics {
         default {
            textures: {
               basePath: "ax4/images/zeshioModified/16 Trees/"
               primary: "PixelHex_zeshio_tile-1197.png"
               variantChance: 0.3
               variants: [
                  "PixelHex_zeshio_tile-1196.png",
                  "PixelHex_zeshio_tile-1195.png",
                  "PixelHex_zeshio_tile-1198.png",
                  "PixelHex_zeshio_tile-1204.png",
                  "PixelHex_zeshio_tile-1206.png",
               ]
            }
         }
         hills {
            textures : {
               basePath: "ax4/images/zeshioModified/16 Trees/"
               primary: "PixelHex_zeshio_tile-1203.png"
               variantChance: 0.3
               variants: [
                  "PixelHex_zeshio_tile-1204.png",
                  "PixelHex_zeshio_tile-1195.png"
               ]
            }
         }
      }
   }
}