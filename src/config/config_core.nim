import tables
import parseutils
import strutils
import macros
import sequtils
import noto
import glm
import options

type
   ConfigValueKind {.pure.} = enum
      Empty
      String
      Number
      Object
      Array
      Bool

   ConfigValue* = object
      case kind*: ConfigValueKind
      of String: str*: string
      of Number: num*: float64
      of Object: fields*: OrderedTable[string, ConfigValue]
      of Array: values*: seq[ConfigValue]
      of Empty: discard
      of Bool: truth*: bool


   ParseContext = object
      str: string
      cursor: int
      buffer: string

template noAutoLoad* {.pragma.}

let fieldStartCharacters = {':', '{'}
let fieldValueEndCharacters = {'\n', ',', ']'}

macro hoconAssert(ctx: ParseContext, b: typed) =
   result = quote do:
      if not `b`:
         echo "Hocon assertion hit"
         echo ctx.str[0 ..< ctx.cursor], "§", ctx.str[ctx.cursor ..< min(ctx.str.len, ctx.cursor + 10)]
         assert false


proc render(v: ConfigValue, indentation: int): string =
   result = case v.kind:
   of ConfigValueKind.String:
      v.str
   of ConfigValueKind.Number:
      $v.num
   of ConfigValueKind.Empty:
      "Empty Config Value"
   of ConfigValueKind.Bool:
      $v.truth
   of ConfigValueKind.Array:
      var s = "[\n"
      for sub in v.values:
         s &= indent(sub.render(indentation + 1), (indentation+1) * 2)
         s &= "\n"
      s &= indent("]\n", indentation * 2)
      s
   of ConfigValueKind.Object:
      var s = "{\n"
      for k, v in v.fields:
         s &= indent(k, (indentation+1) * 2) & " : " & v.render(indentation+1)
         s &= "\n"
      s &= indent("}\n", indentation * 2)
      s


proc `[]`*(v: ConfigValue, key: string): ConfigValue =
   case v.kind:
   of ConfigValueKind.Object:
      return v.fields.getOrDefault(key, ConfigValue(kind: ConfigValueKind.Empty))
   else:
      return ConfigValue(kind: ConfigValueKind.Empty)

proc `[]`*(v: ConfigValue, index: int): ConfigValue =
   case v.kind:
   of ConfigValueKind.Array:
      return v.values[index]
   else:
      return ConfigValue(kind: ConfigValueKind.Empty)

proc asSeq*(v: ConfigValue): seq[ConfigValue] =
   case v.kind:
   of ConfigValueKind.Array:
      return v.values
   of ConfigValueKind.Object:
      toSeq(v.fields.values)
   of ConfigValueKind.Empty:
      return @[]
   else:
      return @[v]

proc asStr*(v: ConfigValue): string =
   case v.kind:
   of ConfigValueKind.String:
      return v.str
   of ConfigValueKind.Number:
      return $v.num
   else:
      writeStackTrace()
      warn fmt"Cannot get string value for config value : {v}"

proc asStr*(v: ConfigValue, orElse: string): string =
   case v.kind:
   of ConfigValueKind.String:
      return v.str
   of ConfigValueKind.Number:
      return $v.num
   else:
      return orElse

proc asArr*(v: ConfigValue): seq[ConfigValue] =
   v.asSeq


proc asInt*(v: ConfigValue): int =
   case v.kind:
   of ConfigValueKind.Number:
      return int(v.num)
   else:
      warn fmt"Cannot get int value for config value : {v}"

proc asInt*(v: ConfigValue, orElse: int): int =
   case v.kind:
   of ConfigValueKind.Number:
      return int(v.num)
   else:
      orElse

proc asBool*(v: ConfigValue): bool =
   case v.kind:
   of ConfigValueKind.Bool:
      v.truth
   else:
      warn fmt"Cannot get bool value for config value : {v}"
      false

proc asBool*(v: ConfigValue, orElse: bool): bool =
   case v.kind:
   of ConfigValueKind.Bool:
      v.truth
   else:
      orElse

