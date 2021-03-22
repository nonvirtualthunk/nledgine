#[
import nimly
import patty
import strutils
import nrql_parser_types

proc makeToken*(kind: TokenKind, baseToken: LToken) : Token =
   Token(kind: kind, colNum: baseToken.colNum, lineNum: baseToken.lineNum)


niml NrqlLexer[Token]:
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
      return Token(kind: TIGNORE, colNum: token.colNum, lineNum: token.lineNum)
   else:
      return Token(kind: TIGNORE, colNum: token.colNum, lineNum: token.lineNum)



iterator tokenizeNrql*(nrql: string) : Token =
   var lexer = NrqlLexer.newWithString(nrql)
   lexer.ignoreIf = proc(t: Token): bool = t.kind == TokenKind.TIGNORE

   for token in lexer.lexIter:
      yield token

when isMainModule:
   var lexer = NrqlLexer.newWithString("SELECT foo from bar WHERe baz > 3.4 AND biz != 'literal here'")
   lexer.ignoreIf = proc(t: Token): bool = t.kind == TokenKind.TIGNORE

   for token in lexer.lexIter:
      echo token

]#