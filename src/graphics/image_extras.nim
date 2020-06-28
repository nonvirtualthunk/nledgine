import images
import resources
import config/config_core
import glm

type
    ImageLikeKinds = enum
        Sentinel
        ImageRef
        Path
    Imagelike* = object
        case kind: ImageLikeKinds
        of ImageRef: img : Image
        of Path : path : string
        of Sentinel : discard


proc `==`*(a,b : ImageLike) : bool =
    a.kind == b.kind and 
    (case a.kind:
        of ImageRef: a.img == b.img
        of Path: a.path == b.path
        of Sentinel: true)

proc imageLike*(img : Image) : ImageLike = ImageLike(kind : ImageRef, img : img)
proc imageLike*(img : string) : ImageLike = 
    if img != "":
        ImageLike(kind : Path, path : img)
    else:
        ImageLike(kind: Sentinel)

proc `$`*(img : ImageLike) : string = 
    case img.kind:
    of ImageLikeKinds.Sentinel: "SentinelImage"
    of ImageLikeKinds.ImageRef: $img.img
    of ImageLikeKinds.Path: "ImageAt(" & img.path & ")"

proc isNil*(img : ImageLike) : bool = false

proc asImage*(il : ImageLike) : Image =
    case il.kind:
    of ImageLikeKinds.ImageRef: 
        il.img
    of ImageLikeKinds.Path: 
        image(il.path)
    of ImageLikeKinds.Sentinel:
        createImage(vec2i(1,1))

proc readFromConfig*(cv : ConfigValue, img : var ImageLike) =
    if cv.nonEmpty:
        img = imageLike(cv.asStr)

converter toImage* (il : ImageLike) : Image =
    asImage(il)

converter toImageLike*(img : Image) : ImageLike = ImageLike(kind : ImageRef, img : img)
converter toImageLike*(img : string) : ImageLike = ImageLike(kind : Path, path : img)

proc isEmpty*(img : ImageLike) : bool = img.kind == ImageLikeKinds.Sentinel
proc isSentinel*(img : ImageLike) : bool = img.kind == ImageLikeKinds.Sentinel
