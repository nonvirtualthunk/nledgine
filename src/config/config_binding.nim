# import graphics/color
import windowingsystem/rich_text
import worlds/taxonomy
import regex
import tables
import strutils
import sets
import noto
import options
import config_core
import graphics/color
import graphics/image_extras
import macros

type

   BoundValueKind* {.pure.} = enum
      Empty
      Number
      Color
      Text
      RichText
      Taxon
      Seq
      Grid
      Bool
      Image
      Nested

   BoundValue* = object
      case kind*: BoundValueKind
      of BoundValueKind.Empty: discard
      of BoundValueKind.Number: number: float
      of BoundValueKind.Color: color: RGBA
      of BoundValueKind.Text: text: string
      of BoundValueKind.RichText: richText: RichText
      of BoundValueKind.Taxon: taxon: Taxon
      of BoundValueKind.Seq: values*: seq[BoundValue]
      of BoundValueKind.Grid: gridValues*: seq[seq[BoundValue]]
      of BoundValueKind.Bool: truth: bool
      of BoundValueKind.Image: image: ImageLike
      of BoundValueKind.Nested: nestedValues*: ref Table[string, BoundValue]

   Bindable*[T] = object
      value*: T
      bindingPattern: string

   BoundValueResolver* = object
      boundValues*: seq[ref Table[string, BoundValue]]


proc resolveBoundValue(r: ref Table[string, BoundValue], keys: var seq[string], ki: int): BoundValue =
   let key = keys[ki]
   let v = r.getOrDefault(key)
   if ki == keys.len - 1:
      v
   else:
      if v.kind == BoundValueKind.Empty:
         v
      elif v.kind == BoundValueKind.Nested:
         resolveBoundValue(v.nestedValues, keys, ki + 1)
      else:
         warn &"Nested key accessor {keys} referred into a non-nested type: {v.kind} : {v}"
         BoundValue()

proc resolve*(r: BoundValueResolver, key: string): BoundValue =
   var keySections = key.split('.')
   for bv in r.boundValues:
      let subR = resolveBoundValue(bv, keySections, 0)
      if subR.kind != BoundValueKind.Empty:
         return subR

   return BoundValue()


proc boundValueResolver*(t: Table[string, BoundValue]): BoundValueResolver =
   result.boundValues.add(newTable[string, BoundValue]())
   result.boundValues[0][] = t

proc boundValueResolver*(t: ref Table[string, BoundValue]): BoundValueResolver =
   result.boundValues.add(t)

const stringBindingPattern = re("%\\(\\s*([a-zA-Z0-9.]*\\s*)\\)")

converter extractValue*[T](b: Bindable[T]): T = b.value

proc `==`*(a, b: BoundValue): bool =
   if a.kind == b.kind:
      case a.kind:
      of BoundValueKind.Empty: true
      of BoundValueKind.Number: a.number == b.number
      of BoundValueKind.Color: a.color == b.color
      of BoundValueKind.Text: a.text == b.text
      of BoundValueKind.RichText: a.richText == b.richText
      of BoundValueKind.Taxon: a.taxon == b.taxon
      of BoundValueKind.Seq: a.values == b.values
      of BoundValueKind.Grid: a.gridValues == b.gridValues
      of BoundValueKind.Bool: a.truth == b.truth
      of BoundValueKind.Image: a.image == b.image
      of BoundValueKind.Nested: a.nestedValues[] == b.nestedValues[]
   else:
      false

proc bindable*[T](t: T): Bindable[T] = Bindable[T](value: t)

proc bindValueInto*[T](key: string, v: T, bindings: ref Table[string, BoundValue]): bool

