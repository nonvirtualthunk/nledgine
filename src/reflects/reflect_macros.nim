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
         `fieldVarName`.setter = proc (`objIdent`: ref `typeName`, value: `fieldType`) =
            (`objDotExpr` = value)
         `fieldVarName`.getter = proc(`objIdent`: `typeName`): `fieldType` =
            `objDotExpr`
         `fieldVarName`.varGetter = proc(`objIdent`: ref `typeName`): var `fieldType` =
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
      var `footype`* {.threadvar.}: `typeDefIdent`
   initProcStmts.add(quote do:
      `footype` = new(`typeDefIdent`)
      `footype`.typeName = `typelit`
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
      worldCallsForAllTypes.add(proc(world: World) =
         setUpType[`typeName`](world, `fooType`)
      )
      displayWorldCallsForAllTypes.add(proc(world: DisplayWorld) =
         setUpType[`typeName`](world, `fooType`)
      )
   )


   result.add(quote do:
      reflectInitializers.add(proc() {.gcsafe.} =
         `initProcStmts`)
      reflectInitializers[reflectInitializers.len-1]()
   )


   result.add(
       quote do:
      proc getDataType*(t: typedesc[`t`]): DataType[`t`] {.inline.} =
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


macro ifOfType*(t: typedesc, x: untyped, stmts: untyped): untyped =
   result = quote do:
      if `x` of `t`:
         let `x` {.inject.} = `x`.`t`
         `stmts`

macro ofType*(x: untyped, t: typed, stmts: untyped): untyped =
   result = quote do:
      if typeTarget of `t`:
         let `x` {.inject.} = typeTarget.`t`
         `stmts`
         break
   # let cond = quote do:
   #     `x` of `t`
   # let body = quote do:
   #     let `x` {.inject.} = `x`.`t`
   #     `stmts`

   # startBranch.add(
   #     newTree(nnkElifBranch, cond, body)
   # )

macro extract*(t: typed, stmts: untyped): untyped =
   result = quote do:
      if typeTarget of `t`:
         `stmts`
         break

macro extract*(t: typed, field1: untyped, stmts: untyped): untyped =
   result = quote do:
      if typeTarget of `t`:
         let `field1` {.inject.} = typeTarget.`t`.`field1`
         `stmts`
         break

macro extract*(t: typed, field1: untyped, field2: untyped, stmts: untyped): untyped =
   result = quote do:
      if typeTarget of `t`:
         let `field1` {.inject.} = typeTarget.`t`.`field1`
         let `field2` {.inject.} = typeTarget.`t`.`field2`
         `stmts`
         break

macro extract*(t: typed, field1: untyped, field2: untyped, field3: untyped, stmts: untyped): untyped =
   result = quote do:
      if typeTarget of `t`:
         let `field1` {.inject.} = typeTarget.`t`.`field1`
         let `field2` {.inject.} = typeTarget.`t`.`field2`
         let `field3` {.inject.} = typeTarget.`t`.`field3`
         `stmts`
         break

macro extract*(t: typed, field1: untyped, field2: untyped, field3: untyped, field4: untyped, stmts: untyped): untyped =
   result = quote do:
      if typeTarget of `t`:
         let `field1` {.inject.} = typeTarget.`t`.`field1`
         let `field2` {.inject.} = typeTarget.`t`.`field2`
         let `field3` {.inject.} = typeTarget.`t`.`field3`
         let `field4` {.inject.} = typeTarget.`t`.`field4`
         `stmts`
         break

template matchType*(value: untyped, stmts: untyped) =
   block:
      let typeTarget {.inject.} = value
      stmts

macro ifSome*(x: untyped, stmts: untyped): untyped =
   result = quote do:
      if `x`.isSome:
         let `x` {.inject.} = `x`.get
         `stmts`

when isMainModule:
   type
      F1 = ref object of RootRef
         i: int

      F2 = ref object of RootRef
         j: int
         k: int


   let f: RootRef = F1()

   matchType(f):
      ofType(f2, F2):
         echo "F2"
      extract(F1, i):
         echo "i : ", i
      ofType(f1, F1):
         echo "F1 : ", f1.i

