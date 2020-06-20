import worlds
import tables
import core
import noto
import config
import game/library
import resources

type
   Resources* = object
      resources* : Table[Taxon, Reduceable[int]]

   ResourceInfo* = object
      recoveryAmount* : int

defineReflection(Resources)


proc currentResourceValue*(r : ref Resources, taxon : Taxon) : int =
   r.resources.getOrDefault(taxon).currentValue

proc recoverResource*(world : World, e : Entity, resource : Taxon, amount : int) =
   withWorld world:
      let rsrc = e[Resources]
      var newV = rsrc.resources.getOrDefault(resource)
      newV.recoverBy(amount)
      e.modify(Resources.resources.put(resource,newV))

proc payResource*(world : World, e : Entity, resource : Taxon, amount : int) =
   withWorld world:
      let rsrc = e[Resources]
      var newV = rsrc.resources.getOrDefault(resource)
      newV.reduceBy(amount)
      e.modify(Resources.resources.put(resource,newV))

proc readFromConfig*(cv : ConfigValue, r : var ResourceInfo) =
   let recoveryAmount = cv["recoveryAmount"]
   if recoveryAmount.isStr:
      if recoveryAmount.asStr == "full":
         r.recoveryAmount = 10000
      else : warn "invalid recoveryAmount for a resource : ", recoveryAmount
   elif recoveryAmount.isNumber:
      r.recoveryAmount = recoveryAmount.asInt
   else: warn "invalid config value for recovery amount : ", recoveryAmount



defineLibrary[ResourceInfo]:
   let lib = new Library[ResourceInfo]
   
   let confs = config("ax4/game/resource_info.sml")
   for k,v in confs:
      let key = taxon("Resources", k)
      let info = readInto(v, ResourceInfo)
      lib[key] = info

   lib