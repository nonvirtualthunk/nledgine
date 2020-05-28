import worlds
import tables
import noto
import sequtils
import hashes
import reflect


type
    Taxon* = ref object
        id : int
        name* : string
        namespace* : string
        parents* : seq[Taxon]

    Taxonomy* = object
        idCounter : int
        taxonsByNameAndNamespace : Table[(string, string), Taxon]


defineReflection(Taxonomy)
const RootNamespace = "root"
let UnknownThing* = Taxon(name : "UnknownThing", namespace : RootNamespace, parents : @[], id : 0)
    
proc `==`*(a,b : Taxon) : bool =
    if a.isNil or b.isNil:
        a.isNil and b.isNil
    else:
        a.id == b.id

proc hash*(a : Taxon) : Hash =
    a.id.hash

proc taxon*(t : ref Taxonomy, namespace : string, name : string) : Taxon =
    result = t.taxonsByNameAndNamespace.getOrDefault((namespace, name), UnknownThing)
    if result == UnknownThing:
        warn "Unresolveable taxon ", namespace, ".", name

proc taxon*(t : ref Taxonomy, name : string) : Taxon =
    taxon(t, RootNamespace, name)

proc isA*(t : Taxon, q : Taxon) : bool =
    t == q or t.parents.anyIt(it.isA(q))

proc addTaxon*(t : var Taxonomy, namespace : string, name : string, parents : seq[Taxon]) : Taxon =
    t.idCounter.inc
    result = Taxon(id : t.idCounter, name : name, namespace : namespace, parents : parents)
    t.taxonsByNameAndNamespace[(namespace, name)] = result

proc addTaxon*(t : var Taxonomy, name : string, parents : seq[Taxon]) : Taxon =
    t.addTaxon(RootNamespace, name, parents)

iterator taxons*(t : ref Taxonomy) : Taxon =
    for v in t.taxonsByNameAndNamespace.values:
        yield v

iterator taxonsInNamespace*(t : ref Taxonomy, namespace : string) : Taxon =
    for v in t.taxons:
        if v.namespace == namespace:
            yield v