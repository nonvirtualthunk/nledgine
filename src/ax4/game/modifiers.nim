import prelude
import noto
import tables
import config
import strutils
import arxregex
import core

type
   ModifierOperation* {.pure.} = enum
      Identity
      Add
      Sub
      Mul
      Div
      Set
      Reduce
      Recover

   Modifier*[T] = object
      operation*: ModifierOperation
      value*: T

proc isIdentity*[T](m: Modifier[T]): bool = m.operation == ModifierOperation.Identity
proc notIdentity*[T](m: Modifier[T]): bool = not isIdentity(m)

proc mergeAdd*[K, V](t1: var Table[K, V], t2: Table[K, V]) =
   for k, v in t2:
      t1[k] = t1.getOrDefault(k) + t2

proc setTo[T, U](a: var T, b: U) =
   a = b

proc apply*[T, U](modifier: Modifier[T], v: var U) =
   case modifier.operation:
   of ModifierOperation.Identity: discard
   of ModifierOperation.Add:
      when compiles(v + modifier.value):
         v = v + modifier.value
      elif compiles(v.add(modifier.value)):
         v.add(modifier.value)
      elif compiles(v.merge(modifier.value)):
         v.mergeAdd(modifier.value)
      else:
         warn &"Add modifier applied to type that does not support it: {$T}, {$U}"
   of ModifierOperation.Sub:
      when compiles(v - modifier.value):
         v = v - modifier.value
      elif compiles(v.removeAll(modifier.value)):
         v.removeAll(modifier.value)
      else:
         warn &"Sub modifier applied to type that does not support it: {$T}"
   of ModifierOperation.Mul:
      when compiles(v * modifier.value):
         v = v * modifier.value
      else:
         warn &"Mul modifier applied to type that does not support it: {$T}"
   of ModifierOperation.Div:
      when compiles(v div modifier.value):
         v = v div modifier.value
      elif compiles(v / modifier.value):
         v = v / modifier.value
      else:
         warn &"Div modifier applied to type that does not support it: {$T}"
   of ModifierOperation.Set:
      when compiles(setTo(v, modifier.value)):
         v = modifier.value
      else:
         warn &"Set modifier applied to type that does not support it: {$T}, {$U}"
   of ModifierOperation.Reduce:
      when compiles(v.reduceBy(modifier.value)):
         v.reduceBy(modifier.value)
      else:
         warn &"Reduce modifier applied to type that does not support it: {$T}"
   of ModifierOperation.Recover:
      when compiles(v.recoverBy(modifier.value)):
         v.recoverBy(modifier.value)
      else:
         warn &"Recover modifier applied to type that does not support it: {$T}"

const modifierRe = re"(?i)([a-z+-]+)\s?(.+)"
proc readFromConfig*[T](cv: ConfigValue, v: var Modifier[T]) =
   if cv.isStr:
      matcher(cv.asStr):
         extractMatches(modifierRe, operationStr, amountStr):
            case operationStr.toLowerAscii:
            of "add", "+": v.operation = ModifierOperation.Add
            of "sub", "-": v.operation = ModifierOperation.Sub
            of "div": v.operation = ModifierOperation.Div
            of "mul": v.operation = ModifierOperation.Mul
            of "set", "setto": v.operation = ModifierOperation.Set
            else: warn &"unsupported operation str in modifier configuration {operationStr} : {amountStr}"

            readInto(amountStr.asConf, v.value)
         warn &"Invalid string format for modifier configuration: {cv.asStr}"
   elif cv.isNumber:
      v.operation = ModifierOperation.Add
      readInto(cv, v.value)
   elif cv.isArr:
      v.operation = ModifierOperation.Add
      readInto(cv, v.value)
   else:
      warn &"Invalid configuration for modifier: {cv}"


proc add*[T](arg: T): Modifier[T] = Modifier[T](operation: ModifierOperation.Add, value: arg)
proc mul*[T](arg: T): Modifier[T] = Modifier[T](operation: ModifierOperation.Mul, value: arg)
proc sub*[T](arg: T): Modifier[T] = Modifier[T](operation: ModifierOperation.Sub, value: arg)
proc reduce*[T](arg: T): Modifier[T] = Modifier[T](operation: ModifierOperation.Reduce, value: arg)
proc recover*[T](arg: T): Modifier[T] = Modifier[T](operation: ModifierOperation.Recover, value: arg)
proc setTo*[T](arg: T): Modifier[T] = Modifier[T](operation: ModifierOperation.Set, value: arg)
