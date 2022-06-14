import strutils
import arxregex
import engines
import survival/game/logic
import survival/game/entities
import noto
import windowingsystem/windowingsystem
import survival/display/world_graphics
import worlds/taxonomy


type
  SurvivalDebugComponent* = ref object of GraphicsComponent
    printWidgetEvents: bool
    printUIEvents: bool






const printEntityRe = "print\\s+([0-9]+)".re
const printPlayerRe = "print\\s+player".re
const spawnRe = "spawn\\s+([a-zA-Z0-9.]+)".re
const funcRe = "([a-zA-Z]+[a-zA-Z0-9]*)\\(([a-zA-Z0-9]+)?\\)".re


proc enableDisable(g: SurvivalDebugComponent, feature: string, truth: bool) =
  case feature:
    of "printUIEvents":
      g.printUIEvents = truth
    of "printWidgetEvents":
      g.printWidgetEvents = truth
    else:
      warn &"Unknown enable/disable feature: {feature}"
      return

  if truth:
    info &"Enabled {feature}"
  else:
    info &"Disabled {feature}"

proc follow(g: SurvivalDebugComponent, display: DisplayWorld, arg: string) =
  let entId = parseIntOpt(arg)
  if entId.isSome:
    display[SurvivalCameraData].povEntity = Entity(id: entId.get)
  else:
    warn &"follow(...) expects an integer entity id, not {arg}"

method onEvent*(g: SurvivalDebugComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(DebugCommandEvent, command):
      matcher(command):
        extractMatches(printPlayerRe):
          printEntityData(world, player(world))
        extractMatches(printEntityRe, target):
          printEntityData(world, Entity(id: target.parseInt))
        extractMatches(spawnRe, spawnTarget):
          let t = findTaxon(spawnTarget)
          if t == UnknownThing:
            warn &"Unknown taxon to spawn: {spawnTarget}"
          else:
            let reg = player(world)[Physical].region
            let pos = facedPosition(world, world.player)
            if t.isA(† Item):
              let item = createItem(world, reg, t)
              placeEntity(world, item, pos, capsuled = true)
            elif t.isA(† Creature):
              let creature = createCreature(world, reg, t)
              placeEntity(world, creature, pos)
        extractMatches(funcRe, funcName, arg0):
          case funcName:
            of "enable":
              enableDisable(g, arg0, true)
            of "disable":
              enableDisable(g, arg0, false)
            of "follow":
              follow(g, display, arg0)
            else:
              warn &"Unknown function: {funcName}"
        warn &"Unknown command: {command}"


  if g.printUIEvents:
    info toString(event)
  elif g.printWidgetEvents and event of WidgetEvent:
    info toString(event)


