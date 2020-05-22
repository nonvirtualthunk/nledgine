
var fineEnabled = false

template fine* (msg : varargs[untyped]) =
    if fineEnabled:
        echo msg

template info* (msg : varargs[untyped]) =
    echo msg