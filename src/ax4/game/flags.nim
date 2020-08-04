import worlds
import tables
import ax_events
import modifiers
import game/library
import game/flags
import worlds
import config
import resources
import modifiers
import noto
import options
import math
import arxregex
import strutils
import effect_types

export flags

type
   FlagEquivalence* = object
      flag*: Taxon
      adder*: int
      multiplier*: int

   FlagBehavior* = object
      modifier*: Modifier[int]
      trigger*: EventCondition
      onlyIfPresent*: bool

   FlagMetaInfo* = object
      behaviors*: seq[FlagBehavior]
      equivalences*: seq[FlagEquivalence]
      attackModifiers*: seq[AttackModifier]




proc readFromConfig*(c: ConfigValue, v: var FlagBehavior) =
   warn &"Reading flag behavior directly from conf has not yet been implemented, cv: {c}"
   discard

proc readFromConfig*(c: ConfigValue, v: var FlagMetaInfo) =
   c["behaviors"].readInto(v.behaviors)
   if c["tickDown"].nonEmpty:
      v.behaviors.add(FlagBehavior(
         onlyIfPresent: true,
         trigger: readInto(c["tickDown"], EventCondition),
         modifier: Modifier[int](operation: ModifierOperation.Sub, value: 1)
      ))
   if c["resetAtEndOfTurn"].asBool(orElse = false):
      v.behaviors.add(FlagBehavior(
         onlyIfPresent: true,
         trigger: EventCondition(kind: EventConditionKind.OnTurnEnded),
         modifier: Modifier[int](operation: ModifierOperation.Set, value: 0)
      ))
   if c["resetAtStartOfTurn"].asBool(orElse = false):
      v.behaviors.add(FlagBehavior(
         onlyIfPresent: true,
         trigger: EventCondition(kind: EventConditionKind.OnTurnStarted),
         modifier: Modifier[int](operation: ModifierOperation.Set, value: 0)
      ))


defineLibrary[FlagMetaInfo]:
   var lib = new Library[FlagMetaInfo]
   lib.defaultNamespace = "flags"

   let confs = config("ax4/game/flags.sml")
   var flagInfo: Table[Taxon, FlagMetaInfo]
   for k, v in confs["Flags"]:
      let key = taxon("Flags", k)
      flagInfo[key] = readInto(v, FlagMetaInfo)

   for k, c in confs["Flags"]:
      let key = taxon("Flags", k)
      let equivalenceConfigs = @[
         (c["countsAsNegative"], (0, -1)),
         (c["countsAs"], (0, 1)),
         (c["countsAsOne"], (1, 0)),
         (c["countsAsNegativeOne"], (-1, 0))
      ]
      for eqc in equivalenceConfigs:
         let (subConf, addMul) = eqc
         let (add, mul) = addMul
         for ssv in subConf.asArr:
            var mulAmount = 1
            var flagName = ssv.asStr
            matcher(ssv.asStr):
               extractMatches(wordNumberPattern, word, number):
                  flagName = word
                  mulAmount = number.parseInt

            let equivalentTo = taxon("flags", flagName)
            flagInfo[equivalentTo].equivalences.add(FlagEquivalence(flag: key, adder: add, multiplier: mul * mulAmount))

   for k, v in flagInfo:
      lib[k] = v

   lib


proc modifyFlag*(world: World, entity: Entity, flag: Taxon, modifier: Modifier[int]) =
   withWorld(world):
      let flagInfo = library(FlagInfo).get(flag).get(FlagInfo())
      var cur = entity.data(flags.Flags).flags.getOrDefault(flag)
      let oldV = cur
      modifier.apply(cur)
      if flagInfo.minValue.isSome:
         cur = max(flagInfo.minValue.get, cur)
      if flagInfo.maxValue.isSome:
         cur = min(flagInfo.maxValue.get, cur)

      world.eventStmts(FlagChangedEvent(flag: flag, oldValue: oldV, newValue: cur)):
         entity.modify(Flags.flags.put(flag, cur))

proc rawFlagValue*(flags: ref Flags, flag: Taxon): int =
   flags.flags.getOrDefault(flag)

proc rawFlagValue*(view: WorldView, entity: Entity, flag: Taxon): int =
   rawFlagValue(view.data(entity, Flags), flag)

proc flagValue*(flags: ref Flags, flag: Taxon): int =
   var cur = rawFlagValue(flags, flag)
   let lib = library(FlagMetaInfo)
   let meta = lib.get(flag).get(FlagMetaInfo())
   for equiv in meta.equivalences:
      let v = flagValue(flags, equiv.flag)
      cur += v * equiv.multiplier + sgn(v) * equiv.adder

   cur

proc flagValue*(view: WorldView, entity: Entity, flag: Taxon): int =
   withView(view):
      let flags = view.data(entity, Flags)
      flagValue(flags, flag)