proc bindValue*(f: BoundValue): BoundValue = f
proc bindValue*(f: float): BoundValue = BoundValue(kind: BoundValueKind.Number, number: f)
proc bindValue*(f: bool): BoundValue = BoundValue(kind: BoundValueKind.Bool, truth: f)
proc bindValue*(f: string): BoundValue = BoundValue(kind: BoundValueKind.Text, text: f)
proc bindValue*(f: int): BoundValue = BoundValue(kind: BoundValueKind.Number, number: f.toFloat)
proc bindValue*(f: RGBA): BoundValue = BoundValue(kind: BoundValueKind.Color, color: f)
proc bindValue*(f: RichText): BoundValue = BoundValue(kind: BoundValueKind.RichText, richText: f)
proc bindValue*(f: ImageLike): BoundValue = BoundValue(kind: BoundValueKind.Image, image: f)
proc bindValue*(f: Taxon): BoundValue = BoundValue(kind: BoundValueKind.Taxon, taxon: f)
proc bindValue*[K, V](f: ref Table[K, V]): BoundValue = BoundValue(kind: BoundValueKind.Nested, nestedValue: f)
proc bindValue*[K, V](f: Table[K, V]): BoundValue =
   let nt = newTable[string, BoundValue]()
   for k,v in f:
     nt[$k] = bindValue(v)
   BoundValue(kind: BoundValueKind.Nested, nestedValues: nt)

proc bindNestedValue*[T](t: T): BoundValue

macro bindNestedValueMacro[T](v: T, t: typedesc[T], bindings: ref Table[string, BoundValue]) =
   let stmts = newStmtList()
   if t.getType[1].getTypeImpl.len <= 2:
      error("Invalid type to perform implicit nested bindNestedValueMacro: " & t.getType[1].repr, t)
   for field in t.getType[1].getTypeImpl[2]:
      # echo "\"", field[0].repr, "\""
      let fieldName = newIdentNode($field[0].strVal)
      let fieldStr = newLit(field[0].strVal)
      # let fieldAppend = newLit("." & $field[0].strVal)
      stmts.add(quote do:
         when compiles(bindValue(`v`.`fieldName`)):
            `bindings`[`fieldStr`] = bindValue(`v`.`fieldName`)
         else:
            `bindings`[`fieldStr`] = bindNestedValue(`v`.`fieldName`)
      )
   result = stmts

proc bindNestedValue*[T](t: T): BoundValue =
   var subBindings: ref Table[string, BoundValue] = newTable[string, BoundValue]()
   bindNestedValueMacro(t, T, subBindings)
   BoundValue(kind: BoundValueKind.Nested, nestedValues: subBindings)


proc bindValue*[T](f: seq[T]): BoundValue =
   var subValues: seq[BoundValue]
   for v in f:
      when compiles(bindValue(v)):
         subValues.add(bindValue(v))
      elif compiles(asRichText(v)):
         subValues.add(bindValue(asRichText(v)))
      else:
         subValues.add(bindNestedValue(v))
         # {.error: ("seq[" & $T & "] cannot bind nested value").}
   BoundValue(kind: BoundValueKind.Seq, values: subValues)
proc bindValue*[T](f: seq[seq[T]]): BoundValue =
   var subValues: seq[seq[BoundValue]]
   for ss in f:
      var row: seq[BoundValue]
      for v in ss:
         when compiles(bindValue(v)):
            row.add(bindValue(v))
         elif compiles(asRichText(v)):
            row.add(bindValue(asRichText(v)))
         else:
            {.error: ("seq[" & $T & "] cannot bind nested value").}
      subValues.add(row)
   BoundValue(kind: BoundValueKind.Grid, values: subValues)

macro bindValueIntoMacro[T](key: string, v: T, t: typedesc[T], bindings: ref Table[string, BoundValue]) =
   let stmts = newStmtList()
   if t.getType[1].getTypeImpl.len <= 2:
      error("Invalid type to perform implicit nested bindValueInfo: " & t.getType[1].repr, t)
   for field in t.getType[1].getTypeImpl[2]:
      # echo "\"", field[0].repr, "\""
      let fieldName = newIdentNode($field[0].strVal)
      let fieldAppend = newLit("." & $field[0].strVal)
      stmts.add(quote do:
         if bindValueInto(`key` & `fieldAppend`, `v`.`fieldName`, `bindings`):
            result = true
      )
   result = stmts


