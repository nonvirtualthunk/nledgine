import survival/game/events
import survival/game/entities
import survival/game/tiles
import survival/game/survival_core
import survival/game/logic
import prelude
import engines
import worlds
import graphics/canvas
import graphics/color
import options
import reflect
import resources
import graphics/images
import glm
import random
import times
import tables
import game/library
import sequtils
import sets
import noto
import windowingsystem/windowingsystem
import core
import worlds/identity
import algorithm
import windowingsystem/rich_text
import windowingsystem/list_widget
import strutils
import engines/event_types
import arxmath


type
  # Signal to cancel whatever is being done, i.e. open menus, etc
  CancelContext* = ref object of UIEvent

  SurvivalVertex* = object
    vertex*: Vec3f
    texCoords*: Vec2f
    color*: RGBA
    animation*: Vec3f

  SurvivalQuadBuilder* = object
    position* : Vec3f
    dimensions* : Vec2f
    texture* : Image
    color* : RGBA
    origin* : Vec2f
    textureSubRect*: Rectf
    frameCount*: int
    secondsPerFrame*: float

  GraphicalModKind* {.pure.} = enum
    Offset
    Tint
    Texture

  GraphicalMod* = object
    case kind*: GraphicalModKind:
      of GraphicalModKind.Offset:
        offset*: Vec3f
      of GraphicalModKind.Tint:
        tint*: RGBA
      of GraphicalModKind.Texture:
        texture*: ImageRef

  AnimationData* = object




eventToStr(CancelContext)


proc createSurvivalCanvas*(name: string) : Canvas[SurvivalVertex, uint16] =
  createCanvas[SurvivalVertex,uint16]("survival/graphics/shaders/survival_main_shader", 1024, name)

proc drawTo*[I](qb : SurvivalQuadBuilder, cv : var Canvas[SurvivalVertex,I]) =
  let imgData = cv.texture.imageData(qb.texture)
  var vi = cv.vao.vi
  var ii = cv.vao.ii
  for i in 0 ..< 4:
    let vt = cv.vao[vi+i]
    vt.vertex.x = qb.position.x + (UnitSquareVertices[i].x - qb.origin.x) * qb.dimensions.x
    vt.vertex.y = qb.position.y + (UnitSquareVertices[i].y - qb.origin.y) * qb.dimensions.y
    vt.vertex.z = qb.position.z

    vt.color = qb.color
    if qb.textureSubRect.width > 0.0:
      vt.texCoords = imgData.texPosition + (qb.textureSubRect.position + qb.textureSubRect.dimensions * UnitSquareVertices2d[q]) * imgData.texDimensions
    else:
      vt.texCoords = imgData.texCoords[i]

    vt.animation.x = imgData.texDimensions.x / qb.frameCount.float
    vt.animation.y = qb.frameCount.float
    vt.animation.z = qb.secondsPerFrame.float

  cv.vao.addIQuad(ii,vi)

proc centered*(qb : var SurvivalQuadBuilder) : var SurvivalQuadBuilder {.discardable.} =
  qb.origin = vec2f(0.5,0.5)
  qb


proc iconFor*(world: LiveWorld, e: Entity): Image =
  if e.hasData(Fire) and e[Fire].active:
    let activeImages = e[Fire].activeImages
    if activeImages.nonEmpty:
      e[Fire].activeImages[0].asImage
    else:
      image("survival/graphics/effects/fire_c_24.png")
  elif e.hasData(Physical):
    e[Physical].images[0]
  else:
    warn &"iconFor(...) does not support entity {debugIdentifier(world, e)}"
    image("images/unknown.png")

proc iconFor*(t: Taxon): ImageRef =
  if t.isA(† Item):
    return itemKind(t).images[0]
  elif t.isA(† Recipe):
    let recipe = recipe(t)
    if recipe.icon.isSome:
      return recipe.icon.get
    else:
      if recipe.outputs.nonEmpty:
        return iconFor(recipe.outputs[0].item)
      else:
        return imageRef("images/unknown.png")
  else:
    warn &"iconFor(...) only supports items and recipes at this time: {t}"
    return imageRef("images/unknown.png")
