import regex
import prelude
import noto

export regex
export prelude


template extractMatches*(r: Regex, stmts: untyped): untyped =
   if matchTarget.match(r):
      stmts
      break

proc firstOrEmpty(matchTarget: string, captures: seq[Slice[int]]): string =
   if captures.len > 0:
      matchTarget[captures[0]]
   else:
      ""

template extractMatches*(r: Regex, var1: untyped, stmts: untyped): untyped =
   var rematch: RegexMatch
   if matchTarget.match(r, rematch):
      let `var1` {.inject.} =
         if rematch.group(0).len > 0:
            matchTarget[rematch.group(0)[0]]
         else:
            ""

      stmts
      break

template extractMatches*(r: Regex, var1: untyped, var2: untyped, stmts: untyped): untyped =
   var rematch: RegexMatch
   if matchTarget.match(r, rematch):
      if rematch.groupsCount < 2:
         warn "Attempted to extract 2 matches using regex " & $r & ", but insufficient captures were found"
      let `var1` {.inject.} = firstOrEmpty(matchTarget, rematch.group(0))
      let `var2` {.inject.} = firstOrEmpty(matchTarget, rematch.group(1))
      stmts
      break

template extractMatches*(r: Regex, var1: untyped, var2: untyped, var3: untyped, stmts: untyped): untyped =
   var rematch: RegexMatch
   if matchTarget.match(r, rematch):
      if rematch.groupsCount < 3:
         warn "Attempted to extract 3 matches using regex " & $r & ", but insufficient captures were found"
      let `var1` {.inject.} = firstOrEmpty(matchTarget, rematch.group(0))
      let `var2` {.inject.} = firstOrEmpty(matchTarget, rematch.group(1))
      let `var3` {.inject.} = firstOrEmpty(matchTarget, rematch.group(2))
      stmts
      break

template extractMatches*(r: Regex, var1: untyped, var2: untyped, var3: untyped, var4: untyped, stmts: untyped): untyped =
   var rematch: RegexMatch
   if matchTarget.match(r, rematch):
      if rematch.groupsCount < 4:
         warn "Attempted to extract 4 matches using regex " & $r & ", but insufficient captures were found"
      let `var1` {.inject.} = firstOrEmpty(matchTarget, rematch.group(0))
      let `var2` {.inject.} = firstOrEmpty(matchTarget, rematch.group(1))
      let `var3` {.inject.} = firstOrEmpty(matchTarget, rematch.group(2))
      let `var4` {.inject.} = firstOrEmpty(matchTarget, rematch.group(3))
      stmts
      break

when isMainModule:
   const re1 = re"([0-9]+) from (.*)"

   matcher("10 from bottom right"):
      extractMatches(re1, distance, orientation):
         echo "Distance is " & distance & " orientation is " & orientation
      extractMatches(re1, distance, orientation):
         echo "dupe Distance is " & distance & " orientation is " & orientation

   const expandToParentPattern = re"(?i)expand\s?to\s?parent\(([0-9]+)\)"
   block:
      assert "expandToParent(10)".match(expandToParentPattern)