proc asFloat*(v: ConfigValue): float =
   case v.kind:
   of ConfigValueKind.Number:
      return float(v.num)
   else:
      warn fmt"Cannot get float value for config value : {v}"

# proc fields*(v : ConfigValue) : Table[string, ConfigValue] =
#    case v.kind:
#    of ConfigValueKind.Object:
#       return v.fields
#    else:
#       return Table[string, ConfigValue]()

iterator pairs*(v: ConfigValue): tuple[a: string, b: ConfigValue] =
   case v.kind:
   of ConfigValueKind.Object:
      for k, v in v.fields:
         yield (k, v)
   else:
      echo "Invalid type of configvalue to be iterating over by k/v : ", $v

proc isEmpty*(v: ConfigValue): bool =
   return v.kind == ConfigValueKind.Empty

template nonEmpty*(v: ConfigValue): bool =
   not v.isEmpty


proc readFromConfig*(v: ConfigValue, x: var int) =
   if v.nonEmpty:
      x = v.asInt

proc readFromConfig*(v: ConfigValue, x: var int16) =
   if v.nonEmpty:
      x = v.asInt.int16


proc readFromConfig*(v: ConfigValue, x: var uint8) =
   if v.nonEmpty:
      x = v.asInt.uint8

proc readFromConfig*(v: ConfigValue, x: var int32) =
   if v.nonEmpty:
      x = v.asInt.int32

proc readFromConfig*(v: ConfigValue, x: var bool) =
   if v.nonEmpty:
      x = v.asBool

proc readFromConfig*(v: ConfigValue, x: var float) =
   if v.nonEmpty:
      x = v.asFloat

proc readFromConfig*(v: ConfigValue, x: var float32) =
   if v.nonEmpty:
      x = v.asFloat

proc readFromConfig*(v: ConfigValue, x: var string) =
   if v.nonEmpty:
      x = v.asStr

proc readFromConfig*[T](v: ConfigValue, x: var Vec2[T]) =
   if v.nonEmpty:
      let arr = v.asArr
      if arr.len <= 2:
         for i in 0 ..< min(arr.len, 2):
            readFromConfig(arr[i], x[i])
      else:
         warn &"Config value loading into Vec2[{$T}] had incorrect element count : {v}"

proc readFromConfig*[T](v: ConfigValue, x: var Vec3[T]) =
   if v.nonEmpty:
      let arr = v.asArr
      if arr.len <= 3:
         for i in 0 ..< min(arr.len, 3):
            readFromConfig(arr[i], x[i])
      else:
         warn &"Config value loading into Vec3[{$T}] had incorrect element count : {v}"

proc readFromConfig*[T](v: ConfigValue, x: var Vec4[T]) =
   if v.nonEmpty:
      let arr = v.asArr
      if arr.len <= 4:
         for i in 0 ..< min(arr.len, 4):
            readFromConfig(arr[i], x[i])
      else:
         warn &"Config value loading into Vec4[{$T}] had incorrect element count : {v}"

proc readFromConfig*[T](v: ConfigValue, x: var seq[T]) =
   if v.nonEmpty:
      for s in v.asSeq:
         var tmp: T
         s.readInto(tmp)
         x.add(tmp)

proc readFromConfig*[I, T](v: ConfigValue, x: var array[I, T]) =
   if v.nonEmpty:
      for i in 0 ..< I:
         var tmp: T
         s.readInto(tmp)
         x[i] = tmp

proc readFromConfig*[T](v: ConfigValue, x: var set[T]) =
   if v.nonEmpty:
      for s in v.asSeq:
         var tmp: T
         s.readInto(tmp)
         x.incl(tmp)

proc asConf*(str: string): ConfigValue

proc readFromConfig*[K, V](v: ConfigValue, x: var Table[K, V]) =
   if v.nonEmpty:
      for subK, subV in v:
         var tmpK: K
         var tmpV: V
         asConf(subK).readInto(tmpK)
         subV.readInto(tmpV)
         x[tmpK] = tmpV