# template bindValueIntoMacro[T](key : string, v : T, bindings : var Table[string, BoundValue]) = bindValueIntoMacro(key, v, T)

proc bindValueInto*[T](key: string, v: T, bindings: ref Table[string, BoundValue]): bool =
   when v is seq or compiles(bindValue(v)) or compiles(asRichText(v)):
      when v is seq or compiles(bindValue(v)):
         let bv = bindValue(v)
      else:
         let bv = bindValue(asRichText(v))

      var curBindings = bindings
      let sections = key.split('.')
      for ki in 0 ..< sections.len - 1:
         let ks = sections[ki]
         let subR = curBindings.getOrDefault(ks)
         if subR.kind == BoundValueKind.Empty:
            let newNested = BoundValue(kind: BoundValueKind.Nested, nestedValues: newTable[string, BoundValue]())
            curBindings[ks] = newNested
            curBindings = newNested.nestedValues
         elif subR.kind == BoundValueKind.Nested:
            curBindings = subR.nestedValues
         else:
            result = true
            warn &"overwriting a fixed value by indexing further into it: {key} section: {ks}"
            let newNested = BoundValue(kind: BoundValueKind.Nested, nestedValues: newTable[string, BoundValue]())
            curBindings[ks] = newNested
            curBindings = newNested.nestedValues

      let terminalKey = sections[sections.len-1]
      if not curBindings.hasKeyOrPut(terminalKey, bv):
         result = true
      else:
         when not compiles(curBindings[terminalKey] != bv):
            {.error: ("No equality defined for type " & $typeof(bv) & " with T " & $T & " when building out config binding code").}
         if curBindings[terminalKey] != bv:
            curBindings[terminalKey] = bv
            result = true
   elif compiles(isSome(v)): # we're dealing with an option here
      if v.isSome:
         result = bindValueInto(key, v.get, bindings)
      else:
         result = bindValueInto(key, BoundValue(), bindings)
   else:
      bindValueIntoMacro[T](key, v, T, bindings)

proc asString*(bv: BoundValue): string =
   case bv.kind:
   of BoundValueKind.Empty: ""
   of BoundValueKind.Number: $bv.number
   of BoundValueKind.Color: $bv.color
   of BoundValueKind.Text: bv.text
   of BoundValueKind.RichText: "[rich text not supported yet]"
   of BoundValueKind.Taxon: bv.taxon.name.capitalizeAscii
   of BoundValueKind.Seq: "[seqs not supported yet]"
   of BoundValueKind.Grid: "[grids not supported yet]"
   of BoundValueKind.Bool: $bv.truth
   of BoundValueKind.Image: "[images not supported as strings]"
   of BoundValueKind.Nested: "[nested values not supported as strings yest]"

proc extractSimpleBindingPattern(str: string, bindingPattern: var string) =
   var m: RegexMatch
   if not str.match(stringBindingPattern, m):
      warn &"invalid binding pattern \"{bindingPattern}\" from raw str {str}"
   else:
      bindingPattern = str[m.group(0)[0]]


proc readBindableNumFromConfig*[T: int | int32 | float | float32](v: ConfigValue, b: var Bindable[T]) =
   if v.isNumber:
      readInto(v, b.value)
   elif v.isStr:
      extractSimpleBindingPattern(v.asStr, b.bindingPattern)
   else:
      warn &"invalid config type for Bindable[{$T}], was: {v.kind}"

proc readFromConfig*(v: ConfigValue, b: var Bindable[float]) =
   readBindableNumFromConfig[float](v, b)
proc readFromConfig*(v: ConfigValue, b: var Bindable[int]) =
   readBindableNumFromConfig[int](v, b)
