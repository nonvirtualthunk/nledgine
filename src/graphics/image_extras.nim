import image_core
import resources
import config/config_core
import glm
import prelude
import arxregex
import strutils
import noto

type
  ImageRefKinds = enum
    Sentinel
    ImageObj
    Path

  ImageRef* = object
    case kind: ImageRefKinds
    of ImageObj:
      img: Image
    of Path:
      path: string
    of Sentinel:
      discard

  Animation* = object
    image*: ImageRef
    frameCount*: int
    frameDuration*: UnitOfTime


  ImageLikeKind* {.pure.} = enum
    Sentinel
    Image
    Animation

  ImageLike* = object
    case kind: ImageLikeKind
    of ImageLikeKind.Sentinel: discard
    of ImageLikeKind.Image: image: ImageRef
    of ImageLikeKind.Animation: animation: Animation

var sentinelImage {.threadvar.}: Image

proc `==`*(a, b: ImageRef): bool =
  a.kind == b.kind and
  (case a.kind:
    of ImageObj: a.img == b.img
    of Path: a.path == b.path
    of Sentinel: true)

proc imageRef*(img: Image): ImageRef = ImageRef(kind: ImageObj, img: img)
proc imageRef*(img: string): ImageRef =
  if img != "":
    ImageRef(kind: Path, path: img)
  else:
    ImageRef(kind: Sentinel)

proc preload*(img: ImageRef) =
  case img.kind:
  of ImageRefKinds.Path: preloadImage(img.path)
  else: discard

proc `$`*(img: ImageRef): string =
  case img.kind:
  of ImageRefKinds.Sentinel: "SentinelImage"
  of ImageRefKinds.ImageObj: $img.img
  of ImageRefKinds.Path: "ImageAt(" & img.path & ")"

proc isNil*(img: ImageRef): bool = false

proc asImage*(il: ImageRef): Image =
  case il.kind:
  of ImageRefKinds.ImageObj:
    il.img
  of ImageRefKinds.Path:
    image(il.path)
  of ImageRefKinds.Sentinel:
    if sentinelImage == nil:
      sentinelImage = createImage(vec2i(1, 1))
      sentinelImage.sentinel = true
    sentinelImage

proc resolve*(il: var ImageRef): Image =
  case il.kind:
  of ImageRefKinds.ImageObj:
    il.img
  of ImageRefKinds.Path:
    il = imageRef(image(il.path))
    il.asImage
  of ImageRefKinds.Sentinel:
    if sentinelImage == nil:
      sentinelImage = createImage(vec2i(1, 1))
      sentinelImage.sentinel = true
    sentinelImage

proc asImage*(il: var ImageRef): Image =
  il.resolve()


proc readFromConfig*(cv: ConfigValue, img: var ImageRef) =
  if cv.nonEmpty:
    img = imageRef(cv.asStr)

proc readFromConfig*(cv: ConfigValue, img: var Image) =
  if cv.nonEmpty:
    img = image(cv.asStr)


const timeRegex = "([0-9.]+)\\s?([a-z]+)".re
proc readFromConfig*(cv: ConfigValue, anim: var Animation) =
  if cv.nonEmpty:
    cv["image"].readInto(anim.image)
    cv["frameCount"].readInto(anim.frameCount)
    let durcv = cv["frameDuration"]
    if durcv.isStr:
      matcher(durcv.asStr):
        extractMatches(timeRegex, amountStr, unit):
          let amount = amountStr.parseFloat
          case unit.toLowerAscii:
            of "s", "second", "seconds": anim.frameDuration = amount.seconds
            else: warn &"Unknown units for duration: {unit}"
        warn &"Unknown format for frame duration: {durcv}"
    else:
      warn &"Unknown format for frame duration: {durcv}"




proc readFromConfig*(cv: ConfigValue, img: var ImageLike) =
  if cv.isStr:
    img = ImageLike(kind: ImageLikeKind.Image, image: readInto(cv, ImageRef))
  else:
    if cv.hasField("frameCount"):
      img = ImageLike(kind: ImageLikeKind.Animation, animation: readInto(cv, Animation))
    else:
      img = ImageLike(kind: ImageLikeKind.Image, image: readInto(cv, ImageRef))


converter toImage*(il: var ImageRef): Image =
  asImage(il)

converter toImageRef*(img: Image): ImageRef = ImageRef(kind: ImageObj, img: img)
converter toImageRef*(img: string): ImageRef = ImageRef(kind: Path, path: img)

proc isEmpty*(img: ImageRef): bool = img.kind == ImageRefKinds.Sentinel
proc isSentinel*(img: ImageRef): bool = img.kind == ImageRefKinds.Sentinel
