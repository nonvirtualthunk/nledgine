import glm
import options
import stb_image/read as stbi
import stb_image/write as stbw
import os
import times
import color
import hashes
import noto
import atomics


var imageID: Atomic[int]

type
  Image* = ref object
    id*: int
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

proc reloadImage*(img: Image) =
  if img.resourcePath.isSome:
    let path = img.resourcePath.get
    stbi.setFlipVerticallyOnLoad(true)
    var width, height, channels: int

    try:
      img.data = stbi.load(path, width, height, channels, stbi.Default)
      img.sentinel = false
      img.lastModified = getLastModificationTime(path)
    except:
      img.data = stbi.load("resources/images/unknown.png", width, height, channels, stbi.Default)
      img.sentinel = true

    if channels == 3:
      let tmpData = img.data
      img.data = createSharedU(byte, width * height * 4)
      for i in 0 ..< width * height:
        let srcO = i * 3
        let destO = i * 4
        cast[ptr uint8]((cast[uint](img.data) + (destO + 0).uint))[] = cast[ptr uint8]((cast[uint](tmpData) + (srcO + 0).uint))[]
        cast[ptr uint8]((cast[uint](img.data) + (destO + 1).uint))[] = cast[ptr uint8]((cast[uint](tmpData) + (srcO + 1).uint))[]
        cast[ptr uint8]((cast[uint](img.data) + (destO + 2).uint))[] = cast[ptr uint8]((cast[uint](tmpData) + (srcO + 2).uint))[]
        cast[ptr uint8]((cast[uint](img.data) + (destO + 3).uint))[] = 255
      channels = 4
      freeShared(tmpData)
    elif channels != 4:
      raise newException(ValueError, "Only 4 channel images are currently supported [" & path & "] : " & $channels)

    img.channels = channels
    img.dimensions = vec2i(width.int32, height.int32)

proc loadImage*(path: string): Image =
  result = new Image
  result.id = imageID.fetchAdd(1)+1
  result.resourcePath = some(path)
  result.resourcePathHash = path.hash
  result.revision = 1
  reloadImage(result)


proc createImage*(dimensions: Vec2i): Image =
  result = new Image
  result.id = imageID.fetchAdd(1)+1
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

proc copy*(src: Image) : Image =
  result = createImage(src.dimensions)
  copyMem(cast[pointer](result.data), cast[pointer](src.data), src.dimensions.x * src.dimensions.y * 4)

proc hash*(e: Image): int =
  # if e.resourcePath.isSome:
  #    e.resourcePathHash
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
    #    a.resourcePath == b.resourcePath
    # else:
    cast[int](a.data) == cast[int](b.data)

proc width*(a: Image): int = a.dimensions.x
proc height*(a: Image): int = a.dimensions.y

proc `[]`*(img: Image, x: int, y: int): ptr RGBA =
  let offset = y * img.dimensions.x * 4 + x * 4
  cast[ptr RGBA]((cast[uint](img.data) + offset.uint))

proc `[]`*(img: Image, i: int): ptr RGBA =
  let offset = i * 4
  cast[ptr RGBA]((cast[uint](img.data) + offset.uint))

proc `[]=`*(img: Image, x: int, y: int, v: RGBA) =
  let offset = y * img.dimensions.x * 4 + x * 4
  cast[ptr RGBA]((cast[uint](img.data) + offset.uint))[] = v

proc `[]`*(img: Image, x: int, y: int, q: int): float =
  let offset = y * img.dimensions.x * 4 + x * 4 + q
  cast[ptr uint8]((cast[uint](img.data) + offset.uint))[].float / 255.0f


proc recolor*(img: Image, fromRamp: ColorRamp, toRampIn: ColorRamp) =
  if fromRamp.colors.len == 0 or toRampIn.colors.len == 0:
    return

  let toRamp = if toRampIn.colors.len >= fromRamp.colors.len:
    toRampIn
  else:
    var extendedRamp = toRampIn
    extendedRamp.colors.setLen(fromRamp.colors.len)
    for i in toRampIn.colors.len ..< fromRamp.colors.len:
      extendedRamp.colors[i] = extendedRamp.colors[i - 1]
    extendedRamp

  var i = 0
  let limit = img.width * img.height * 4

  let dataAddr = cast[int](img.data)
  let fromRampU = fromRamp.asUint32s()
  let toRampU = toRamp.asUint32s()

  while i < limit:
    let srcPtr = cast[ptr uint32](dataAddr + i)
    let srcColor = srcPtr[]
    for ci in 0 ..< fromRampU.len:
      if srcColor == fromRampU[ci]:
        srcPtr[] = toRampU[ci]
        break
    i += 4

proc extractRamp*(img: Image, sx: int, sy: int) : ColorRamp =
  var x = sx
  while x < img.dimensions.x:
    let color = img[x, sy]
    if color[].ai > 0:
      result.colors.add(color[])
    else:
      break
    x.inc

proc copyFrom*(target: Image, src: Image, position: Vec2i) =
  if target.channels != src.channels:
    raise newException(ValueError, "copyFrom(...) on images with differing channel counts")

  if position.x < 0 or position.y < 0 or position.x + src.dimensions.x >= target.dimensions.x or position.y + src.dimensions.y >= target.dimensions.y:
    warn &"Trying to copy image at invalid positon ! {position} target image dimensions: {target.dimensions}"
  else:
    for y in 0 ..< src.dimensions.y:
      # for x in 0 ..< src.dimensions.x:
      #    # echo "Copying pixel [", x, ",", y, "] : ", src[x,y][]
      #    target[position.x + x, position.y + y][] = src[x,y][]
      let srcPointer = src[0, y]
      let targetPointer = target[position.x, position.y + y]
      copyMem(targetPointer, srcPointer, src.dimensions.x * 4)


## Returns true if the image on disk has been modified more recently than the image in memory
proc modifiedOnDisk*(img: Image): bool =
  if img.resourcePath.isSome:
    if fileExists(img.resourcePath.get) and getLastModificationTime(img.resourcePath.get) > img.lastModified:
      return true
  false


proc writeToFile*(img: Image, path: string) =
  stbw.writePNG(
    path,
    img.width,
    img.height,
    img.channels,
    img.data
  )