import strformat
export strformat

const fineEnabled = false


var writeChannel: Channel[string]
writeChannel.open()

var notoThread: Thread[bool]

proc notoThreadFunc(b: bool) {.thread.} =
   while true:
      let str = writeChannel.recv
      if str == "[!]quit[!]":
         break
      echo str

createThread(notoThread, notoThreadFunc, true)

proc quit*() =
   writeChannel.send("[!]quit[!]")

proc write(v: string) =
   discard writeChannel.trySend(v)

template fine*(msg: string) =
   if fineEnabled:
      write(msg)

template info*(msg: string) =
   write(msg)

template warn*(msg: string) =
   var str = "\u001B[33m"
   str.add(msg)
   str.add("\u001B[0m")
   write(str)
