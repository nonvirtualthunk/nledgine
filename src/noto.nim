
var fineEnabled = false

template fine* (msg : varargs[untyped]) =
    if fineEnabled:
        echo msg

template info* (msg : varargs[untyped]) =
    echo msg

template warn* (msg : varargs[untyped]) =
    write(stdmsg(), "\u001B[33m")
    echo msg
    write(stdmsg(), "\u001B[0m")