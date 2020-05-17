# include reflects/reflect_types
# include reflects/reflect_macros

import reflects/reflect_types
import reflects/reflect_macros

export reflect_types
export reflect_macros

# import sugar
# import sequtils
# import tables

# type 
#     DataType*[C]=ref object of RootRef
#         name* : string
#         index* : int
#         fields* : seq[ref AbstractField[C]]

#     AbstractField*[C]=ref object of RootRef
#         name* : string
#         index* : int

#     Field*[C, T]=ref object of AbstractField[C]
#         setter* : (ref C,T) -> void
#         getter* : (C) -> T
#         dataType* : DataType[C]

#     Operation*[T]=object
#         applicationFunction* : T -> T


#     OperationKind* {.pure.} =enum
#         Add
#         Mul
#         Div
#         Append
#         Remove

#     TaggedOperation*[T] = object
#         case kind : OperationKind
#         of OperationKind.Add, OperationKind.Mul, OperationKind.Div: arg : T
#         of OperationKind.Append, OperationKind.Remove: seqArg : typeof(T[0])


# proc removeAll[T](seq1 : seq[T], seq2 : seq[T]) : seq[T] =
#     result = newSeq[T]
#     for v in seq1:
#         if not seq2.any(v2 => v2 == v):
#             result.add(v)
    

# proc apply[T](operation : Operation[T], target : T) : T = 
#     operation.applicationFunction(target)

# proc apply[T](operation : TaggedOperation[T], value : T) : T =
#     case operation.kind:
#     of OperationKind.Add: value + operation.arg
#     of OperationKind.Mul: value * operation.arg
#     of OperationKind.Div: value / operation.arg
#     of OperationKind.Apped: concat(value, operation.arg)
#     of OperationKind.Remove: removeAll(value, operation.arg)

# proc `+`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a + delta)

# proc `+=`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a + delta)

# proc `-`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a - delta)

# proc `-=`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a - delta)

# proc `*`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a * delta)

# proc `*=`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a * delta)

# proc `/`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a / delta)

# proc `/=`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a / delta)

# proc `reduceBy`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a.reduceBy(delta))

# proc `recoverBy`*[C,T](field : Field[C,T], delta : T) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         a.recoverBy(delta))

# proc append*[C,T,U](field : Field[C,T], value : U) : Operation[T] =
#     Operation[T](applicationFunction : proc(a : T) : T =
#         var tmp = a
#         tmp.add(value)
#         return tmp
#     )







# # import reflect_types
# import macros
# import tables

# var dataTypeIndexCounter {.compileTime.} = 0
# # var dataTypeIndexesByName {.compileTime.} = newTable[string, int]()


# macro defineReflection*(t: typedesc): typed =
#     result = newStmtList()

#     let tDesc = getType(getType(t)[1])

#     let typeDefIdent = genSym(nskType, $t & "TypeDef")

#     var typeDefVarList = newSeq[NimNode]()
#     for field in tDesc[2].children:
#         let typeName = t
#         let fieldName = newIdentNode($field)
#         let fieldType = getType(field).copy

#         typeDefVarList.add(
#             nnkIdentDefs.newTree(
#                 nnkPostfix.newTree(
#                     newIdentNode("*"),
#                     fieldName
#                 ),
#                 nnkBracketExpr.newTree(
#                 bindSym("Field"),
#                 typeName,
#                 fieldType
#                 ),
#                 newEmptyNode()
#             )
#         )

#     let typeDefDecl = nnkTypeSection.newTree(
#         nnkTypeDef.newTree(
#             nnkPostfix.newTree(
#                 newIdentNode("*"),
#                 typeDefIdent,
#             ),
#             newEmptyNode(),
#             nnkRefTy.newTree(
#                 nnkObjectTy.newTree(
#                     newEmptyNode(),
#                     nnkOfInherit.newTree(
#                     nnkBracketExpr.newTree(
#                         bindSym("DataType"),
#                         newIdentNode($t)
#                     )
#                     ),
#                     nnkRecList.newTree(
#                         typeDefVarList
#                     )
#                 )
#             )
#         )
#     )
#     result.add(typeDefDecl)

