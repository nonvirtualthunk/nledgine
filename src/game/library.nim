import worlds/taxonomy
import tables
import macros
import options
import noto
import sugar

export tables

type
  Library*[T] = ref object
    values*: OrderedTable[Taxon, ref T]
    seqValues: seq[ref T]
    seqIndexes: Table[Taxon, int]
    defaultNamespace*: string

  LibraryID* = distinct uint32

  LibraryTaxon* = object
    taxon*: Taxon
    id*: LibraryID

proc `==`*(a, b: LibraryID): bool {.borrow.}
proc id*[T](lib: Library[T], key: Taxon) : LibraryID =
  let idx = lib.seqIndexes.getOrDefault(key, -1)
  if idx == -1:
    warn &"Attempted to look up id for {key} but not present in library, valid values were:"
    for k,v  in lib.seqIndexes:
      warn &"\t{k}"
  LibraryID(idx)
proc libTaxon*[T](lib: Library[T], key: Taxon): LibraryTaxon = LibraryTaxon(taxon: key, id: lib.id(key))
proc libraryTaxon*[T](lib: Library[T], key: Taxon): LibraryTaxon = LibraryTaxon(taxon: key, id: lib.id(key))
proc `$`*(id: LibraryID): string = "LibraryID(" & $id.uint32 & ")"

proc `[]`*[T](lib: Library[T], key: Taxon): ref T = lib.values[key]
proc `[]`*[T](lib: Library[T], id: LibraryID): ref T = lib.seqValues[id.int]
proc `[]`*[T](lib: Library[T], key: var LibraryTaxon): ref T =
  if key.id.uint32 == 0:
    key.id = lib.id(key.taxon)
  lib[key.id]
proc `[]`*[T](lib: Library[T], key: string): ref T = lib.values[taxon(lib.defaultNamespace, key)]
proc `[]=`*[T](lib: Library[T], key: Taxon, value: ref T) = lib.values[key] = value
proc contains*[T](lib: Library[T], key: Taxon) = lib.values.contains(key)
proc get*[T](lib: Library[T], key: Taxon): Option[ref T] =
  if lib.values.contains(key):
    some(lib.values[key])
  else:
    none(ref T)

proc getOrDefault*[T](lib: Library[T], key: Taxon, fallback: Taxon, warnOnMissing: bool = true): ref T =
  if lib.values.contains(key):
    lib.values[key]
  else:
    if warnOnMissing:
      warn &"Could not find {key} in library for {$T}, falling back to default {fallback}"
    if lib.values.contains(fallback):
      lib.values[fallback]
    else:
      warn &"\tFallback not present either, returning nil"
      nil

proc `==`*(a: LibraryTaxon, b: Taxon): bool =
  a.taxon == b


converter toTaxon*(k: LibraryTaxon): Taxon = k.taxon
# converter fromTaxon*(t: Taxon): LibraryTaxon = LibraryTaxon(taxon: t)



iterator pairs*[T](lib: Library[T]) : (Taxon, ref T) =
  for k,v in lib.values:
    yield (k,v)

iterator pairsById*[T](lib: Library[T]) : (LibraryID, ref T) =
  var i = 0
  for v in lib.seqValues:
    if i != 0:
      yield (LibraryID(i), v)
    i.inc

# length of the id space of the library (including the 0 -> nil mapping)
proc maxID*[T](lib: Library[T]) : LibraryID =
  LibraryID(lib.seqValues.len-1)

var libraryLoadChannel: Channel[proc() {.gcSafe.}]
libraryLoadChannel.open()
var libraryLoadThread: Thread[void]

createThread(libraryLoadThread, proc() {.gcSafe.} =
  while true:
    let task = libraryLoadChannel.recv
    task()
)

proc `[]`*[T](s : seq[T], l : LibraryTaxon): T = s[l.id.uint32]
proc `[]`*[T](s : var seq[T], l : LibraryTaxon): var T = s[l.id.uint32]

template defineLibrary*[T](loadFn: untyped) =
  # quote do:
  var libraryRef {.threadvar.}: Library[T]
  var libraryCopyChannel: Channel[Library[T]]
  libraryCopyChannel.open()


  const typeStr = repr(T)
  libraryLoadChannel.send(proc () {.gcsafe.} =
    noto.setContext("Library[" & typeStr & "].load()")
    let res = loadFn
    noto.unsetContext()

    res.seqValues.add(nil)
    for k,v in res.values:
      res.seqIndexes[k] = res.seqValues.len
      res.seqValues.add(v)
    libraryCopyChannel.send(res))

  proc library*(t: typedesc[T]): Library[T] =
    if libraryRef.isNil:
      libraryRef = libraryCopyChannel.recv
      libraryCopyChannel.send(libraryRef)
    libraryRef

func noOpLib[T](lib: Library[T]) =
  discard

template defineSimpleLibrary*[T](baseConfPaths: seq[string], namespace: string, postProcess: proc(t: Library[T])) =
  defineLibrary[T]:
    var lib = new Library[T]
    lib.defaultNamespace = namespace

    var confPaths: seq[string]
    for confPath in baseConfPaths:
      let confs = config(confPath)
      if confs["Module"].nonEmpty:
        for p in confs["Module"]["files"].asArr:
          confPaths.add(p.asStr)
      else:
        confPaths.add(confPath)

    for confPath in confPaths:
      let confs = config(confPath)

      if confs[namespace].isEmpty:
        err "Simple library load: config did not have top level value \"" & namespace & "\""
      for k, v in confs[namespace]:
        let key = taxon(namespace, k)
        var ri: ref T = new (typedesc[T])

        when compiles(ri.taxon):
          ri.taxon = key
        elif compiles(ri.identity):
          ri.identity = key
        elif compiles(ri.kind):
          ri.kind = key
        readInto(v, ri[])
        lib[key] = ri

    postProcess(lib)
    lib

template defineSimpleLibrary*[T](confPaths: seq[string], namespace: string) =
  let noop = proc(t: Library[T]) =
    discard
  defineSimpleLibrary(confPaths, namespace, noop)

template defineSimpleLibrary*[T](confPath: string, namespace: string, postProcess: proc(t: Library[T])) =
  defineSimpleLibrary[T](@[confPath], namespace, postProcess)

template defineSimpleLibrary*[T](confPath: string, namespace: string) =
  let noop = proc(t: Library[T]) =
    discard
  defineSimpleLibrary[T](@[confPath], namespace, noop)

when isMainModule:

  defineLibrary[int]:
    let lib = new Library[int]
    lib[taxon("CardTypes", "Slash")] = 2
    lib

  echo library(int)[taxon("CardTypes", "Slash")]
  var tmpThread: Thread[void]
  createThread(tmpThread, proc() =
    echo library(int)[taxon("CardTypes", "Slash")]
  )

  tmpThread.joinThread
