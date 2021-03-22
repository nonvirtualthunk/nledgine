import patty
import strutils

type
   TokenKind* = enum
      TFROM
      TSELECT
      TWHERE
      TTIMESERIES
      TIDENTIFIER
      TUNKNOWN
      TLITERAL
      TNUMBER
      TIGNORE
      TGT
      TGTE
      TLT
      TLTE
      TEQ
      TNEQ
      TSINCE
      TUNTIL
      TAGO
      TFACET
      TSEPARATOR
      TLPAREN
      TRPAREN
      TMUL
      TADD
      TSUB
      TDIV

   Token* = object
      startIndex*: int
      endIndex*: int
      case kind*: TokenKind
      #of TFROM, TSELECT, TWHERE, TTIMESERIES, TIGNORE, TNEQ, TEQ, TLT, TGT, TLTE, TGTE, TUNKNOWN: discard
      of TLITERAL:
         literal*: string
      of TIDENTIFIER:
         identifier*: string
      of TNUMBER:
         number*: float64
      of TUNKNOWN:
         unknownChar*: char
      else:
         discard



proc isKeyword*(tk: Token): bool =
   case tk.kind:
      of TFROM, TSELECT, TWHERE, TTIMESERIES, TFACET, TSINCE, TUNTIL, TAGO: true
      else: false

proc isOperator*(tk: Token): bool =
   case tk.kind:
      of TGT, TGTE, TLT, TLTE, TEQ, TNEQ, TMUL, TSUB, TADD, TDIV: true
      else: false