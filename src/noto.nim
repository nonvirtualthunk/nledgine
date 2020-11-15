import strutils
import tables
import strformat
export strformat


const fineEnabled = false

type NotoMessage = object
   message: string
   level: int8
   indentationChange: int8
   originThread: int
   quit: bool

var writeChannel: Channel[NotoMessage]
writeChannel.open()

var notoThread: Thread[bool]

# const threadColors = [102, 105, 108, 117, 145, 77, 31, 194, 223, 101, 148]
const threadColors = [
   "\u001B[38;5;231m",
   "\u001B[38;5;102m",
   "\u001B[38;5;105m",
   "\u001B[38;5;108m",
   "\u001B[38;5;117m",
   "\u001B[38;5;145m",
   "\u001B[38;5;77m",
   "\u001B[38;5;31m",
   "\u001B[38;5;194m",
   "\u001B[38;5;223m",
   "\u001B[38;5;101m",
   "\u001B[38;5;148m", ]

proc notoThreadFunc(b: bool) {.thread.} =
   var indentationByThread: Table[int, int]
   var colorsByThread: Table[int, string]

   while true:
      var msg = writeChannel.recv
      if msg.quit:
         flushFile(stdout)
         break

      indentationByThread[msg.originThread] = indentationByThread.getOrDefault(msg.originThread) + msg.indentationChange
      let indentation = indentationByThread.getOrDefault(msg.originThread)

      let effMessage = if indentation > 0 and msg.message.len > 0:
         msg.message.indent(indentation)
      else:
         msg.message

      if effMessage.len > 0:
         if msg.level == 1:
            echo "\u001B[38;5;184m", effMessage
         if msg.level == 1:
            echo "\u001B[38;5;196m", effMessage
         else:
            if not colorsByThread.hasKey(msg.originThread):
               colorsByThread[msg.originThread] = threadColors[colorsByThread.len]
            echo colorsByThread[msg.originThread], effMessage

createThread(notoThread, notoThreadFunc, true)

proc quit*() =
   writeChannel.send(NotoMessage(quit: true))

proc write(v: string, level: int) =
   discard writeChannel.trySend(NotoMessage(message: v, originThread: getThreadId(), level: level.int8))

template fine*(msg: string) =
   if fineEnabled:
      write(msg, 3)

template info*(msg: string) =
   write(msg, 2)

template info*(enabled: bool, msg: string) =
   if enabled:
      write(msg, 2)

template warn*(msg: string) =
   write(msg, 1)

template err*(msg: string) =
   write(msg, 0)

proc indentLogs*(enabled: bool = true) =
   if enabled:
      discard writeChannel.trySend(NotoMessage(originThread: getThreadId(), indentationChange: 3))

proc unindentLogs*(enabled: bool = true) =
   if enabled:
      discard writeChannel.trySend(NotoMessage(originThread: getThreadId(), indentationChange: -3))

template indentSection*(stmts: untyped) =
   indentLogs()

   let tmp = stmts

   unindentLogs()

   tmp
