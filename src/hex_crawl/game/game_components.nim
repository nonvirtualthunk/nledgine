import game_prelude
import engines
import worlds
import arxmath
import game/library
import prelude
import events
import noto
import glm
import game/flags
import windowingsystem/rich_text


import logic
import data


type
  CaptainComponent* = ref object of LiveGameComponent

  EncounterComponent* = ref object of LiveGameComponent


method initialize(g: CaptainComponent, world: LiveWorld) =
  g.name = "CaptainComponent"
  var captainCount = 0
  for c in world.entitiesWithData(Captain): captainCount.inc
  if captainCount == 0:
    let captain = createCaptain(world)
    captain[Captain].encounterStack = @[EncounterElement(node: some(taxon("Encounters", "SundarsLanding|Initial")))]
    captain[Flags].flags[† Qualities.Urchin] = 1

method update(g: CaptainComponent, world: LiveWorld) =
  discard

method onEvent(g: CaptainComponent, world: LiveWorld, event: Event) =
  discard





method initialize(g: EncounterComponent, world: LiveWorld) =
  g.name = "EncounterComponent"


method update(g: EncounterComponent, world: LiveWorld) =
  discard

method onEvent(g: EncounterComponent, world: LiveWorld, event: Event) =
  discard
  # postMatcher(event):
  #   extract(EncounterOptionChosenEvent, entity, option):
  #     let outcome = determineOutcome(world, entity, option)
  #     if outcome.text.nonEmpty:
  #       entity[Captain].encounterStack.add(EncounterElement(outcome: some(outcome)))
  #     else:
  #       for eff in outcome.effects:
  #         applyEffect(world, entity, eff)
  #   extract(EncounterOutcomeContinueEvent, entity):
  #     let cap = entity[Captain]
  #     if cap.encounterStack[^1].outcome.isNone:
  #       warn &"Encounter stack top is not an outcome?"
  #     else:
  #       let elem = cap.encounterStack[^1]
  #       cap.encounterStack.setLen(cap.encounterStack.len - 1)
  #       for eff in elem.outcome.get.effects:
  #         applyEffect(world, entity, eff)