proc readFromConfig*(v: ConfigValue, b: var Bindable[float32]) =
   readBindableNumFromConfig[float32](v, b)
proc readFromConfig*(v: ConfigValue, b: var Bindable[int32]) =
   readBindableNumFromConfig[int32](v, b)
proc readFromConfig*[T](v: ConfigValue, b: var Option[Bindable[T]]) =
   if v.isEmpty:
      b = none(Bindable[T])
   else:
      var ret: Bindable[T]
      readInto(v, ret)
      b = some(ret)

proc readFromConfig*(v: ConfigValue, b: var Bindable[bool]) =
   if v.isBool:
      readInto(v, b.value)
   elif v.isStr:
      extractSimpleBindingPattern(v.asStr, b.bindingPattern)
   else:
      warn &"invalid config type for Bindable[{$bool}], was: {v.kind}"

proc readFromConfig*(v: ConfigValue, b: var Bindable[string]) =
   if v.isStr:
      if v.asStr.contains(stringBindingPattern):
         b.bindingPattern = v.asStr
      else:
         b.value = v.asStr
   else:
      b.value = v.asStr

proc readFromConfig*(v: ConfigValue, b: var Bindable[RichText]) =
   if v.isStr:
      if v.asStr.contains(stringBindingPattern):
         b.bindingPattern = v.str
      else:
         b.value = parseRichText(v.asStr)
   else:
      readInto(v, b.value)

proc readFromConfig*(v: ConfigValue, b: var Bindable[RGBA]) =
   if v.isStr:
      if v.asStr.contains(stringBindingPattern):
         extractSimpleBindingPattern(v.asStr, b.bindingPattern)
      else:
         readInto(v, b.value)
   else:
      readInto(v, b.value)

proc readFromConfig*(v: ConfigValue, b: var Bindable[ImageLike]) =
   if v.isStr:
      if v.asStr.contains(stringBindingPattern):
         extractSimpleBindingPattern(v.asStr, b.bindingPattern)
      else:
         readInto(v, b.value)
   else:
      readInto(v, b.value)


proc updateBindingImpl(bindable: var Bindable[string], boundValues: BoundValueResolver): bool =
   var str = ""

   let srcPattern = bindable.bindingPattern
   var cursor = 0
   for match in srcPattern.findAll(stringBindingPattern):
      if match.boundaries.a > cursor:
         str.add(srcPattern[cursor ..< match.boundaries.a])
      # echo "Match: ", match
      for cap in match.group(0):
         # echo "\tcapture: [", bindable.bindingPattern[cap], "]"
         let resolved = boundValues.resolve(srcPattern[cap])
         # echo "resolved value ", resolved
         str.add(resolved.asString)
      cursor = match.boundaries.b+1
   if cursor < srcPattern.len:
      str.add(srcPattern[cursor ..< srcPattern.len])

   if bindable.value != str:
      bindable.value = str
      true
   else:
      false


proc updateBindingImpl(bindable: var Bindable[RichText], boundValues: BoundValueResolver): bool =
   var str = RichText()

   let srcPattern = bindable.bindingPattern
   var cursor = 0
   for match in srcPattern.findAll(stringBindingPattern):
      if match.boundaries.a > cursor:
         str.add(parseRichText(srcPattern[cursor ..< match.boundaries.a]))
      for cap in match.group(0):
         let resolved = boundValues.resolve(srcPattern[cap])
         case resolved.kind:
         of BoundValueKind.Image:
            str.add(richText(resolved.image))
         of BoundValueKind.Text:
            str.add(richText(resolved.text))
         of BoundValueKind.RichText:
            if str.sections.len == 0:
               str = resolved.richText
            else:
               str.add(resolved.richText)
         of BoundValueKind.Bool:
            str.add(richText($resolved.truth))
         of BoundValueKind.Empty:
            discard
         of BoundValueKind.Color:
            str.tint = some(resolved.color)
         of BoundValueKind.Number:
            let num = resolved.number
            if num == num.int.float:
              str.add(richText($resolved.number.int))
            else:
              str.add(richText($resolved.number))
         else:
            warn &"Invalid bound value for rich text section: {resolved.kind}"
      cursor = match.boundaries.b+1
   if cursor < srcPattern.len:
      str.add(parseRichText(srcPattern[cursor ..< srcPattern.len]))

   if bindable.value != str:
      bindable.value = str
      true
   else:
      false

