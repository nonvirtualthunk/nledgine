import worlds/taxonomy
import tables
import macros
import options

type
  Library*[T] = ref object
    values*: Table[Taxon, T]
    defaultNamespace*: string


proc `[]`*[T](lib: Library[T], key: Taxon): T = lib.values[key]
proc `[]`*[T](lib: Library[T], key: string): T = lib.values[taxon(lib.defaultNamespace, key)]
proc `[]=`*[T](lib: Library[T], key: Taxon, value: T) = lib.values[key] = value
proc contains*[T](lib: Library[T], key: Taxon) = lib.values.contains(key)
proc get*[T](lib: Library[T], key: Taxon): Option[T] =
  if lib.values.contains(key):
    some(lib.values[key])
  else:
    none(T)


var libraryLoadChannel: Channel[proc() {.gcSafe.}]
libraryLoadChannel.open()
var libraryLoadThread: Thread[void]

createThread(libraryLoadThread, proc() {.gcSafe.} =
  while true:
    let task = libraryLoadChannel.recv
    task()
)

template defineLibrary*[T](loadFn: untyped) =
  # quote do:
  var libraryRef {.threadvar.}: Library[T]
  var libraryCopyChannel: Channel[Library[T]]
  libraryCopyChannel.open()


  libraryLoadChannel.send(proc () {.gcsafe.} =
    let res = loadFn
    libraryCopyChannel.send(res))

  proc library*(t: typedesc[T]): Library[T] =
    if libraryRef.isNil:
      libraryRef = libraryCopyChannel.recv
      libraryCopyChannel.send(libraryRef)
    libraryRef

template defineSimpleLibrary*[T](confPaths: seq[string], namespace: string) =
  defineLibrary[T]:
    var lib = new Library[T]
    lib.defaultNamespace = namespace

    
    for confPath in confPaths:
      let confs = config(confPath)
      if confs[namespace].isEmpty:
        echo "Simple library load: config did not have top level value \"", namespace, "\""
      for k, v in confs[namespace]:
        let key = taxon(namespace, k)
        var ri: T
        readInto(v, ri)
        when compiles(ri.taxon):
         ri.taxon = key
        lib[key] = ri

    lib
    
template defineSimpleLibrary*[T](confPath: string, namespace: string) =
  defineSimpleLibrary[T](@[confPath], namespace)

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
