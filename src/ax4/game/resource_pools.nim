import worlds
import tables
import core
import noto
import config
import game/library
import resources
import ax4/game/modifiers
import ax4/game/ax_events
import strformat

type
   ResourcePools* = object
      resources*: Table[Taxon, Reduceable[int]]

   ResourcePoolInfo* = object
      recoveryAmount*: int

   ResourceChangedEvent* = ref object of AxEvent
      resource*: Taxon
      oldValue*: int
      newValue*: int

defineReflection(ResourcePools)


method toString*(evt: ResourceChangedEvent): string =
   return &"ResourceChangedEvent({$evt[]})"

proc currentResourceValue*(r: ref ResourcePools, taxon: Taxon): int =
   r.resources.getOrDefault(taxon).currentValue

proc maximumResourceValue*(r: ref ResourcePools, taxon: Taxon): int =
   r.resources.getOrDefault(taxon).maxValue

proc recoverResource*(world: World, e: Entity, resource: Taxon, amount: int) =
   if amount == 0: return

   withWorld world:
      let rsrc = e[ResourcePools]
      let oldV = rsrc.resources.getOrDefault(resource)
      var newV = oldV
      newV.recoverBy(amount)
      world.eventStmts(ResourceChangedEvent(resource: resource, oldValue: oldV.currentValue, newValue: newV.currentValue)):
         e.modify(ResourcePools.resources.put(resource, newV))

proc payResource*(world: World, e: Entity, resource: Taxon, amount: int) =
   if amount == 0: return

   withWorld world:
      let rsrc = e[ResourcePools]
      let oldV = rsrc.resources.getOrDefault(resource)
      var newV = oldV
      newV.reduceBy(amount)
      world.eventStmts(ResourceChangedEvent(resource: resource, oldValue: oldV.currentValue, newValue: newV.currentValue)):
         e.modify(ResourcePools.resources.put(resource, newV))

proc changeResource*(world: World, e: Entity, resource: Taxon, modifier: Modifier[int]) =
   if (modifier.operation == ModifierOperation.Add or modifier.operation == ModifierOperation.Sub) and modifier.value == 0: return

   withWorld world:
      let rsrc = e[ResourcePools]
      let oldV = rsrc.resources.getOrDefault(resource)
      var newV = oldV
      modifier.apply(newV)
      world.eventStmts(ResourceChangedEvent(resource: resource, oldValue: oldV.currentValue, newValue: newV.currentValue)):
         e.modify(ResourcePools.resources.put(resource, newV))

proc readFromConfig*(cv: ConfigValue, r: var ResourcePoolInfo) =
   let recoveryAmount = cv["recoveryAmount"]
   if recoveryAmount.isStr:
      if recoveryAmount.asStr == "full":
         r.recoveryAmount = 10000
      else: warn &"invalid recoveryAmount for a resource : {recoveryAmount}"
   elif recoveryAmount.isNumber:
      r.recoveryAmount = recoveryAmount.asInt
   else: warn &"invalid config value for recovery amount : {recoveryAmount}"



defineLibrary[ResourcePoolInfo]:
   var lib = new Library[ResourcePoolInfo]
   lib.defaultNamespace = "resource pools"

   let confs = config("ax4/game/resource_pools.sml")
   for k, v in confs["ResourcePools"]:
      let key = taxon("resource pools", k)
      let info = readInto(v, ResourcePoolInfo)
      lib[key] = info

   lib