proc updateBindingImpl(bindable: var Bindable[bool], boundValues: BoundValueResolver): bool =
   let bound = boundValues.resolve(bindable.bindingPattern)
   let newValue = case bound.kind:
   of BoundValueKind.Bool:
      some(bound.truth)
   of BoundValueKind.Empty:
      none(bool)
   else:
      warn &"Bound non-boolean value to Bindable[bool]: {bound}"
      none(bool)
   if newValue.isSome and bindable.value != newValue.get:
      bindable.value = newValue.get
      true
   else:
      false

proc updateBindingImpl(bindable: var Bindable[RGBA], boundValues: BoundValueResolver): bool =
   let bound = boundValues.resolve(bindable.bindingPattern)
   let newValue = case bound.kind:
   of BoundValueKind.Color:
      some(bound.color)
   of BoundValueKind.Empty:
      none(RGBA)
   else:
      warn &"Bound non-rgba value to Bindable[RGBA]: {bound}"
      none(RGBA)
   if newValue.isSome and bindable.value != newValue.get:
      bindable.value = newValue.get
      true
   else:
      false

proc updateBindingImpl(bindable: var Bindable[ImageLike], boundValues: BoundValueResolver): bool =
   let bound = boundValues.resolve(bindable.bindingPattern)
   let newValue = case bound.kind:
   of BoundValueKind.Image:
      some(bound.image)
   of BoundValueKind.Empty:
      none(ImageLike)
   else:
      warn &"Bound non-image value to Bindable[ImageLike]: {bound}"
      none(ImageLike)
   if newValue.isSome and bindable.value != newValue.get:
      bindable.value = newValue.get
      true
   else:
      false


proc updateBindingImpl[T: float | float32 | int | int32](bindable: var Bindable[T], boundValues: BoundValueResolver): bool =
   let bound = boundValues.resolve(bindable.bindingPattern)
   let newValue = case bound.kind:
   of BoundValueKind.Number:
      some(bound.number)
   of BoundValueKind.Empty:
      none(float)
   else:
      warn &"Bound non-number value to Bindable[numeric]: {bound}"
      none(float)
   if newValue.isSome and bindable.value != newValue.get.T:
      bindable.value = newValue.get.T
      true
   else:
      false

proc updateBindings*[T](bindable: var Bindable[T], boundValues: BoundValueResolver): bool =
   if bindable.bindingPattern.len > 0:
      updateBindingImpl(bindable, boundValues)
   else:
      false

proc updateBindings*[T](container: var T, boundValues: BoundValueResolver): bool

macro updateBindings*[T](container: var T, t: typedesc[T], boundValues: BoundValueResolver) =
   let stmts = newStmtList()
   for field in t.getType[1].getTypeImpl[2]:
      let fieldName = newIdentNode($field[0].strVal)
      let fieldType = field[1]

      if (fieldType.repr).startsWith("Option") and fieldType[1].repr.startsWith("Bindable"):
         stmts.add(quote do:
            if `container`.`fieldName`.isSome:
               let altered = updateBindings(`container`.`fieldName`.get, boundValues)
               result = result or altered
         )
      # if (fieldType.repr).startsWith("seq"):
      #    stmts.add(quote do:
      #       for i in 0 ..< `container`.`fieldName`.len:
      #          let altered = updateBindings(`container`.`fieldName`[i], boundValues)
      #          result = result or altered
      #    )
      if (fieldType.repr).startsWith("Bindable"):
         stmts.add(quote do:
            let altered = updateBindings(`container`.`fieldName`, boundValues)
            result = result or altered
         )
   result = stmts