#     var fieldVarSyms = newSeq[NimNode]()
#     var fieldIdx = 0
#     for field in tDesc[2].children:
#         let typeName = t
#         let fieldName = newIdentNode($field)
#         let fieldNameLit = newLit($field)
#         let fieldType = getType(field).copy
#         let fieldVarName = genSym(nskLet, $t & "Field" & $field)
#         fieldVarSyms.add(fieldVarName)
#         let objIdent = newIdentNode("obj")
#         let objDotExpr = newDotExpr(objIdent, fieldName)

#         result.add(quote do:
#             let `fieldVarName` = new(Field[`typeName`, `fieldType`])
#             `fieldVarName`.name = `fieldNameLit`
#             `fieldVarName`.index = `fieldIdx`
#             `fieldVarName`.setter = proc (`objIdent` :ref `typeName`, value: `fieldType`) = 
#                 (`objDotExpr` = value)
#             `fieldVarName`.getter = proc(`objIdent`:`typeName`) : `fieldType` = 
#                 `objDotExpr`
#         )
#         fieldIdx.inc

#     var fieldListInitializer = newSeq[NimNode]()
#     var constrValues = @[
#         typeDefIdent.copy,
#             nnkExprColonExpr.newTree(
#             newIdentNode("name"),
#             newLit($t)
#             ),
#             nnkExprColonExpr.newTree(
#             newIdentNode("index"),
#             newIntLitNode(dataTypeIndexCounter)
#             )]

#     fieldIdx = 0
#     for field in tDesc[2].children:
#         let typeName = newIdentNode($t)
#         constrValues.add(
#             nnkExprColonExpr.newTree(
#                 newIdentNode($field),
#                 fieldVarSyms[fieldIdx].copy
#             ),
#         )

#         fieldListInitializer.add(
#             nnkCast.newTree(
#                     nnkRefTy.newTree(
#                     nnkBracketExpr.newTree(
#                         bindSym("AbstractField"),
#                         typeName
#                     )
#                     ),
#                     fieldVarSyms[fieldIdx].copy
#                 )
#         )
#         fieldIdx.inc

#     constrValues.add(nnkExprColonExpr.newTree(
#             newIdentNode("fields"),
#             nnkPrefix.newTree(
#                 newIdentNode("@"),
#                 nnkBracket.newTree(
#                     fieldListInitializer
#                 )
#             )
#             ))

#     let footype = newIdentNode($t & "Type")
#     # let tdi = quote do:
#     #     let `footype` = new(`typeDefIdent`)
#     #     `footype`.name = 


#     let typelit = newLit($t)
#     let idxlit = newIntLitNode(dataTypeIndexCounter)
#     let typeDefInst = quote do:
#         let `footype` = new(`typeDefIdent`)
#         `footype`.name = `typelit`
#         `footype`.index = `idxlit`
    

#     # let typeDefInst = nnkLetSection.newTree(
#     #     nnkIdentDefs.newTree(
#     #     footype,
#     #     newEmptyNode(),
#     #     nnkObjConstr.newTree(
#     #         constrValues
#     #     )
#     #     )
#     # )
#     result.add(typeDefInst)



#     fieldIdx = 0
#     for field in tDesc[2].children:
#         let fieldName = newIdentNode($field)
#         let fieldSym = fieldVarSyms[fieldIdx]
#         result.add(
#             quote do:
#                 `fieldSym`.dataType = `footype`
#                 `footype`.`fieldName` = `fieldSym`
#         )
#         fieldIdx.inc

#     dataTypeIndexCounter.inc

#     result = result.copy
#     echo result.copy.repr


# import macros
# dumpAstGen:
#     type
#         Foos* =ref object of DataType[int]
#             wat*: int


# when isMainModule:
#     import macros

#     type
#         Foo* =object
#             i : int
#             s : seq[int]


#     expandMacros:
#         defineReflection(Foo)

#     let test = FooType.i.dataType