proc readFromConfig*[K, V](v: ConfigValue, x: var OrderedTable[K, V]) =
   if v.nonEmpty:
      for subK, subV in v:
         var tmpK: K
         var tmpV: V
         asConf(subK).readInto(tmpK)
         subV.readInto(tmpV)
         x[tmpK] = tmpV

proc readFromConfig*[T](v: ConfigValue, x: var Option[T]) =
   if v.nonEmpty:
      var tmp: T
      v.readInto(tmp)
      x = some(tmp)
   else:
      x = none(T)

template readInto*[T](v: ConfigValue, x: var T) =
   if v.nonEmpty:
      when not compiles(readFromConfig(v, x)):
         # error("You must define a readFromConfig(...) implementation for type " & $T)
         {.error: ("Must define readFromConfig for type " & $typeOf(x)).}
      else:
         readFromConfig(v, x)

      when compiles(extraReadFromConfig(v, x)):
         extraReadFromConfig(v, x)

proc readInto*[T](v: ConfigValue, t: typedesc[T]): T =
   readInto(v, result)

macro readFromConfigByField*[T](v: ConfigValue, t: typedesc[T], x: var T) =
   result = newStmtList()
   #   echo getTypeInst(t)[1].repr
   let tDesc = getType(getType(t)[1])

   if tDesc.len <= 2:
      error("Attempted to generate subReadInto for unsupported type " & $tdesc.repr, tdesc)
   for field in t.getType[1].getTypeImpl[2]:
      let fieldName = newIdentNode($field[0].strVal)
      let fieldType = field[1]
      let fieldNameLit = newLit($field[0].strVal)
      result.add(quote do:
         when not hasCustomPragma(`x`.`fieldName`, noAutoLoad):
            let cv = `v`[`fieldNameLit`]
            readInto[`fieldType`](cv, `x`.`fieldName`)
      )

template defineSimpleReadFromConfig*[T](t: typedesc[T]) =
   proc readFromConfig*(cv: ConfigValue, tc: var T) = readFromConfigByField(cv, t, tc)

template readIntoOrElse*[T](cv: ConfigValue, x: var T, defaultV: typed) =
   if cv.isEmpty:
      x = defaultV
   else:
      readInto(cv, x)

proc `$`*(v: ConfigValue): string =
   render(v, 0)

proc peek(ctx: ParseContext, ahead: int = 0): char =
   ctx.str[ctx.cursor + ahead]

proc finished(ctx: ParseContext): bool =
   ctx.cursor >= ctx.str.len

proc advance(ctx: var ParseContext) =
   ctx.cursor += 1

proc next(ctx: var ParseContext): char =
   result = ctx.str[ctx.cursor]
   ctx.cursor += 1
   # skip comments
   if result == '/' and ctx.peek() == '/':
      while ctx.peek() != '\n': ctx.advance()
      result = ctx.next()


proc parseUntil(ctx: var ParseContext, chars: set[char]): string =
   if ctx.peek() == '/' and ctx.peek(1) == '/':
      while ctx.next() != '\n': discard
   ctx.cursor += parseUntil(ctx.str, ctx.buffer, chars, ctx.cursor)
   return ctx.buffer

proc skipWhitespace(ctx: var ParseContext) =
   ctx.cursor += skipWhitespace(ctx.str, ctx.cursor)

proc parseValue(ctx: var ParseContext): ConfigValue {.gcsafe.}

proc parseString(ctx: var ParseContext): ConfigValue =
   hoconAssert ctx, ctx.next() == '"'
   var str = ""
   var escaped = false
   while true:
      let c = ctx.next()
      var shouldEscape = false
      case c:
      of '\\':
         if escaped:
            str.add('\\')
         else:
            shouldEscape = true
      of '"':
         if not escaped:
            break
         else:
            str.add('"')
      else:
         str.add(c)
      escaped = shouldEscape
   result = ConfigValue(kind: ConfigValueKind.String, str: str)

