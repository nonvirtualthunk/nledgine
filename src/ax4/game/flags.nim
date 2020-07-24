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

export flags

type

   FlagBehavior* = object
      modifier*: Modifier[int]
      trigger*: EventCondition
      onlyIfPresent*: bool

   FlagBehaviors* = object
      behaviors*: seq[FlagBehavior]


proc readFromConfig*(c: ConfigValue, v: var FlagBehavior) =

   discard

proc readFromConfig*(c: ConfigValue, v: var FlagBehaviors) =
   c["behaviors"].readInto(v.behaviors)
   if c["tickDown"].nonEmpty:
      v.behaviors.add(FlagBehavior(
         onlyIfPresent: true,
         trigger: readInto(c["tickDown"], EventCondition),
         modifier: Modifier[int](operation: ModifierOperation.Sub, value: 1)
      ))
   if c["resetAtEndOfTurn"].asBool(false):
      v.behaviors.add(FlagBehavior(
         onlyIfPresent: true,
         trigger: EventCondition(kind: EventConditionKind.OnTurnEnded),
         modifier: Modifier[int](operation: ModifierOperation.Set, value: 0)
      ))
   if c["resetAtStartOfTurn"].asBool(false):
      v.behaviors.add(FlagBehavior(
         onlyIfPresent: true,
         trigger: EventCondition(kind: EventConditionKind.OnTurnStarted),
         modifier: Modifier[int](operation: ModifierOperation.Set, value: 0)
      ))

defineLibrary[FlagBehaviors]:
   var lib = new Library[FlagBehaviors]
   lib.defaultNamespace = "flags"

   let confs = config("ax4/game/flags.sml")
   for k, v in confs["Flags"]:
      let key = taxon("Flags", k)
      lib[key] = readInto(v, FlagBehaviors)

   lib


proc modifyFlag*(world: World, entity: Entity, flag: Taxon, modifier: Modifier[int]) =
   withWorld(world):
      var cur = entity.data(Flags).flags.getOrDefault(flag)
      modifier.apply(cur)
      entity.modify(Flags.flags.put(flag, cur))

proc flagValue*(view: WorldView, entity: Entity, flag: Taxon): int =
   withView(view):
      let cur = entity.data(Flags).flags.getOrDefault(flag)

      cur
