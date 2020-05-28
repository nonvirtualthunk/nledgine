import images
import glm
import ../arxmath
import tables
import ../prelude
import sequtils
import sugar
import math
import options
import core
import atomics
import nimgl/opengl


type 
    ImageData = object
        location : Vec2i
        revision : int
    TextureBlock* = ref object of Texture
        id : TextureID
        image : Image
        openRects : seq[Recti]
        imageData : Table[Image, ImageData]
        imageTexCoords : Table[Image, ref array[4, Vec2f]]
        borderWidth : int
        magFilter : GLenum
        minFilter : GLenum
        internalFormat : GLenum
        dataFormat : GLenum

method textureInfo*(tb : TextureBlock) : TextureInfo =
    if tb.id == 0:
        tb.id = core.textureID.fetchAdd(1)+1
    result = TextureInfo(
        id : tb.id,
        data : tb.image.data,
        len : tb.image.dimensions.x * tb.image.dimensions.y * tb.image.channels,
        magFilter : tb.magFilter,
        minFilter : tb.minFilter,
        internalFormat : tb.internalFormat,
        dataFormat : tb.dataFormat,
        revision : tb.image.revision,
        width : tb.image.dimensions.x,
        height : tb.image.dimensions.y
    )

proc newTextureBlock*(size : int = 2048, borderWidth : int = 1, gammaCorrection : bool = false) : TextureBlock =
    let internalFormat = if gammaCorrection: GL_SRGB_ALPHA
                         else: GL_RGBA
    TextureBlock(
        image : images.createImage(vec2i(size, size)),
        openRects : @[Recti(position : vec2(borderWidth,borderWidth), dimensions : vec2(size - borderWidth * 2, size - borderWidth * 2) )],
        borderWidth : borderWidth,
        minFilter : GL_NEAREST,
        magFilter : GL_NEAREST,
        internalFormat : internalFormat,
        dataFormat : GL_RGBA,
        
    )

proc toTexCoords(tb : TextureBlock, rect : Recti) : ref array[4, Vec2f] =
    let wf = tb.image.dimensions.x.float
    let hf = tb.image.dimensions.y.float
    let lowX = rect.x.float / wf
    let highX = (rect.x + rect.width).float / wf
    let lowY = rect.y.float / hf
    let highY = (rect.y + rect.height).float / hf

    result = new array[4, Vec2f]
    result[] = [vec2f(lowX, lowY),vec2f(highX, lowY),vec2f(highX, highY),vec2f(lowX, highY)]

proc addNewImage(tb : TextureBlock, img : Image) =
    let requiredSize = img.dimensions + vec2i(tb.borderWidth * 2, tb.borderWidth * 2)
    let possibleRects = tb.openRects.filterIt(it.dimensions.x >= requiredSize.x and it.dimensions.y >= requiredSize.y)
    let chosenRect = possibleRects.minBy((rect) => min(rect.dimensions.x, rect.dimensions.y))
    if chosenRect.isSome:
        let chosenRect = chosenRect.get
        for i, r in tb.openRects:
            if r == chosenRect:
                tb.openRects.del(i)
                break
        # add in the new rects, todo: this is quite naive at the moment, but probably fine for a while, just not terribly efficient at packing
        tb.openRects.add(rect(chosenRect.position + vec2i(0, requiredSize.y), chosenRect.dimensions - vec2i(0, requiredSize.y)))
        tb.openRects.add(rect(chosenRect.position + vec2i(requiredSize.x, 0), vec2i(chosenRect.dimensions.x - requiredSize.x, requiredSize.y)))
        
        
        tb.image.copyFrom(img, chosenRect.position + vec2i(tb.borderWidth, tb.borderWidth))
        tb.image.revision += 1
        tb.imageData[img] = ImageData(location : chosenRect.position, revision : img.revision)
        tb.imageTexCoords[img] = tb.toTexCoords(Recti(position : chosenRect.position + vec2i(tb.borderWidth, tb.borderWidth), dimensions : img.dimensions))
    else:
        raise newException(ValueError, "Could not find space for image in texture block")
    

proc `[]`*(tb : TextureBlock, img : Image) : ref array[4, Vec2f] =
    result = tb.imageTexCoords.getOrDefault(img, nil)
    if result == nil:
        tb.addNewImage(img)
        result = tb.imageTexCoords[img]

proc addImage*(tb : TextureBlock, img : Image) =
    discard tb[img]