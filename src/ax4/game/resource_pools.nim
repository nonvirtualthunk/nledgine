import worlds
import tables
import core
import noto
import config
import game/library
import resources

type
   ResourcePools* = object
      resources* : Table[Taxon, Reduceable[int]]

   ResourcePoolInfo* = object
      recoveryAmount* : int

defineReflection(ResourcePools)


proc currentResourceValue*(r : ref ResourcePools, taxon : Taxon) : int =
   r.resources.getOrDefault(taxon).currentValue

proc recoverResource*(world : World, e : Entity, resource : Taxon, amount : int) =
   withWorld world:
      let rsrc = e[ResourcePools]
      var newV = rsrc.resources.getOrDefault(resource)
      newV.recoverBy(amount)
      e.modify(ResourcePools.resources.put(resource,newV))

proc payResource*(world : World, e : Entity, resource : Taxon, amount : int) =
   withWorld world:
      let rsrc = e[ResourcePools]
      var newV = rsrc.resources.getOrDefault(resource)
      newV.reduceBy(amount)
      e.modify(ResourcePools.resources.put(resource,newV))

proc readFromConfig*(cv : ConfigValue, r : var ResourcePoolInfo) =
   let recoveryAmount = cv["recoveryAmount"]
   if recoveryAmount.isStr:
      if recoveryAmount.asStr == "full":
         r.recoveryAmount = 10000
      else : warn "invalid recoveryAmount for a resource : ", recoveryAmount
   elif recoveryAmount.isNumber:
      r.recoveryAmount = recoveryAmount.asInt
   else: warn "invalid config value for recovery amount : ", recoveryAmount



defineLibrary[ResourcePoolInfo]:
   let lib = new Library[ResourcePoolInfo]
   
   let confs = config("ax4/game/resource_info.sml")
   for k,v in confs:
      let key = taxon("ResourcePools", k)
      let info = readInto(v, ResourcePoolInfo)
      lib[key] = info

   lib