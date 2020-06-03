import images
import resources
import config
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


proc imageLike*(img : Image) : ImageLike = ImageLike(kind : ImageRef, img : img)
proc imageLike*(img : string) : ImageLike = ImageLike(kind : Path, path : img)

proc asImage*(il : ImageLike) : Image =
    case il.kind:
    of ImageLikeKinds.ImageRef: 
        il.img
    of ImageLikeKinds.Path: 
        image(il.path)
    of ImageLikeKinds.Sentinel:
        createImage(vec2i(1,1))

proc readFromConfig*(cv : ConfigValue, img : var ImageLike) =
    img = imageLike(cv.asStr)

converter toImage* (il : ImageLike) : Image =
    asImage(il)

converter toImageLike*(img : Image) : ImageLike = ImageLike(kind : ImageRef, img : img)
converter toImageLike*(img : string) : ImageLike = ImageLike(kind : Path, path : img)