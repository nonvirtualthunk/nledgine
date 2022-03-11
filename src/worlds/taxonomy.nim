
import tables
import noto
import sequtils
import hashes
import resources
import strutils
import strformat
import options
import sugar

type
  Taxon* = ref object
    id: int
    name*: string
    namespace*: string
    parents*: seq[Taxon]

  ProtoTaxon* = object
    name*: string
    namespace*: string
    parents*: seq[string]

  Taxonomy* = object
    idCounter: int
    taxonsByNameAndNamespace: Table[(string, string), Taxon]
    taxonsByName: Table[string, seq[Taxon]]
    namespaceParents: Table[string, string]

  TaxonomyLoader* = object
    loadTaxonsFrom*: proc (cv: ConfigValue) : seq[ProtoTaxon] {.gcsafe.}
    loadStaticTaxons*: proc (): seq[ProtoTaxon] {.gcsafe.}


var TaxonomyLoaderCount = 0
var TaxonomyLoaders: array[10,ptr TaxonomyLoader]

proc addTaxonomyLoader*(t: TaxonomyLoader) =
  TaxonomyLoaders[TaxonomyLoaderCount] = cast[ptr TaxonomyLoader](allocShared(sizeof(TaxonomyLoader)))
  TaxonomyLoaders[TaxonomyLoaderCount][] = t
  TaxonomyLoaderCount.inc

const RootNamespace = "root"
var UnknownThing* {.threadvar.}: Taxon

proc load(taxonomy: ref Taxonomy) {.gcsafe.}


var passBackChannel: Channel[ref Taxonomy]
passBackChannel.open()

var globalTaxonomy {.threadvar.}: ref Taxonomy

var taxonomyLoaderThread: Thread[void]
createThread(taxonomyLoaderThread, proc() {.thread.} =
  UnknownThing = Taxon(name: "UnknownThing", namespace: RootNamespace, parents: @[], id: 0)
  globalTaxonomy = new Taxonomy
  globalTaxonomy.load()
  discard passBackChannel.trySend(globalTaxonomy)
)

proc getGlobalTaxonomy(): ref Taxonomy =
  if globalTaxonomy == nil:
    UnknownThing = Taxon(name: "UnknownThing", namespace: RootNamespace, parents: @[], id: 0)
    globalTaxonomy = passBackChannel.recv()
    discard passBackChannel.trySend(globalTaxonomy)
  globalTaxonomy


proc `==`*(a, b: Taxon): bool =
  # treat nil as equivalent to UnknownThing (id == 0)
  if a.isNil or b.isNil or a.id == 0 or b.id == 0:
    (a.isNil or a.id == 0) and (b.isNil or b.id == 0)
  else:
    a.id == b.id

proc `==`*(a, b: seq[Taxon]): bool =
  result = a.len == b.len
  if result:
    for i in 0 ..< a.len:
      if a[i] != b[i]:
        return false


proc hash*(a: Taxon): Hash =
  if a.isNil:
    0.hash
  else:
    a.id.hash

proc `$`*(a: Taxon): string =
  if a == nil:
    "nil"
  else:
    a.namespace.replace(" ", "_") & "." & a.name.replace(" ", "_")

proc `$`*(a: seq[Taxon]): string =
  result = "["
  for s in a:
    result.add($s)
    result.add(",")
  result.add("]")

proc normalizeTaxonStr(s: string): string =
  var prevPunctOrSpaceOrPipe = false
  for i in 0 ..< s.len:
    let c = s[i]
    if not prevPunctOrSpaceOrPipe and i != 0 and c.isUpperAscii:
      result.add(' ')
    result.add(c.toLowerAscii)
    prevPunctOrSpaceOrPipe = (c == '.' or c == ' ' or c == '|')

proc normalizeTaxonStrCompileTime(s: string): string {.compiletime.} =
  var prevPunctOrSpace = false
  for i in 0 ..< s.len:
    let c = s[i]
    if not prevPunctOrSpace and i != 0 and c.isUpperAscii:
      result.add(' ')
    result.add(c.toLowerAscii)
    prevPunctOrSpace = (c == '.' or c == ' ')

proc displayName*(t: Taxon): string =
  if t.isNil:
    result = "Unknown"
  else:
    result = t.name
    for i in 0 ..< result.len:
      if i == 0 or result[i-1] == ' ':
        result[i] = result[i].toUpperAscii

