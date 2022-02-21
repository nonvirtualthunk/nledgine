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


import logic
import data


type
  CaptainComponent* = ref object of LiveGameComponent


method initialize(g: CaptainComponent, world: LiveWorld) =
  g.name = "CaptainComponent"
  var captainCount = 0
  for c in world.entitiesWithData(Captain): captainCount.inc
  if captainCount == 0:
    let captain = world.createEntity()
    captain.attachData(
      Captain(
        encounterStack: @[taxon("Encounters", "SundarsLanding|Initial")],
        attributes: {
          † Attributes.Iron : 2,
          † Attributes.Silver : 2,
          † Attributes.Mask : 2,
          † Attributes.Lens : 2,
          † Attributes.Art : 2,
          † Attributes.Spirit : 2,
        }.toTable,
        money: 20
      )
    )
    captain.attachData(Flags())
    captain[Flags].flags[† Qualities.Urchin] = 1

method update(g: CaptainComponent, world: LiveWorld) =
  discard

method onEvent(g: CaptainComponent, world: LiveWorld, event: Event) =
  discard