import tables
import worlds
import sugar
import config
import library
import resources
import options
import arxregex
import noto
import strutils
import math
import game/modifiers
import engines/core_event_types

type
  Flags* = object
    flags*: Table[Taxon, int]
    keyedFlags*: Table[Taxon, Table[Taxon, int]]

  FlagEquivalence* = object
    flag*: Taxon
    adder*: int
    multiplier*: int


  FlagInfo* = object
    taxon*: Taxon
    mechanicalDescription*: string
    description*: string
    vagueDescription*: string
    targetEquivalences*: seq[FlagEquivalence]
    equivalences*: seq[FlagEquivalence]
    targetKeyedEquivalences*: Table[Taxon, seq[FlagEquivalence]]
    keyedEquivalences*: Table[Taxon, seq[FlagEquivalence]]
    minValue*: Option[int]
    maxValue*: Option[int]
    hidden*: bool
    boolean*: bool

  FlagChangedEvent* = ref object of GameEvent
    flag*: Taxon
    oldValue*: int
    newValue*: int


defineReflection(Flags)


eventToStr(FlagChangedEvent)

const flagEquivPattern = re"(?x)([a-zA-Z0-9]+)(?:\[(.+)\])?\(([0-9]+)\)"
const countsAsNPattern = re"(?ix)counts\s?as(\d+)"


proc readFromConfig*(cv: ConfigValue, f: var Flags) =
  if cv.isObj:
    for k,v in cv.fields:
      f.flags[taxon("Flags", k)] = v.asInt
  else:
    err &"Unknown representation of Flags: {cv}"

proc readFromConfig*(cv: ConfigValue, v: var FlagInfo) =
  cv["mechanicalDescriptor"].readInto(v.mechanicalDescription)
  cv["description"].readInto(v.description)
  cv["vagueDescription"].readInto(v.vagueDescription)
  cv["minValue"].readInto(v.minValue)
  cv["maxValue"].readInto(v.maxValue)
  cv["hidden"].readInto(v.hidden)
  cv["boolean"].readInto(v.boolean)
  if cv["equivalences"].nonEmpty:
    warn &"Trying to supply equivalences directly for flag definition is not supported at this time: {cv}"

  if cv["limitToZero"].asBool(orElse = false):
    v.minValue = some(0)

  var equivalenceConfigs = @[
    (cv["countsAsNegative"], (0, -1)),
    (cv["countsAs"], (0, 1)),
    (cv["countsAsOne"], (1, 0)),
    (cv["countsAsNegativeOne"], (-1, 0))
  ]
  # Allows for "countsAs25: DamageDealtReduction" or whatever arbitrary number, it's hacky, but :shrug:
  for subK, subV in cv.fields:
    matcher(subK):
      extractMatches(countsAsNPattern, n):
        equivalenceConfigs.add((subV, (n.parseInt, 0)))
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
        v.targetKeyedEquivalences.mgetOrPut(flagArg.get, default(seq[FlagEquivalence])).add(FlagEquivalence(flag: v.taxon, adder: add, multiplier: mul * mulAmount))
      else:
        v.targetEquivalences.add(FlagEquivalence(flag: equivalentTo, adder: add, multiplier: mul * mulAmount))



proc postProcessEquivalencies(lib: Library[FlagInfo]) =
  for k, v in lib:
    for targetEq in v.targetEquivalences:
      let newEquiv = FlagEquivalence(flag: k, adder: targetEq.adder, multiplier: targetEq.multiplier)
      lib[targetEq.flag].equivalences.add(newEquiv)



defineSimpleLibrary[FlagInfo](ProjectName & "/game/flags.sml", "Flags", postProcessEquivalencies)


proc rawFlagValue*(flags: ref Flags, flag: Taxon, arg: Option[Taxon] = none(Taxon)): int =
  if arg.isSome:
    flags.keyedFlags.getOrDefault(flag).getOrDefault(arg.get)
  else:
    flags.flags.getOrDefault(flag)

proc rawFlagValue*(view: WorldView, entity: Entity, flag: Taxon, arg: Option[Taxon] = none(Taxon)): int =
  rawFlagValue(view.data(entity, Flags), flag, arg)

proc flagValue*(flags: ref Flags, flag: Taxon, arg: Option[Taxon] = none(Taxon)): int =
  var cur = rawFlagValue(flags, flag, arg)
  let lib = library(FlagInfo)
  let meta = lib.get(flag)
  if not meta.isSome:
    cur
  else:
    let meta = meta.get
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


proc flagValue*(world: LiveWorld, entity: Entity, flag: Taxon): int =
  if hasData(world, entity, Flags):
    flagValue(entity[Flags], flag)
  else:
    0

proc keyedFlagValues*(flags: ref Flags, flag: string): Table[Taxon, int] =
  let flag = taxon("flags", flag)
  for key in flags.keyedFlags.getOrDefault(flag).keys:
    result[key] = flagValue(flags, flag, some(key))


proc modifyFlag*(world: World, entity: Entity, flag: Taxon, arg: Option[Taxon], modifier: Modifier[int]) =
  if (modifier.operation == ModifierOperation.Add or modifier.operation == ModifierOperation.Sub) and modifier.value == 0:
    return

  withWorld(world):
    let flagInfo = library(FlagInfo).get(flag)
    var cur = entity.data(flags.Flags).flags.getOrDefault(flag)
    let oldV = cur
    modifier.apply(cur)
    if flagInfo.isSome and flagInfo.get.minValue.isSome:
      cur = max(flagInfo.get.minValue.get, cur)
    if flagInfo.isSome and flagInfo.get.maxValue.isSome:
      cur = min(flagInfo.get.maxValue.get, cur)

    world.eventStmts(FlagChangedEvent(flag: flag, oldValue: oldV, newValue: cur)):
      if arg.isSome:
        entity.modify(Flags.keyedFlags.put(flag, arg.get, cur))
      else:
        entity.modify(Flags.flags.put(flag, cur))

proc modifyFlag*(world: World, entity: Entity, flag: Taxon, modifier: Modifier[int]) =
  modifyFlag(world, entity, flag, none(Taxon), modifier)

when isMainModule:
  for k,v in library(FlagInfo):
    info &"{k}:\n"
    indentLogs()
    info &"{v[]}"
    unindentLogs()