proc taxon*(t: ref Taxonomy, namespace: string, name: string, warnOnAbsence: bool = true): Taxon {.gcsafe.} =
  let name = normalizeTaxonStr(name)
  let namespace = normalizeTaxonStr(namespace)
  result = t.taxonsByNameAndNamespace.getOrDefault((namespace, name), UnknownThing)
  if result == UnknownThing:
    if namespace != RootNamespace:
      let sepIndex = namespace.rfind(".")
      if sepIndex != -1:
        let parentNamespace = namespace[0 ..< sepIndex]
        result = t.taxon(parentNamespace, name, warnOnAbsence)
      else:
        let parentNamespace = t.namespaceParents.getOrDefault(namespace, RootNamespace)
        result = t.taxon(parentNamespace, name, warnOnAbsence)
  if warnOnAbsence and result == UnknownThing:
    writeStackTrace()
    warn &"Unresolveable taxon {namespace}.{name}"



proc taxon*(t: ref Taxonomy, name: string): Taxon =
  taxon(t, RootNamespace, name)

proc maybeTaxon*(namespace: string, name: string): Option[Taxon] =
  let res = getGlobalTaxonomy().taxon(namespace, name, false)
  if res == UnknownThing:
    none(Taxon)
  else:
    some(res)

proc taxon*(namespace: string, name: string): Taxon =
  getGlobalTaxonomy().taxon(namespace, name)

proc taxon*(name: string): Taxon =
  getGlobalTaxonomy().taxon(name)

# Higher performance function that can assume the name and namespace are fully qualified and well formed
proc taxonAlreadyNormalized(namespace: string, name: string): Taxon =
  getGlobalTaxonomy().taxonsByNameAndNamespace.getOrDefault((namespace, name), UnknownThing)

proc qualifiedTaxon*(nameExpr: string): Taxon =
  let sections = nameExpr.rsplit('.', 1)
  if sections.len == 1:
    taxon(sections[0])
  else:
    taxon(sections[0], sections[1])

# Attempts to find a taxon matching the given expression. Will search across namespaces if a namespace
# is not part of the expression
proc findTaxon*(taxonomy: ref Taxonomy, nameExpr: string): Taxon =
  let sections = nameExpr.rsplit('.', 1)
  if sections.len == 1:
    let possibleTaxons = taxonomy.taxonsByName.getOrDefault(normalizeTaxonStr(sections[0]))
    if possibleTaxons.len == 1:
      possibleTaxons[0]
    elif possibleTaxons.len == 0:
      UnknownThing
    else:
      warn &"Multiple taxons matching expression : {nameExpr} picking arbitrarily"
      possibleTaxons[0]
  else:
    taxon(sections[0], sections[1])

proc findTaxon*(nameExpr: string): Taxon = findTaxon(getGlobalTaxonomy(), nameExpr)

proc isA*(t: Taxon, q: Taxon): bool =
  t != nil and (t == q or t.parents.anyIt(it.isA(q)))

proc addTaxon(t: ref Taxonomy, namespace: string, name: string, parents: seq[Taxon]): Taxon =
  let namespace = normalizeTaxonStr(namespace)
  let name = normalizeTaxonStr(name)
  t.idCounter.inc
  result = Taxon(id: t.idCounter, name: name, namespace: namespace, parents: parents)
  t.taxonsByNameAndNamespace[(namespace, name)] = result
  t.taxonsByName.mgetOrPut(name, @[]).add(result)


proc addTaxon(t: ref Taxonomy, name: string, parents: seq[Taxon]): Taxon =
  t.addTaxon(RootNamespace, name, parents)

iterator taxons*(t: ref Taxonomy): Taxon =
  for v in t.taxonsByNameAndNamespace.values:
    yield v

iterator taxonsInNamespace*(t: ref Taxonomy, namespace: string): Taxon =
  for v in t.taxons:
    if v.namespace == namespace:
      yield v



proc load(taxonomy: ref Taxonomy, cv: ConfigValue, namespace: string, name: string) =
  let namespace = normalizeTaxonStr(namespace)
  let name = normalizeTaxonStr(name)
  if cv.isObj:
    taxonomy.namespaceParents[name] = namespace
    for k, v in cv.fields:
      taxonomy.load(v, name, k) # if it's an object the name of the object becomes the namespace of its children
  else:
    discard taxonomy.addTaxon(namespace, name, @[])

proc loadParents(taxonomy: ref Taxonomy, cv: ConfigValue, namespace: string, name: string) {.gcsafe.} =
  if cv.isObj:
    for k, v in cv.fields:
      taxonomy.loadParents(v, name, k) # if it's an object the name of the object becomes the namespace of its children
  else:
    let taxon = taxonomy.taxon(namespace, name)
    for p in cv.asArr:
      let parent = taxonomy.taxon(namespace, p.asStr)
      taxon.parents.add(parent)

