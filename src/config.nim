import tables
import parseutils
import strutils
import macros
import sequtils
import noto

type
    ConfigValueKind {.pure.} = enum
        Empty
        String
        Number
        Object
        Array
        Bool

    ConfigValue* = object 
        case kind* : ConfigValueKind
        of String : str* : string
        of Number : num* : float64
        of Object : fields* : Table[string, ConfigValue] 
        of Array : values* : seq[ConfigValue]
        of Empty : discard
        of Bool : truth* : bool


    ParseContext = object
        str : string
        cursor : int
        buffer : string

template noAutoLoad* {.pragma.}

let fieldStartCharacters = { ':' , '{' }
let fieldValueEndCharacters = { '\n', ',', ']' }

macro hoconAssert(ctx : ParseContext, b : typed) =
    result = quote do:
        if not `b`:
            echo "Hocon assertion hit"
            echo ctx.str[0 ..< ctx.cursor] , "§", ctx.str[ctx.cursor ..< min(ctx.str.len, ctx.cursor + 10)]
            assert false
    

proc render(v : ConfigValue, indentation : int) : string =
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
        for k,v in v.fields:
            s &= indent(k, (indentation+1) * 2)  & " : " & v.render(indentation+1)
            s &= "\n"
        s &= indent("}\n", indentation * 2)
        s

        
proc `[]`*(v : ConfigValue, key : string) : ConfigValue =
    case v.kind:
    of ConfigValueKind.Object:
        return v.fields.getOrDefault(key, ConfigValue(kind : ConfigValueKind.Empty))
    else:
        return ConfigValue(kind : ConfigValueKind.Empty)

proc `[]`*(v : ConfigValue, index : int) : ConfigValue =
    case v.kind:
    of ConfigValueKind.Array:
        return v.values[index]
    else:
        return ConfigValue(kind : ConfigValueKind.Empty)

proc asSeq*(v : ConfigValue) : seq[ConfigValue] =
    case v.kind:
    of ConfigValueKind.Array:
        return v.values
    of ConfigValueKind.Object:
        toSeq(v.fields.values)
    of ConfigValueKind.Empty:
        return @[]
    else:
        return @[v]

proc asStr*(v : ConfigValue) : string =
    case v.kind:
    of ConfigValueKind.String:
        return v.str
    of ConfigValueKind.Number:
        return $v.num
    else:
        warn "Cannot get string value for config value : ", v

proc asArr*(v : ConfigValue) : seq[ConfigValue] =
    v.asSeq


proc asInt*(v : ConfigValue) : int =
    case v.kind:
    of ConfigValueKind.Number:
        return int(v.num)
    else:
        warn "Cannot get int value for config value : ", v

proc asBool*(v : ConfigValue) : bool =
    case v.kind:
    of ConfigValueKind.Bool:
        v.truth
    else:
        warn "Cannot get bool value for config value : ", v
        false

proc asFloat*(v : ConfigValue) : float =
    case v.kind:
    of ConfigValueKind.Number:
        return float(v.num)
    else:
        warn "Cannot get float value for config value : ", v

# proc fields*(v : ConfigValue) : Table[string, ConfigValue] =
#     case v.kind:
#     of ConfigValueKind.Object:
#         return v.fields
#     else:
#         return Table[string, ConfigValue]()

iterator pairs*(v : ConfigValue) : tuple[a : string, b : ConfigValue] =
    case v.kind:
    of ConfigValueKind.Object:
        for k,v in v.fields:
            yield (k,v)
    else:
        echo "Invalid type of configvalue to be iterating over by k/v : ", $v

proc isEmpty*(v : ConfigValue) : bool =
    return v.kind == ConfigValueKind.Empty

template nonEmpty*(v : ConfigValue) : bool =
    not v.isEmpty


proc readFromConfig*(v : ConfigValue, x : var int) =
    if v.nonEmpty:
        x = v.asInt

proc readFromConfig*(v : ConfigValue, x : var uint8) =
    if v.nonEmpty:
        x = v.asInt.uint8

proc readFromConfig*(v : ConfigValue, x : var int32) =
    if v.nonEmpty:
        x = v.asInt.int32

proc readFromConfig*(v : ConfigValue, x : var bool) =
    if v.nonEmpty:
        x = v.asBool

proc readFromConfig*(v : ConfigValue, x : var float) =
    if v.nonEmpty:
        x = v.asFloat

proc readFromConfig*(v : ConfigValue, x : var string) =
    if v.nonEmpty:
        x = v.asStr

proc readFromConfig*[T](v : ConfigValue, x : var seq[T]) =
    if v.nonEmpty:
        for s in v.asSeq:
            var tmp : T
            s.readInto(tmp)
            x.add(tmp)

proc readFromConfig*[T](v : ConfigValue, x : var set[T]) =
    if v.nonEmpty:
        for s in v.asSeq:
            var tmp : T
            s.readInto(tmp)
            x.add(tmp)

macro subReadInto[T](v : ConfigValue, t : typedesc[T], x : var T) =
    result = newStmtList()
    # echo getTypeInst(t)[1].getImpl.treeRepr
    let tDesc = getType(getType(t)[1])

    for field in tDesc[2].children:
        let fieldName = newIdentNode($field)
        let fieldNameLit = newLit($field)
        result.add(quote do:
            when not hasCustomPragma(`x`.`fieldName`, noAutoLoad):
                let cv = `v`[`fieldNameLit`]
                if cv.nonEmpty:
                    cv.readInto(`x`.`fieldName`)
        )

