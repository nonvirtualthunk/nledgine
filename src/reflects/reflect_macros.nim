import reflect_types
import macros
import tables



# var dataTypeIndexesByName {.compileTime.} = newTable[string, int]()

macro defineReflection*(t: typedesc) =
    result = newStmtList()

    let tDesc = getType(getType(t)[1])

    let typeDefIdent = genSym(nskType, $t & "TypeDef")

    var initProcStmts = newStmtList()

    var typeDefVarList = newSeq[NimNode]()
    for field in t.getType[1].getTypeImpl[2]:
        let typeName = t
        let fieldName = newIdentNode($field[0].strVal)
        let fieldType = field[1]

        typeDefVarList.add(
            nnkIdentDefs.newTree(
                nnkPostfix.newTree(
                    newIdentNode("*"),
                    fieldName
                ),
                nnkBracketExpr.newTree(
                bindSym("Field"),
                typeName,
                fieldType
                ),
                newEmptyNode()
            )
        )

    let typeDefDecl = nnkTypeSection.newTree(
        nnkTypeDef.newTree(
            nnkPostfix.newTree(
                newIdentNode("*"),
                typeDefIdent,
            ),
            newEmptyNode(),
            nnkRefTy.newTree(
                nnkObjectTy.newTree(
                    newEmptyNode(),
                    nnkOfInherit.newTree(
                    nnkBracketExpr.newTree(
                        bindSym("DataType"),
                        newIdentNode($t)
                    )
                    ),
                    nnkRecList.newTree(
                        typeDefVarList
                    )
                )
            )
        )
    )
    result.add(typeDefDecl)

    var fieldVarSyms = newSeq[NimNode]()
    var fieldIdx = 0
    for field in t.getType[1].getTypeImpl[2]:
        let typeName = t
        let fieldName = newIdentNode($field[0].strVal)
        let fieldType = field[1]
        let fieldNameLit = newLit($field[0].strVal)
        let fieldVarName = genSym(nskLet, $t & "Field" & $field[0].strVal)
        fieldVarSyms.add(fieldVarName)
        let objIdent = newIdentNode("obj")
        let objDotExpr = newDotExpr(objIdent, fieldName)
    
        initProcStmts.add(quote do:
            let `fieldVarName` = new(Field[`typeName`, `fieldType`])
            `fieldVarName`.name = `fieldNameLit`
            `fieldVarName`.index = `fieldIdx`
            `fieldVarName`.setter = proc (`objIdent` :ref `typeName`, value: `fieldType`) = 
                (`objDotExpr` = value)
            `fieldVarName`.getter = proc(`objIdent`:`typeName`) : `fieldType` = 
                `objDotExpr`
            `fieldVarName`.varGetter = proc(`objIdent`:ref `typeName`) : var `fieldType` = 
                result = `objDotExpr`
        )
        fieldIdx.inc

    # var fieldListInitializer = newSeq[NimNode]()
    # var constrValues = @[
    #     typeDefIdent.copy,
    #         nnkExprColonExpr.newTree(
    #         newIdentNode("name"),
    #         newLit($t)
    #         ),
    #         nnkExprColonExpr.newTree(
    #         newIdentNode("index"),
    #         newIntLitNode(dataTypeIndexCounter)
    #         )]

    let typeName = newIdentNode($t)
    # fieldIdx = 0
    # for field in tDesc[2].children:
        
    #     constrValues.add(
    #         nnkExprColonExpr.newTree(
    #             newIdentNode($field),
    #             fieldVarSyms[fieldIdx].copy
    #         ),
    #     )

    #     fieldListInitializer.add(
    #         nnkCast.newTree(
    #                 nnkRefTy.newTree(
    #                 nnkBracketExpr.newTree(
    #                     bindSym("AbstractField"),
    #                     typeName
    #                 )
    #                 ),
    #                 fieldVarSyms[fieldIdx].copy
    #             )
    #     )
    #     fieldIdx.inc

    # constrValues.add(nnkExprColonExpr.newTree(
    #         newIdentNode("fields"),
    #         nnkPrefix.newTree(
    #             newIdentNode("@"),
    #             nnkBracket.newTree(
    #                 fieldListInitializer
    #             )
    #         )
    #         ))

    let footype = newIdentNode($t & "Type")
    # let tdi = quote do:
    #     let `footype` = new(`typeDefIdent`)
    #     `footype`.name = 

    let typelit = newLit($t)
    let idxlit = newIntLitNode(dataTypeIndexCounter)
    let typeDefInst = quote do:
        var `footype`* {.threadvar.} : `typeDefIdent`
    initProcStmts.add(quote do:
        `footype` = new(`typeDefIdent`)
        `footype`.name = `typelit`
        `footype`.index = `idxlit`
    )
    

    # let typeDefInst = nnkLetSection.newTree(
    #     nnkIdentDefs.newTree(
    #     footype,
    #     newEmptyNode(),
    #     nnkObjConstr.newTree(
    #         constrValues
    #     )
    #     )
    # )
    result.add(typeDefInst)

    fieldIdx = 0
    for field in tDesc[2].children:
        let fieldName = newIdentNode($field)
        let fieldSym = fieldVarSyms[fieldIdx]
        initProcStmts.add(
            quote do:
                `fieldSym`.dataType = `footype`
                `footype`.`fieldName` = `fieldSym`
        )
        fieldIdx.inc

    dataTypeIndexCounter.inc

    initProcStmts.add(
        quote do:
            worldCallsForAllTypes.add(proc(world : World) =
                setUpType[`typeName`](world, `fooType`)
            )
            displayWorldCallsForAllTypes.add(proc(world : DisplayWorld) =
                setUpType[`typeName`](world, `fooType`)
            )
    )

    result.add(quote do:
        let initProc = proc() {.gcsafe.} =
            `initProcStmts`
        reflectInitializers.add(initProc)
        initProc()
    )


    result.add(
        quote do:
            proc getDataType* (t : typedesc[`t`]) : DataType[`t`] {.inline.} =
                return `fooType`
    )

    # echo result.copy.repr
    result = result.copy



# import macros
# dumpAstGen:
#     type
#         Foos* =ref object of DataType[int]
#             wat*: int


# template defineReflections*(ts: varargs[untyped]) =
#     for t in ts:
#         defineReflection(t)


macro ifOfType*(x : untyped, t : typed, stmts : untyped) : untyped =
    result = quote do:
        if `x` of `t`:
            let `x` {.inject.} = `x`.`t`
            `stmts`