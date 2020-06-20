import worlds/taxonomy
import tables
import macros

type
    Library*[T] = ref object
        values* : Table[Taxon,T]


proc `[]`*[T](lib : Library[T], key : Taxon) : T = lib.values[key]
proc `[]=`*[T](lib : Library[T], key : Taxon, value : T) = lib.values[key] = value


var libraryLoadChannel : Channel[proc() {.gcSafe.}]
libraryLoadChannel.open()
var libraryLoadThread : Thread[void]

createThread(libraryLoadThread, proc() {.gcSafe.} =
    while true:
        let task = libraryLoadChannel.recv
        task()
)

template defineLibrary*[T](loadFn : untyped) = 
    # quote do:
    var libraryRef {.threadvar.} : Library[T]
    var libraryCopyChannel : Channel[Library[T]]
    libraryCopyChannel.open()
    
    proc loadLibraryFn() {.gcsafe.} =
        let res = loadFn
        libraryCopyChannel.send(res)
    libraryLoadChannel.send(loadLibraryFn)

    proc library*(t : typedesc[T]) : Library[T] =
        if libraryRef.isNil:
            libraryRef = libraryCopyChannel.recv
            libraryCopyChannel.send(libraryRef)
        libraryRef

template defineSimpleLibrary*[T](confPath : string, namespace : string) = 
    defineLibrary[T]:
        let lib = new Library[T]

        let confs = config(confPath)
        if confs[namespace].isEmpty:
            echo "Simple library load: config did not have top level value \"", namespace, "\""
        for k,v in confs[namespace]:
            let key = taxon(namespace, k)
            var ri : T
            readInto(v, ri)
            lib[key] = ri

        lib

when isMainModule:

    defineLibrary[int] :
        let lib = new Library[int]
        lib[taxon("CardTypes", "Slash")] = 2
        lib

    echo library(int)[taxon("CardTypes", "Slash")]
    var tmpThread : Thread[void]
    createThread(tmpThread, proc() =
        echo library(int)[taxon("CardTypes", "Slash")]
    )
    
    tmpThread.joinThread