proc parseArray(ctx: var ParseContext): ConfigValue {.gcsafe.} =
   hoconAssert ctx, ctx.next() == '['
   var values: seq[ConfigValue] = @[]
   while true:
      ctx.skipWhitespace()
      if ctx.peek() == ',':
         ctx.advance()
         ctx.skipWhitespace()
      if ctx.peek() == ']':
         ctx.advance()
         break
      let value = parseValue(ctx)
      values.add(value)
   result = ConfigValue(kind: ConfigValueKind.Array, values: values)



proc fillField(fields: var OrderedTable[string, ConfigValue], sections: seq[string], index: int, value: ConfigValue) =
   let key = sections[index]
   if index == sections.len-1:
      fields[key] = value
   else:
      var nested = fields.mgetOrPut(key, ConfigValue(kind: ConfigValueKind.Object))
      if nested.kind != ConfigValueKind.Object:
         warn fmt"dotted key {sections} would nest into non-object child"
      else:
         fillField(fields[key].fields, sections, index + 1, value)


proc parseObj(ctx: var ParseContext, skipEnclosingBraces: bool = false): ConfigValue =
   if not skipEnclosingBraces:
      hoconAssert ctx, ctx.next() == '{'
   ctx.skipWhitespace()
   var fields = OrderedTable[string, ConfigValue]()
   while not ctx.finished and ctx.peek() != '}':
      let fieldName = ctx.parseUntil(fieldStartCharacters).strip()
      if ctx.peek() == ':':
         ctx.advance()
      let fieldValue = parseValue(ctx)

      if fieldName.contains("."):
         let fieldNameSections = fieldName.split(".")
         fillField(fields, fieldNameSections, 0, fieldValue)
      else:
         fields[fieldName] = fieldValue
      ctx.skipWhitespace()
      if not ctx.finished and ctx.peek() == ',':
         ctx.advance()
   if not skipEnclosingBraces:
      ctx.advance() # advance past the end }
   result = ConfigValue(kind: ConfigValueKind.Object, fields: fields)


proc parseValue(ctx: var ParseContext): ConfigValue =
   ctx.skipWhitespace()
   result = case ctx.peek():
   of '{':
      parseObj(ctx)
   of '"':
      parseString(ctx)
   of '[':
      parseArray(ctx)
   else:
      let rawValue = ctx.parseUntil(fieldValueEndCharacters)
      if cmpIgnoreCase(rawValue, "true") == 0:
         ConfigValue(kind: ConfigValueKind.Bool, truth: true)
      elif cmpIgnoreCase(rawValue, "false") == 0:
         ConfigValue(kind: ConfigValueKind.Bool, truth: false)
      else:
         try:
            let f = parseFloat rawValue
            ConfigValue(kind: ConfigValueKind.Number, num: f)
         except ValueError:
            ConfigValue(kind: ConfigValueKind.String, str: rawValue)




proc parseConfig*(str: string): ConfigValue =
   var ctx = ParseContext(str: str, cursor: 0)
   ctx.skipWhitespace()
   parseObj(ctx, true)

proc isObj*(cv: ConfigValue): bool =
   cv.kind == ConfigValueKind.Object

proc isArr*(cv: ConfigValue): bool =
   cv.kind == ConfigValueKind.Array

proc isNumber*(cv: ConfigValue): bool =
   cv.kind == ConfigValueKind.Number

proc isStr*(cv: ConfigValue): bool =
   cv.kind == ConfigValueKind.String

proc isString*(cv: ConfigValue): bool =
   cv.kind == ConfigValueKind.String

proc isBool*(cv: ConfigValue): bool =
   cv.kind == ConfigValueKind.Bool

proc asConf*(str: string): ConfigValue =
   ConfigValue(kind: ConfigValueKind.String, str: str)

proc hasField*(v: ConfigValue, str: string): bool =
   v.isObj and v.fields.contains(str)

