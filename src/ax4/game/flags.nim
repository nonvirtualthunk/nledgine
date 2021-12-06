import worlds
import tables
import ax_events
import game/modifiers
import game/library
import game/flags
import config
import resources
import noto
import options
import math
import arxregex
import strutils
import effect_types

export flags

type
  FlagBehavior* = object
    effect*: GameEffect
    trigger*: EventCondition
    onlyIfPresent*: bool

  FlagMetaInfo* = object
    flag*: Taxon
    behaviors*: seq[FlagBehavior]
    attackModifiers*: seq[AttackModifier]




proc readFromConfig*(c: ConfigValue, v: var FlagBehavior) =
  v.onlyIfPresent = true
  readFromConfigByField(c, FlagBehavior, v)

proc readFromConfig*(c: ConfigValue, v: var FlagMetaInfo) =
  c["behaviors"].readInto(v.behaviors)
  if c["tickDown"].nonEmpty:
    v.behaviors.add(FlagBehavior(
      onlyIfPresent: true,
      trigger: readInto(c["tickDown"], EventCondition),
      effect: changeFlagEffect(v.flag, Modifier[int](operation: ModifierOperation.Sub, value: 1))
    ))
  if c["resetAtEndOfTurn"].asBool(orElse = false):
    v.behaviors.add(FlagBehavior(
      onlyIfPresent: true,
      trigger: EventCondition(kind: EventConditionKind.OnTurnEnded),
      effect: changeFlagEffect(v.flag, Modifier[int](operation: ModifierOperation.Set, value: 0))
    ))
  if c["resetAtStartOfTurn"].asBool(orElse = false):
    v.behaviors.add(FlagBehavior(
      onlyIfPresent: true,
      trigger: EventCondition(kind: EventConditionKind.OnTurnStarted),
      effect: changeFlagEffect(v.flag, Modifier[int](operation: ModifierOperation.Set, value: 0))
    ))


const flagEquivPattern = re"(?x)([a-zA-Z0-9]+)(?:\[(.+)\])?\(([0-9]+)\)"
const countsAsNPattern = re"(?ix)counts\s?as(\d+)"

defineLibrary[FlagMetaInfo]:
  var lib = new Library[FlagMetaInfo]
  lib.defaultNamespace = "flags"

  let confs = config("ax4/game/flags.sml")
  for k, v in confs["Flags"]:
    let key = taxon("Flags", k)
    let flagMeta = new FlagMetaInfo
    flagMeta.flag = key
    v.readInto(flagMeta[])
    lib[key] = flagMeta
    fine &"Flag meta info[{key}]: {lib[key][]}"
  lib


