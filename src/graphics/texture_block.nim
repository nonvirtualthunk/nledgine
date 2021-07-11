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
import graphics/color
import stb_image/write as stbi
import noto
import random


type
  ImageData = ref object
    location*: Vec2i
    dimensions*: Vec2i
    texPosition*: Vec2f
    texDimensions*: Vec2f
    revision: int
    texCoords*: ref array[4, Vec2f]
  TextureBlock* = ref object of Texture
    id: TextureID
    image: Image
    openRects: seq[Recti]
    imageData: Table[Image, ImageData]
    borderWidth: int
    magFilter: GLenum
    minFilter: GLenum
    internalFormat: GLenum
    dataFormat: GLenum
    blankImage: Image
    blankTexCoords: ref array[4, Vec2f]

method textureInfo*(tb: TextureBlock): TextureInfo =
  if tb.id == 0:
    tb.id = core.textureID.fetchAdd(1)+1
  result = TextureInfo(
     id: tb.id,
     data: tb.image.data,
     len: tb.image.dimensions.x * tb.image.dimensions.y * tb.image.channels,
     magFilter: tb.magFilter,
     minFilter: tb.minFilter,
     internalFormat: tb.internalFormat,
     dataFormat: tb.dataFormat,
     revision: tb.image.revision,
     width: tb.image.dimensions.x,
     height: tb.image.dimensions.y
  )

proc addNewImage(tb: TextureBlock, img: Image)

proc newTextureBlock*(size: int = 2048, borderWidth: int = 1, gammaCorrection: bool = false): TextureBlock =
  let internalFormat = if gammaCorrection: GL_SRGB_ALPHA
                 else: GL_RGBA
  TextureBlock(
    image: images.createImage(vec2i(size, size)),
    openRects: @[Recti(position: vec2(borderWidth, borderWidth), dimensions: vec2(size - borderWidth * 2, size - borderWidth * 2))],
    borderWidth: borderWidth,
    minFilter: GL_NEAREST,
    magFilter: GL_NEAREST,
    internalFormat: internalFormat,
    dataFormat: GL_RGBA
  )

proc toTexCoords(tb: TextureBlock, rect: Recti): ref array[4, Vec2f] =
  result = new array[4, Vec2f]

  let wf = tb.image.dimensions.x.float
  let hf = tb.image.dimensions.y.float
  if rect.dimensions == vec2i(1, 1):
    let px = rect.position.x.float / wf
    let py = rect.position.y.float / hf
    result[] = [vec2f(px, py), vec2f(px, py), vec2f(px, py), vec2f(px, py)]
  else:
    let lowX = (rect.x.float + 0.0f) / wf
    let highX = ((rect.x + rect.width).float + 0.0f) / wf
    let lowY = (rect.y.float + 0.0f) / hf
    let highY = ((rect.y + rect.height).float + 0.0f) / hf

    result[] = [vec2f(lowX, lowY), vec2f(highX, lowY), vec2f(highX, highY), vec2f(lowX, highY)]

proc addNewImage(tb: TextureBlock, img: Image) =
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
    if chosenRect.dimensions.x - requiredSize.x < chosenRect.dimensions.y - requiredSize.y:
      tb.openRects.add(rect(
        chosenRect.position + vec2i(0, requiredSize.y),
        chosenRect.dimensions - vec2i(0, requiredSize.y)))
      tb.openRects.add(rect(
        chosenRect.position + vec2i(requiredSize.x, 0),
        vec2i(chosenRect.dimensions.x - requiredSize.x, requiredSize.y)))
    else:
      tb.openRects.add(rect(
        chosenRect.position + vec2i(requiredSize.x, 0),
        chosenRect.dimensions - vec2i(requiredSize.x, 0)))
      tb.openRects.add(rect(
        chosenRect.position + vec2i(0, requiredSize.y),
        vec2i(requiredSize.x, chosenRect.dimensions.y - requiredSize.y)))


    tb.image.copyFrom(img, chosenRect.position + vec2i(tb.borderWidth, tb.borderWidth))
    tb.image.revision += 1
    let tc = tb.toTexCoords(Recti(position: chosenRect.position + vec2i(tb.borderWidth, tb.borderWidth), dimensions: img.dimensions))
    tb.imageData[img] = ImageData(location: chosenRect.position, dimensions: img.dimensions, revision: img.revision, texPosition: tc[0], texDimensions: tc[2] - tc[0], texCoords: tc)
  else:
    warn &"Failed to find space for image in texture block"
    for rect in tb.openRects:
      let color = rgba(rand(255).uint8, rand(255).uint8, rand(255).uint8, 255.uint8)
      for x in rect.x ..< rect.x + rect.width:
        for y in rect.y ..< rect.y + rect.height:
          tb.image[x, y] = color
    stbi.writePNG(
      "/tmp/out.png",
      tb.image.width,
      tb.image.height,
      tb.image.channels,
      tb.image.data
    )
    raise newException(ValueError, "Could not find space for image in texture block")

proc blankTexCoords*(tb: TextureBlock): ref array[4, Vec2f]

proc `[]`*(tb: TextureBlock, img: Image): ref array[4, Vec2f] =
  let tmp = tb.imageData.getOrDefault(img, nil)
  if tmp == nil:
    tb.addNewImage(img)
    result = tb.imageData[img].texCoords
  else:
    result = tmp.texCoords

proc imageData*(tb: TextureBlock, img: Image): ImageData =
  result = tb.imageData.getOrDefault(img, nil)
  if result == nil:
    tb.addNewImage(img)
    result = tb.imageData[img]

proc blankTexCoords*(tb: TextureBlock): ref array[4, Vec2f] =
  if tb.blankImage.isNil:
    tb.blankImage = createImage(vec2i(1, 1))
    tb.blankImage[0, 0] = rgba(1.0f, 1.0f, 1.0f, 1.0f)
    tb.addNewImage(tb.blankImage)
    tb.blankTexCoords = tb[tb.blankImage]
  tb.blankTexCoords

proc addImage*(tb: TextureBlock, img: Image) =
  discard tb[img]

proc dimensions*(tb: TextureBlock): Vec2i = tb.image.dimensions
