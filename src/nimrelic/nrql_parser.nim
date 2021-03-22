import nrql_parser_types
import strutils
#import arxregex
import regex
import noto

const hardNrql = "FROM Foo SELECT filter( percentile(bar,99), WHERE baz > 3.0 ) WHERE str!='test value () here'"


#[
   r"\d+.?\d*":
         return Token(kind: TNUMBER, number: token.token.parseFloat(), colNum: token.colNum, lineNum: token.lineNum)
   r"'.*'":
      return Token(kind: TLITERAL, literal: token.token, colNum: token.colNum, lineNum: token.lineNum)
   r"[a-zA-Z][a-zA-Z0-9]*":
      case token.token.toLowerAscii:
         of "where": return makeToken(TWHERE, token)
         of "from": return makeToken(TFROM, token)
         of "select": return makeToken(TSELECT, token)
         of "timeseries": return makeToken(TTIMESERIES, token)
         else: return Token(kind: TIDENTIFIER, identifier: token.token, colNum: token.colNum, lineNum: token.lineNum)
   ">=": return makeToken(TGTE, token)
   "<=": return makeToken(TLTE, token)
   ">": return makeToken(TGT, token)
   "<": return makeToken(TLT, token)
   "!=": return makeToken(TNEQ, token)
   "=": return makeToken(TEQ, token)
   r"\s":
]#


proc makeToken*(kind: TokenKind) : Token =
   Token(kind: kind)


template tokenCase*(regex: Regex, var1: untyped, stmts: untyped) : auto {.dirty.} =
   if token.kind == TUNKNOWN and nrql.startsWith(regex, i):
      var rematch: RegexMatch
      discard nrql.find(regex, rematch, i)
      let a = nrql[rematch.boundaries]
      let `var1` {.inject.} = a
      token = stmts
      token.startIndex = i
      token.endIndex = i + a.len
      i += a.len

template tokenCaseA*(regex: Regex, stmts: untyped) : auto =
   if token.kind == TUNKNOWN and nrql.startsWith(regex, i):
      var rematch: RegexMatch
      discard nrql.find(regex, rematch, i)
      let tokenVar {.inject.} = nrql[rematch.boundaries]
      token = stmts
      token.startIndex = i
      token.endIndex = i + tokenVar.len
      i += tokenVar.len


template matchTokens(stmts: untyped): auto =
   block:
      stmts


iterator tokenizeNrql*(nrql: string): Token =
   var i = 0

   while i < nrql.len:
      var token = Token(kind: TUNKNOWN)
      matchTokens:
         tokenCase(re"\d+\.?\d*", num):Token(kind: TNUMBER, number: num.parseFloat())
         tokenCaseA(re"(?i)select"): makeToken(TSELECT)
         tokenCaseA(re"(?i)from"): makeToken(TFROM)
         tokenCaseA(re"(?i)where"): makeToken(TWHERE)
         tokenCaseA(re"(?i)timeseries"): makeToken(TTIMESERIES)
         tokenCaseA(re"(?i)since"): makeToken(TSINCE)
         tokenCaseA(re"(?i)until"): makeToken(TUNTIL)
         tokenCaseA(re"(?i)ago"): makeToken(TAGO)
         tokenCaseA(re"(?i)facet"): makeToken(TFACET)
         tokenCaseA(re","): makeToken(TSEPARATOR)
         tokenCaseA(re"\("): makeToken(TLPAREN)
         tokenCaseA(re"\)"): makeToken(TRPAREN)
         tokenCaseA(re">="): makeToken(TGTE)
         tokenCaseA(re"<="): makeToken(TLTE)
         tokenCaseA(re">"): makeToken(TGT)
         tokenCaseA(re"<"): makeToken(TLT)
         tokenCaseA(re"!="): makeToken(TNEQ)
         tokenCaseA(re"="): makeToken(TEQ)
         tokenCaseA(re"\+"): makeToken(TADD)
         tokenCaseA(re"-"): makeToken(TSUB)
         tokenCaseA(re"\*"): makeToken(TMUL)
         tokenCaseA(re"/"): makeToken(TDIV)
         tokenCase(re"'.*?'", literal): Token(kind: TLITERAL, literal: literal[1..<literal.len-1])
         tokenCase(re"[a-zA-Z][a-zA-Z0-9]*", identifier): Token(kind: TIDENTIFIER, identifier: identifier)
         tokenCaseA(re"\s"): makeToken(TIGNORE)

      if token.kind != TUNKNOWN:
         if token.kind != TIGNORE:
            yield token
      else:
         token.unknownChar = nrql[i]
         token.startIndex = i
         token.endIndex = i+1
         yield token
         i.inc

proc tokenizeNrqlSeq*(nrql: string): seq[Token] =
   for t in tokenizeNrql(nrql):
      result.add(t)


when isMainModule:
   for token in tokenizeNrql(hardNrql):
      echo $token
