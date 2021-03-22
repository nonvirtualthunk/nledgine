import config
import os
import strformat
import strutils
import algorithm
import sequtils
import noto

type
   Query* = object
      queryString*: string

   QueryHistory* = ref QueryHistoryRaw
   QueryHistoryRaw = object
      queries*: seq[Query]
      activeQuery*: Query
      cursor*: int
      rSearchStr*: string
      rSearchResults* : seq[Query]




defineSimpleReadFromConfig(Query)
defineSimpleReadFromConfig(QueryHistoryRaw)

proc readFromConfig*(cv: ConfigValue, v : var QueryHistory) =
   if v == nil:
      v = new QueryHistoryRaw
   readInto(cv, v[])

proc loadQueryHistory*(): QueryHistory =
   result = new QueryHistoryRaw
   result.cursor = -1
   let path = getHomeDir() & ".nimrelic/queryHistory"
   if fileExists(path):
      let cv = readConfigFromFile(path)
      readInto(cv, result[])
      info &"Read in qh:\n{cv}"

proc saveQueryHistory*(qh: QueryHistory) =
   writeFile(getHomeDir() & ".nimrelic/queryHistory", $writeToConfig(qh[]))

proc queryAtCursor*(qh: QueryHistory) : Query =
   if qh.cursor < 0 or qh.cursor >= qh.queries.len:
      qh.activeQuery
   else:
      qh.queries[qh.queries.len - 1 - qh.cursor]


proc moveCursorBack*(qh: QueryHistory) : Query =
   qh.cursor = min(qh.cursor + 1, qh.queries.len-1)
   qh.queryAtCursor

proc moveCursorForward*(qh: QueryHistory) : Query =
   qh.cursor = max(qh.cursor - 1, -1)
   qh.queryAtCursor



proc recordQuery*(qh: QueryHistory, qs: string) =
   if qh.queries.len == 0 or qh.queries[qh.queries.len - 1].queryString != qs:
      qh.queries.add(Query(queryString: qs))
   qh.cursor = -1
   qh.activeQuery = Query()

proc setActiveQuery*(qh: QueryHistory, qs: string) =
   qh.activeQuery.queryString = qs

proc rMatches*(q: Query, str: string) : bool =
   var qi = 0
   for c in str:
      var found = false
      while qi < q.queryString.len:
         qi.inc
         if q.queryString[qi].toLowerAscii == c:
            found = true
            break

      if not found:
         return false
   true



proc rSearch*(qh: QueryHistory, str: string) : seq[Query] =
   if str.startsWith(qh.rSearchStr):
      qh.rSearchResults = qh.rSearchResults.filterIt(it.rMatches(str))
   else:
      qh.rSearchResults = qh.queries.filterIt(it.rMatches(str))
   qh.rSearchStr = str
   qh.rSearchResults


#proc readFromConfig*(cv : ConfigValue, v : var QueryHistory) =