proc updateBindings*[T](container: var T, boundValues: BoundValueResolver): bool =
   when compiles(updateBinding(container, boundValues)):
      result = updateBinding(container, boundValues)
   else:
      updateBindings(container, T, boundValues)


when isMainModule:
   import prelude

   var bindableStr = Bindable[string](
      value: "",
      bindingPattern: "here, before %( test.item) : %(someicon) and after %(empty.binding)"
   )
   var bindableInt: Bindable[int]


   let bindings1 = newTable[string, BoundValue]()
   bindings1["test.item"] = bindValue("trinket")
   bindings1["someicon"] = bindValue(3)

   assert updateBindings(bindableStr, BoundValueResolver(boundValues: @[bindings1]))
   echo "Value: ", bindableStr.value

   assert bindableInt.value == 0
   assert not updateBindings(bindableInt, boundValueResolver({"test": bindValue(3)}.toTable))

   let conf = parseConfig("""
      fixedFloat : 1.0
      bindableFloat : %(a.someValue)
      fixedString : "fixed string"
      bindableString : %(a.thirdValue) - %(a.nestedValue.a)
      fixedColor : "rgba(255,0,0,255)"
      bindableColor : %(a.colorValue)
      fixedRichText : "hello"
      bindableRichText : %(a.richBinding) and %(a.thirdValue) and %(a.imageValue)
      optBindable : %(a.colorValue)
   """)

   type BindContainer = object
      nonBindable: string
      fixedFloat: Bindable[float]
      bindableFloat: Bindable[float]
      fixedString: Bindable[string]
      bindableString: Bindable[string]
      fixedColor: Bindable[RGBA]
      bindableColor: Bindable[RGBA]
      fixedRichText: Bindable[RichText]
      bindableRichText: Bindable[RichText]
      optBindable: Option[Bindable[RGBA]]
   defineSimpleReadFromConfig(BindContainer)

   type NestedBindingObject = object
      a: bool

   type BindingObject = object
      someValue: int
      otherValue: float
      thirdValue: string
      nestedValue: NestedBindingObject
      colorValue: RGBA
      richBinding: RichText
      imageValue: ImageLike

   var container: BindContainer
   readInto(conf, container)
   echoAssert container.fixedFloat.value =~= 1.0f
   echoAssert container.bindableFloat.value =~= 0.0f

   assert updateBindings(container.bindableFloat, boundValueResolver({"a": bindValue({"someValue": bindValue(2.0f)}.toTable)}.toTable))

   echoAssert container.bindableFloat.value =~= 2.0f

   let bindingObj = BindingObject(
      someValue: 3,
      otherValue: 1.5,
      thirdValue: "some text",
      nestedValue: NestedBindingObject(
         a: true
      ),
      colorValue: rgba(0.0f, 1.0f, 0.0f, 1.0f),
      richBinding: richText("simple rich text"),
      imageValue: imageLike("fakepath.png")
   )
   let collectedBindings: ref Table[string, BoundValue] = newTable[string, BoundValue]()
   assert bindValueInto("a", bindingObj, collectedBindings)

   assert updateBindings(container, boundValueResolver(collectedBindings))
   # the second time there is no change and it should recognize that
   assert not updateBindings(container, boundValueResolver(collectedBindings))

   # echo "Collected bindings : ", collectedBindings
   echoAssert container.bindableFloat.value =~= 3.0f
   echoAssert container.fixedString.value == "fixed string"
   echoAssert container.bindableString.value == "some text - true"
   echoAssert container.fixedColor.value == rgba(1.0f, 0.0f, 0.0f, 1.0f)
   echoAssert container.bindableColor.value == rgba(0.0f, 1.0f, 0.0f, 1.0f)
   echoAssert container.optBindable.get.value == rgba(0.0f, 1.0f, 0.0f, 1.0f)
