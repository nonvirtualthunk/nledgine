import reflect

{.experimental.}

# dumpAstGen:
#     type
#         FooTypeDef = object of DataType[Foo]
#             value : Field[Foo,int]

#     let FooFieldValue = new(Field[Foo,typeof(Foo.value)])
#     FooFieldValue.name = "value"
#     FooFieldValue.setter = proc(obj : ref Foo, value : typeof(Foo.value)) =
#             (obj.value = value)
#     FooFieldValue.getter = proc(obj : Foo) : typeof(Foo.value) =
#                 obj.value
#     FooFieldValue.index = 0

#     let FooType = FooTypeDef(
#         name : "Foo",
#         index : dataTypeIndexCounter,
#         value : FooFieldValue[],
#         fields : @[cast[ref AbstractField[Foo]](FooFieldValue)]
#     )
#     dataTypeIndexCounter.inc


when isMainModule:
    import macros
    macro myAssert(arg: untyped): untyped =
        # all node kind identifiers are prefixed with "nnk"
        arg.expectKind nnkInfix
        arg.expectLen 3
        # operator as string literal
        let op  = newLit(" " & arg[0].repr & " ")
        let lhs = arg[1]
        let rhs = arg[2]

        result = quote do:
            if not `arg`:
                raise newException(AssertionError,$`lhs` & `op` & $`rhs`)
        
    import worlds
    type
        Foo* =object
            i : int
            s : seq[int]

    
    defineReflection(Foo)

    type
        DefinedHere* = ref object of DataType[Foo]

    let DH : DefinedHere = new(DefinedHere)

    proc tester[T](dt : DataType[T]) =
        discard

    echo FooType.i.name
    when FooType is DataType[Foo]:
        echo "hello"

    tester(DH)
    tester(FooType)

    let entity = Entity(3)
    var world = createWorld()

    let op = TaggedOperation[seq[int]](kind : OperationKind.Append, seqArg : 3)
    var s1 = @[1,2,3]
    op.apply(s1)
    assert s1 == @[1,2,3,3]

    var foo = new(Foo)
    foo.i = 1
    let field = FooType.i

    let add3 = field += 3
    add3.apply(foo)
    echo foo
    assert foo.i == 4

    let newFoo = new(Foo)
    newFoo.i = 4
    world.attachData(entity, FooType, move(newFoo[]))

    macro data(entity : Entity, t : typedesc) : untyped =
        let dataTypeIdent = newIdentNode($t & "Type")
        result = quote do:
            when compiles(view.data(entity, `dataTypeIdent`)):
                view.data(entity, `dataTypeIdent`)
            else:
                world.data(entity, `dataTypeIdent`)

    let retrieved = world.view.data(entity, FooType)
    myAssert retrieved.i == 4

    let niceRetrieved = entity.data(Foo)
    myAssert niceRetrieved.i == 4

    world.modify(entity, FooType.i += 3)
    myAssert retrieved.i == 7
    assert foo.i == 4

    