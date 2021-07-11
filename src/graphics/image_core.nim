import glm
import options
import ../stb_image/read as stbi
import ../stb_image/write as stbw
import os
import times
import color
import hashes
import noto

type
   Image* = ref object
      data*: ptr[uint8]
      channels*: int
      resourcePath*: Option[string]
      dimensions*: Vec2i
      lastModified*: Time
      sentinel*: bool
      revision*: int
      resourcePathHash: Hash

proc `$`*(img: Image): string =
   if img.resourcePath.isSome:
      "ImageFrom(" & img.resourcePath.get & ")"
   else:
      "Image(" & $cast[uint](img.data) & ")"

proc loadImage*(path: string): Image =
   stbi.setFlipVerticallyOnLoad(true)
   var width, height, channels: int
   result = new Image
   try:
      result.data = stbi.load(path, width, height, channels, stbi.Default)
      result.sentinel = false
      result.lastModified = getLastModificationTime(path)
   except:
      result.data = stbi.load("resources/images/unknown.png", width, height, channels, stbi.Default)
      result.sentinel = true

   if channels != 4:
      raise newException(ValueError, "Only 4 channel images are currently supported [" & path & "]")

   result.channels = channels
   result.dimensions = vec2i(width.int32, height.int32)
   result.resourcePath = some(path)
   result.resourcePathHash = path.hash

   result.revision = 1

proc createImage*(dimensions: Vec2i): Image =
   result = new Image
   result.data = createSharedU(uint8, dimensions.x * dimensions.y * 4)
   result.channels = 4
   result.dimensions = dimensions
   result.sentinel = false
   result.revision = 1

proc createImage*(data: ptr uint8, dimensions: Vec2i, flipY: bool = false): Image =
   result = createImage(dimensions)
   if flipY:
      for y in 0 ..< dimensions.y:
         let srcPointer = cast[pointer](cast[uint](data) + (y * dimensions.x * 4).uint)
         let destPointer = cast[pointer](cast[uint](result.data) + ((dimensions.y - y - 1) * dimensions.x * 4).uint)
         copyMem(destPointer, srcPointer, dimensions.x * 4)
   else:
      copyMem(result.data, data, dimensions.x * dimensions.y * 4)

proc createImage*(data: seq[uint8], dimensions: Vec2i, flipY: bool = false): Image =
   createImage(data[0].unsafeAddr, dimensions, flipY)


proc hash*(e: Image): int =
   # if e.resourcePath.isSome:
   #     e.resourcePathHash
   # else:
   if e == nil:
      0
   else:
      cast[int](e.data).hash

proc `==`*(a: Image, b: Image): bool =
   if a.isNil or b.isNil:
      a.isNil and b.isNil
   else:
      # if a.resourcePath.isSome:
      #     a.resourcePath == b.resourcePath
      # else:
      cast[int](a.data) == cast[int](b.data)

proc width*(a: Image): int = a.dimensions.x
proc height*(a: Image): int = a.dimensions.y

proc `[]`*(img: Image, x: int, y: int): ptr RGBA =
   let offset = y * img.dimensions.x * 4 + x * 4
   cast[ptr RGBA]((cast[uint](img.data) + offset.uint))

proc `[]=`*(img: Image, x: int, y: int, v: RGBA) =
   let offset = y * img.dimensions.x * 4 + x * 4
   cast[ptr RGBA]((cast[uint](img.data) + offset.uint))[] = v

proc `[]`*(img: Image, x: int, y: int, q: int): float =
   let offset = y * img.dimensions.x * 4 + x * 4 + q
   cast[ptr uint8]((cast[uint](img.data) + offset.uint))[].float / 255.0f


proc copyFrom*(target: Image, src: Image, position: Vec2i) =
   if target.channels != src.channels:
      raise newException(ValueError, "copyFrom(...) on images with differing channel counts")

   if position.x < 0 or position.y < 0 or position.x + src.dimensions.x >= target.dimensions.x or position.y + src.dimensions.y >= target.dimensions.y:
      warn &"Trying to copy image at invalid positon ! {position} target image dimensions: {target.dimensions}"
   else:
      for y in 0 ..< src.dimensions.y:
         # for x in 0 ..< src.dimensions.x:
         #     # echo "Copying pixel [", x, ",", y, "] : ", src[x,y][]
         #     target[position.x + x, position.y + y][] = src[x,y][]
         let srcPointer = src[0, y]
         let targetPointer = target[position.x, position.y + y]
         copyMem(targetPointer, srcPointer, src.dimensions.x * 4)


proc writeToFile*(img: Image, path: string) =
  stbw.writePNG(
     path,
     img.width,
     img.height,
     img.channels,
     img.data
  )