proc readInto*[T](v : ConfigValue, x : var T) =
    if v.nonEmpty:
        when compiles(readFromConfig(v, x)):
            readFromConfig(v,x)
        else:
            subReadInto(v, T, x)

        when compiles(extraReadFromConfig(v, x)):
            extraReadFromConfig(v, x)

proc `$`*(v : ConfigValue) : string =
    render(v, 0)

proc peek(ctx : ParseContext) : char = 
    ctx.str[ctx.cursor]

proc finished(ctx : ParseContext) : bool =
    ctx.cursor >= ctx.str.len

proc next(ctx : var ParseContext) : char =
    result = ctx.str[ctx.cursor]
    ctx.cursor += 1

proc advance(ctx : var ParseContext) =
    ctx.cursor += 1

proc parseUntil(ctx : var ParseContext, chars : set[char]) : string =
    ctx.cursor += parseUntil(ctx.str, ctx.buffer, chars, ctx.cursor)
    return ctx.buffer

proc skipWhitespace(ctx : var ParseContext) =
    ctx.cursor += skipWhitespace(ctx.str, ctx.cursor)

proc parseValue(ctx : var ParseContext) : ConfigValue {.gcsafe.}

proc parseString(ctx : var ParseContext) : ConfigValue =
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
    result = ConfigValue(kind : ConfigValueKind.String, str : str)
        
proc parseArray(ctx : var ParseContext) : ConfigValue {.gcsafe.} =
    hoconAssert ctx, ctx.next() == '['
    var values : seq[ConfigValue] = @[]
    while true:
        ctx.skipWhitespace()
        if ctx.peek() == ',':
            ctx.advance()
            ctx.skipWhitespace()
        if ctx.peek() == ']':
            ctx.advance()
            break;
        let value = parseValue(ctx)
        values.add(value)
    result = ConfigValue(kind : ConfigValueKind.Array, values : values)

        

proc parseObj(ctx : var ParseContext, skipEnclosingBraces : bool = false) : ConfigValue =
    if not skipEnclosingBraces:
        hoconAssert ctx, ctx.next() == '{'
    ctx.skipWhitespace()
    var fields = Table[string, ConfigValue]()
    while not ctx.finished and ctx.peek() != '}':
        let fieldName = ctx.parseUntil(fieldStartCharacters).strip()
        if ctx.peek() == ':':
            ctx.advance()
        let fieldValue = parseValue(ctx)

        fields[fieldName] = fieldValue
        ctx.skipWhitespace()
        if not ctx.finished and ctx.peek() == ',':
            ctx.advance()
    if not skipEnclosingBraces:
        ctx.advance() # advance past the end }
    result = ConfigValue(kind : ConfigValueKind.Object, fields : fields)
        

proc parseValue(ctx : var ParseContext) : ConfigValue =
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
        try:
            let f = parseFloat rawValue
            ConfigValue(kind : ConfigValueKind.Number, num : f)
        except ValueError:
            ConfigValue(kind : ConfigValueKind.String, str : rawValue)




proc parseConfig*(str : string) : ConfigValue = 
    var ctx = ParseContext(str : str, cursor : 0)
    ctx.skipWhitespace()
    parseObj(ctx, true)

proc isObj*(cv : ConfigValue) : bool =
    cv.kind == ConfigValueKind.Object

proc isArr*(cv : ConfigValue) : bool =
    cv.kind == ConfigValueKind.Array


    
    

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
            r,g,b,a : float

        FirstChild=object
            intKey : int
            stringKey : string

        NestedObject=object
            a : string
            b : string

        NestedNoColon=object
            x : int

        NestedArrayObj=object
            x : float
            y : float

        SecondChild=object
            floatKey : float
            arrayKey : seq[int]
            nestedObject : NestedObject
            nestedNoColon : NestedNoColon
            nestedArrayObj : seq[NestedArrayObj]
            color : TestColor

        TopLevel=object
            firstChild : FirstChild
            secondChild : SecondChild
            notLoadable {.noAutoLoad.} : int
            custom : int


    proc `==`(a,b : TestColor) : bool =
        a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a

    proc readFromConfig(cv : ConfigValue, tc : var TestColor) =
        tc.r = cv.asArr[0].asFloat
        tc.g = cv.asArr[1].asFloat
        tc.b = cv.asArr[2].asFloat
        tc.a = cv.asArr[3].asFloat

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
    proc extraReadFromConfig(v : ConfigValue, tl : var TopLevel) =
        tl.custom = v["customLoadTarget"].asInt

    var tl = TopLevel()
    parsed.readInto(tl)

    assert tl.secondChild.nestedArrayObj[0].x == 2
    assert tl.custom == 4
    assert tl.notLoadable == 0
    echoAssert tl.secondChild.color == TestColor(r : 0.1,g : 0.2,b : 0.3,a : 1.0)

    let defaultCV = ConfigValue()
    assert defaultCV.kind == ConfigValueKind.Empty