when isMainModule:

   let hoconString = """
       firstChild : {
            intKey : 1
            stringKey : "someString"
       }
       secondChild : {
            floatKey : 2.0
            arrayKey : [1,2,3,4]
            nestedObject : {
              a : "quoted"
              b : unquoted
            }
            color : [0.1,0.2,0.3,1.0]
            nestedNoColon {
              x : 1
            }
            nestedArrayObj : [
              {
                x : 2
                y : 3
              },
              {
                x : 4
                y : 6
              }
            ]
       }
       notLoadable : 3
       customLoadTarget : 4
   """

   import prelude

   let parsed = parseConfig(hoconString)
   # echo parseConfig(hoconString)
   assert parsed["firstChild"]["intKey"].asInt == 1
   assert parsed["firstChild"]["stringKey"].asStr == "someString"
   let secondChild = parsed["secondChild"]
   assert secondChild["floatKey"].asFloat == 2.0
   assert secondChild["arrayKey"][0].asInt == 1
   assert secondChild["arrayKey"][1].asInt == 2
   assert secondChild["arrayKey"][2].asInt == 3
   assert secondChild["arrayKey"][3].asInt == 4
   assert secondChild["nestedObject"]["a"].asStr == "quoted"
   assert secondChild["nestedObject"]["b"].asStr == "unquoted"
   assert secondChild["nestedNoColon"]["x"].asInt == 1
   assert secondChild["nestedArrayObj"][0]["x"].asInt == 2
   assert secondChild["nestedArrayObj"][1]["y"].asInt == 6

   type
      TestColor = object
         r, g, b, a: float

      FirstChild = object
         intKey: int
         stringKey: string

      NestedObject = object
         a: string
         b: string

      NestedNoColon = object
         x: int

      NestedArrayObj = object
         x: float
         y: float

      SecondChild = object
         floatKey: float
         arrayKey: seq[int]
         nestedObject: NestedObject
         nestedNoColon: NestedNoColon
         nestedArrayObj: seq[NestedArrayObj]
         color: TestColor

      TopLevel = object
         firstChild: FirstChild
         secondChild: SecondChild
         notLoadable {.noAutoLoad.}: int
         custom: int


   proc `==`(a, b: TestColor): bool =
      a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a

   proc readFromConfig(cv: ConfigValue, tc: var TestColor) =
      tc.r = cv.asArr[0].asFloat
      tc.g = cv.asArr[1].asFloat
      tc.b = cv.asArr[2].asFloat
      tc.a = cv.asArr[3].asFloat

   proc readFromConfig(cv: ConfigValue, tc: var FirstChild) = readFromConfigByField(cv, FirstChild, tc)
   proc readFromConfig(cv: ConfigValue, tc: var NestedArrayObj) = readFromConfigByField(cv, NestedArrayObj, tc)
   proc readFromConfig(cv: ConfigValue, tc: var NestedNoColon) = readFromConfigByField(cv, NestedNoColon, tc)
   proc readFromConfig(cv: ConfigValue, tc: var NestedObject) = readFromConfigByField(cv, NestedObject, tc)
   proc readFromConfig(cv: ConfigValue, tc: var SecondChild) = readFromConfigByField(cv, SecondChild, tc)
   # proc readFromConfig(cv : ConfigValue, tc : var TopLevel) = readFromConfigByField(cv,TopLevel, tc)
   defineSimpleReadFromConfig(TopLevel)

   var c = FirstChild()

   parsed["firstChild"]["intKey"].readInto(c.intKey)
   parsed["firstChild"]["stringKey"].readInto(c.stringKey)
   assert c.intKey == 1
   assert c.stringKey == "someString"

   var d = FirstChild()
   parsed["firstChild"].readInto(d)
   assert d.intKey == 1
   assert d.stringKey == "someString"

   echo "================================="
   proc extraReadFromConfig(v: ConfigValue, tl: var TopLevel) =
      tl.custom = v["customLoadTarget"].asInt

   var tl = TopLevel()
   parsed.readInto(tl)

   assert tl.secondChild.nestedArrayObj[0].x == 2
   assert tl.custom == 4
   assert tl.notLoadable == 0
   echoAssert tl.secondChild.color == TestColor(r: 0.1, g: 0.2, b: 0.3, a: 1.0)

   let defaultCV = ConfigValue()
   assert defaultCV.kind == ConfigValueKind.Empty
