import strutils
import arxregex
import engines
import survival/game/logic


type
  SurvivalDebugComponent* = ref object of GraphicsComponent







const printEntityRe = "print\\s+([0-9]+)".re
const printPlayerRe = "print\\s+player".re


method onEvent*(g: SurvivalDebugComponent, world: LiveWorld, display: DisplayWorld, event: Event) =
  matcher(event):
    extract(DebugCommandEvent, command):
      matcher(command):
        extractMatches(printPlayerRe):
          printEntityData(world, player(world))
        extractMatches(printEntityRe, target):
          printEntityData(world, Entity(id: target.parseInt))

