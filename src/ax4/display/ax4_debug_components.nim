import strutils
import arxregex
import engines
import noto
import ax4/game/characters
import windowingsystem/windowingsystem
import worlds/worlds


type
  Ax4DebugComponent* = ref object of GraphicsComponent
    printWidgetEvents: bool
    printUIEvents: bool


const printEntityRe = "print\\s+([0-9]+)".re
const printPlayerRe = "print\\s+player".re
const funcRe = "([a-zA-Z]+[a-zA-Z0-9]*)\\(([a-zA-Z0-9]+)?\\)".re


proc enableDisable(g: Ax4DebugComponent, feature: string, truth: bool) =
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

method onEvent*(g: Ax4DebugComponent, world: World, curView: WorldView, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(DebugCommandEvent, command):
      matcher(command):
        extractMatches(printPlayerRe):
          for c in playerCharacters(curView):
            printEntityData(world, c)
        extractMatches(printEntityRe, target):
          printEntityData(world, Entity(id: target.parseInt))
        extractMatches(funcRe, funcName, arg0):
          case funcName:
            of "enable":
              enableDisable(g, arg0, true)
            of "disable":
              enableDisable(g, arg0, false)
            else:
              warn &"Unknown function: {funcName}"
        warn &"Unknown command: {command}"


  if g.printUIEvents:
    info toString(event)
  elif g.printWidgetEvents and event of WidgetEvent:
    info toString(event)