proc load(taxonomy: ref Taxonomy) {.gcsafe.} =
  when defined(ProjectName):
    let conf = resources.config(&"{ProjectName}/taxonomy.sml")
  else:
    let conf = resources.config("data/taxonomy.sml")
  for k, v in conf["Taxonomy"].fields:
    taxonomy.load(v, RootNamespace, k)
  for k, v in conf["Taxonomy"].fields:
    taxonomy.loadParents(v, RootNamespace, k)


  var taxonSources : seq[string]
  for v in conf["TaxonomySources"].asArr:
    let conf = resources.config(v.asStr)
    if conf["Module"].nonEmpty:
      for f in conf["Module"]["files"].asArr:
        taxonSources.add(f.asStr)
    else:
      taxonSources.add(v.asStr)

  for sourcePath in taxonSources:
    let sourceConf = resources.config(sourcePath)
    for namespace, topLevelV in sourceConf.fields:

      let rootParentName = if namespace.endsWith("ies"):
          normalizeTaxonStr(namespace[0 .. ^4] & "y")
        else:
          normalizeTaxonStr(namespace[0 .. ^2])
      let rootParent = if taxonomy.taxonsByName.contains(rootParentName):
        taxonomy.taxonsByName[rootParentName][0]
      else:
        taxonomy.addTaxon(rootParentName, @[])

      for k, v in topLevelV.fields:
        let name = normalizeTaxonStr(k)
        var parents: seq[Taxon] = @[rootParent]
        for parentK in v["isA"].asArr:
          let parentStr = parentK.asStr
          if parentStr.contains('.'):
            parents.add(taxonomy.findTaxon(parentStr))
          else:
            parents.add(taxonomy.taxon(namespace, parentStr))
        discard taxonomy.addTaxon(namespace, name, parents)

  proc loadProtoTaxon(t: ProtoTaxon) =
    var parents : seq[Taxon]
    for p in t.parents:
      let norm = normalizeTaxonStr(p)
      if taxonomy.taxonsByName.contains(norm):
        parents.add(taxonomy.taxonsByName[norm])
      else:
        let sections = p.split('.')
        if sections.len == 2:
          let namespace = normalizeTaxonStr(sections[0])
          let name = normalizeTaxonStr(sections[1])
          if taxonomy.taxonsByNameAndNamespace.contains((namespace, name)):
            parents.add(taxonomy.taxonsByNameAndNamespace[(namespace, name)])
          else:
            warn &"Could not resolve parent by namespace.name when using custom taxon loader {namespace} : {name}"
        else:
          warn &"Could not resolve parent when using custom taxon loader {p}"
    discard taxonomy.addTaxon(t.namespace, t.name, parents)

  for i in 0 ..< TaxonomyLoaderCount:
    if not TaxonomyLoaders[i].loadStaticTaxons.isNil:
      for t in TaxonomyLoaders[i].loadStaticTaxons():
        loadProtoTaxon(t)

  for v in conf["TaxonomySources"].asArr:
    let sourcePath = v.asStr
    let sourceConf = resources.config(sourcePath)
    for i in 0 ..< TaxonomyLoaderCount:
      if not TaxonomyLoaders[i].loadTaxonsFrom.isNil:
        for t in TaxonomyLoaders[i].loadTaxonsFrom(sourceConf):
          loadProtoTaxon(t)



import macros
macro `†`*(stmt: untyped) : Taxon =
  if stmt.kind == nnkDotExpr:
    let namespace = normalizeTaxonStrCompileTime($stmt[0])
    let taxonStr = normalizeTaxonStrCompileTime($stmt[1])
    quote do:
      taxonAlreadyNormalized(`namespace`, `taxonStr`)
  else:
    let str = $stmt
    quote do:
      taxon(`str`)


when isMainModule:

  import prelude

  echoAssert taxon("BodyParts", "Leg").name == "leg"
  echoAssert taxon("BodyParts", "Leg").namespace == "body parts"
  echoAssert taxon("BodyParts", "Leg").parents == @[taxon("BodyParts", "Appendage")]
  echoAssert taxon("BodyParts", "Leg").isA(† BodyPart) == true

  echoAssert taxon("CardTypes", "FightAnotherDay").name == "fight another day"
  echoAssert taxon("CardTypes", "FightAnotherDay").namespace == "card types"
  echoAssert taxon("CardTypes", "FightAnotherDay").parents[1] == taxon("CardTypes", "MoveCard")
  echoAssert taxon("CardTypes", "FightAnotherDay").parents[0] == taxon("CardType")
  echoAssert taxon("CardTypes", "FightAnotherDay").parents == @[taxon("CardType"), taxon("CardTypes", "MoveCard")]

  echoAssert taxon("CardTypes", "RecklessSmash").name == "reckless smash"
