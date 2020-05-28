import glm
import options
import ../stb_image/read as stbi
import os
import times
import color
import hashes

type 
    Image* = ref object
        data* : ptr[uint8]
        channels* : int
        resourcePath* : Option[string]
        dimensions* : Vec2i
        lastModified* : Time
        sentinel* : bool
        revision* : int
        resourcePathHash : Hash


proc loadImage*(path : string) : Image =
    stbi.setFlipVerticallyOnLoad(true)               
    var width,height,channels:int        
    result = new Image
    result.data = stbi.load(path,width,height,channels,stbi.Default)        

    if channels != 4:
        raise newException(ValueError, "Only 4 channel images are currently supported [" & path & "]")

    result.channels = channels
    result.dimensions = vec2i(width.int32, height.int32)
    result.resourcePath = some(path)
    result.resourcePathHash = path.hash
    result.lastModified = getLastModificationTime(path)
    result.sentinel = false
    result.revision = 1

proc createImage*(dimensions : Vec2i) : Image =
    result = new Image
    result.data = createSharedU(uint8, dimensions.x * dimensions.y * 4)
    result.channels = 4
    result.dimensions = dimensions
    result.sentinel = false
    result.revision = 1

proc hash*(e : Image) : int =
    # if e.resourcePath.isSome:
    #     e.resourcePathHash
    # else:
    if e == nil:
        0
    else:
        cast[int](e.data).hash

proc `==`*(a : Image, b : Image) : bool =
    if a.isNil or b.isNil:
        a.isNil and b.isNil
    else:
        # if a.resourcePath.isSome:
        #     a.resourcePath == b.resourcePath
        # else:
        cast[int](a.data) == cast[int](b.data)


proc `[]`*(img : Image, x : int, y : int) : ptr RGBA =
    let offset = y * img.dimensions.x * 4 + x * 4
    cast[ptr RGBA]((cast[uint](img.data) + offset.uint))


proc copyFrom*(target : Image, src : Image, position : Vec2i) =
    if target.channels != src.channels:
        raise newException(ValueError, "copyFrom(...) on images with differing channel counts")
    for y in 0 ..< src.dimensions.y:
        # for x in 0 ..< src.dimensions.x:
        #     # echo "Copying pixel [", x, ",", y, "] : ", src[x,y][]
        #     target[position.x + x, position.y + y][] = src[x,y][]
        let srcPointer = src[0,y]
        let targetPointer = target[position.x,position.y + y]
        copyMem(targetPointer, srcPointer, src.dimensions.x * 4)