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
      keyedEquivalences*: Table[Taxon, seq[FlagEquivalence]]
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


const flagEquivPattern = re"(?x)([a-zA-Z0-9]+)(?:\[(.+)\])?\(([0-9]+)\)"

defineLibrary[FlagMetaInfo]:
   var lib = new Library[FlagMetaInfo]
   lib.defaultNamespace = "flags"

   let confs = config("ax4/game/flags.sml")
   var flagInfo: Table[Taxon, FlagMetaInfo]
   for k, v in confs["Flags"]:
      let key = taxon("Flags", k)
      flagInfo[key] = readInto(v, FlagMetaInfo)
      echo &"Flag meta info[{key}]: {flagInfo[key]}"

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
            var flagArg = none(Taxon)
            matcher(ssv.asStr):
               extractMatches(flagEquivPattern, word, arg, number):
                  flagName = word
                  mulAmount = number.parseInt
                  if arg != "":
                     flagArg = some(qualifiedTaxon(arg))

            let equivalentTo = taxon("flags", flagName)
            if flagArg.isSome:
               flagInfo.mgetOrPut(equivalentTo, FlagMetaInfo()).keyedEquivalences.mgetOrPut(flagArg.get, default(seq[FlagEquivalence])).add(FlagEquivalence(flag: key, adder: add, multiplier: mul * mulAmount))
            else:
               flagInfo.mgetOrPut(equivalentTo, FlagMetaInfo()).equivalences.add(FlagEquivalence(flag: key, adder: add, multiplier: mul * mulAmount))

   for k, v in flagInfo:
      lib[k] = v

   lib


proc modifyFlag*(world: World, entity: Entity, flag: Taxon, arg: Option[Taxon], modifier: Modifier[int]) =
   if (modifier.operation == ModifierOperation.Add or modifier.operation == ModifierOperation.Sub) and modifier.value == 0:
      return

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
         if arg.isSome:
            entity.modify(Flags.keyedFlags.put(flag, arg.get, cur))
         else:
            entity.modify(Flags.flags.put(flag, cur))

proc modifyFlag*(world: World, entity: Entity, flag: Taxon, modifier: Modifier[int]) =
   modifyFlag(world, entity, flag, none(Taxon), modifier)

proc rawFlagValue*(flags: ref Flags, flag: Taxon, arg: Option[Taxon] = none(Taxon)): int =
   if arg.isSome:
      flags.keyedFlags.getOrDefault(flag).getOrDefault(arg.get)
   else:
      flags.flags.getOrDefault(flag)

proc rawFlagValue*(view: WorldView, entity: Entity, flag: Taxon, arg: Option[Taxon] = none(Taxon)): int =
   rawFlagValue(view.data(entity, Flags), flag, arg)

proc flagValue*(flags: ref Flags, flag: Taxon, arg: Option[Taxon] = none(Taxon)): int =
   var cur = rawFlagValue(flags, flag, arg)
   let lib = library(FlagMetaInfo)
   let meta = lib.get(flag).get(FlagMetaInfo())
   if arg.isSome:
      for equiv in meta.keyedEquivalences.getOrDefault(arg.get):
         let v = flagValue(flags, equiv.flag)
         cur += v * equiv.multiplier + sgn(v) * equiv.adder
   else:
      for equiv in meta.equivalences:
         let v = flagValue(flags, equiv.flag)
         cur += v * equiv.multiplier + sgn(v) * equiv.adder

   cur

proc flagValue*(flags: ref Flags, flag: string, arg: Option[Taxon] = none(Taxon)): int =
   flagValue(flags, taxon("flags", flag), arg)

proc flagValue*(view: WorldView, entity: Entity, flag: Taxon, arg: Option[Taxon] = none(Taxon)): int =
   withView(view):
      let flags = view.data(entity, Flags)
      flagValue(flags, flag)

proc flagValues*(view: WorldView, entity: Entity): Table[Taxon, int] =
   view.data(entity, Flags).flags



proc keyedFlagValues*(flags: ref Flags, flag: string): Table[Taxon, int] =
   let flag = taxon("flags", flag)
   for key in flags.keyedFlags.getOrDefault(flag).keys:
      result[key] = flagValue(flags, flag, some(key))
