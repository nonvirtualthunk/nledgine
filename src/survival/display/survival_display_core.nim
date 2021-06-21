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
import graphics/image_extras
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


proc iconFor*(t: Taxon): ImageLike =
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
        return imageLike("images/unknown.png")
  else:
    warn &"iconFor(...) only supports items at this time: {t}"
    return imageLike("images/unknown.png")
