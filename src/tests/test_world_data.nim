import reflect
import worlds

type Foo = object
   a: int

defineDisplayReflection(Foo)


let w = createDisplayWorld()

let a = w.createEntity()

w.attachData(a, Foo(a: 3))

let b = w.copyEntity(a)

assert w.data(a, Foo).a == w.data(b, Foo).a
