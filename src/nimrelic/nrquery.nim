import asyncdispatch, httpclient
import strformat
import uri
import json
import patty
import sequtils
import config
import os
import options
import prelude
import sets
import strutils
import noto
import hashes
import tables
import algorithm

let keys = readConfigFromFile(getHomeDir() & "/.nimrelic/keys")
echo $keys

variantp QValue:
   QFloat(nValue: float)
   QInt(iValue: BiggestInt)
   QString(sValue: string)
   QBoolean(bValue: bool)
   QNil

type
   QResultType* = enum
      Aggregate
      Timeseries
      Events
      Facet

   QEventColumn* = object
      attributeName*: string
      values*: seq[QValue]

   QBucket* = object
      startTimeSeconds*: int
      endTimeSeconds*: int
      results*: seq[QResult]

   QResult* = object
      case kind*: QResultType
      of Aggregate:
         label*: string
         value*: QValue
      of Facet:
         facetAttributes*: seq[string]
         facetedResults*: Table[seq[QValue], seq[QResult]]
      of Events:
         columns*: seq[QEventColumn]
      of Timeseries:
         buckets*: seq[QBucket]

   QResponse* = object
      results*: seq[QResult]
      error*: Option[string]


proc `$`*(v: QValue): string =
   match v:
      QFloat(f): $f
      QInt(i): $i
      QString(s): $s
      QBoolean(b): $b
      QNil: "nil"

proc `hash`*(v: QValue): int =
   match v:
      QFloat(f): hash(f)
      QInt(i): hash(i)
      QString(s): hash(s)
      QBoolean(b): hash(b)
      QNil: hash(nil)

proc asFloat*(v: QValue): float =
   match v:
      QFloat(f): f
      QInt(i): i.float
      QString(s):
         warn &"Trying to interpret string as float: {s}"
         0.0f
      QBoolean(b): 0.0f
      QNil:
         warn &"Trying to interpret nil as float"
         0.0f

proc asArr(jsonNode: JsonNode): seq[JsonNode] =
   if jsonNode == nil:
      @[]
   elif jsonNode.kind == JArray:
      jsonNode.getElems()
   else:
      @[jsonNode]

proc parseValue(json: JsonNode): QValue =
   if json == nil:
      QNil()
   elif json.kind == JsonNodeKind.JString:
      QString(json.getStr)
   elif json.kind == JsonNodeKind.JInt:
      QInt(json.getInt)
   elif json.kind == JsonNodeKind.JFloat:
      QFloat(json.getFloat)
   elif json.kind == JsonNodeKind.JBool:
      QBoolean(json.getBool)
   else:
      QNil()

proc parseAggregates(json: JsonNode, contents: JsonNode): seq[QResult] =
   let funcName = contents{"function"}.getStr()
   let attr = contents{"attribute"}

   for jkey in json.keys():
      if $jkey.toLowerAscii == "percentiles" and $funcName.toLowerAscii == "percentile":
         let thresholdResultsJson = json{jkey}
         for threshold in contents{"thresholds"}.asArr:
            let v = thresholdResultsJson{$threshold.getInt()}.getFloat
            result.add(QResult(
               kind: QResultType.Aggregate,
               label: &"{funcName}({attr.getStr()}, {threshold.getInt()})",
               value: QFloat(v)
            ))

      elif $jkey.toLowerAscii == $funcName.toLowerAscii:
         let label = if attr != nil:
            &"{funcName}({attr.getStr()})"
         else:
            &"{funcName}"
         result.add(QResult(
            kind: QResultType.Aggregate,
            label: label,
            value: parseValue(json{jkey})
         ))

   if result.isEmpty:
      info &"Did not find valid aggregate, funcName: {funcName}"

proc parseEvents(json: JsonNode, rawColumnNames: seq[string]): QResult =
   var columnNames: seq[string] = rawColumnNames
   if columnNames.isEmpty:
      var seenColumns: HashSet[string]
      for elem in json{"events"}.getElems():
         for column in elem.keys():
            if not seenColumns.contains(column):
               seenColumns.incl(column)
               columnNames.add(column)

   var columns = columnNames.mapIt(QEventColumn(attributeName: it))
   for elem in json{"events"}.getElems():
      for column in columns.mitems:
         column.values.add(parseValue(elem{column.attributeName}))

   QResult(
      kind: QResultType.Events,
      columns: columns
   )


proc parseResults(resultsJson: JsonNode, contentsE : seq[JsonNode]) : seq[QResult] =
   let resultsE = resultsJson.getElems()
   for i in 0 ..< contentsE.len:
      let contents = contentsE[i]
      let results = resultsE[i]
      if contents{"function"} != nil:
         if contents{"function"}.getStr != "events":
            result.add(parseAggregates(results, contents))
         else:
            let columns = contents{"columns"}.getElems().mapIt(it.getStr)
            result.add(parseEvents(results, columns))


proc parseTimeseries(timeseriesJson: JsonNode, contentsE: seq[JsonNode]): QResult =
   var buckets : seq[QBucket]
   for bucketJson in timeseriesJson.getElems():
      var bucket : QBucket
      bucket.startTimeSeconds = bucketJson{"beginTimeSeconds"}.getInt()
      bucket.endTimeSeconds = bucketJson{"endTimeSeconds"}.getInt()
      bucket.results = parseResults(bucketJson{"results"}, contentsE)
      buckets.add(bucket)
   buckets = buckets.sortedByIt(it.startTimeSeconds)
   QResult(kind: QResultType.Timeseries, buckets: buckets)

proc parse(json: JsonNode, response: var QResponse) =
   let metadata = json{"metadata"}
   let contentsNode = metadata{"contents"}
   if contentsNode != nil:
      var contentsE = contentsNode.getElems()

      if metadata{"facet"} != nil:
         contentsE = contentsNode{"contents"}.getElems() # why did they nest contents under contents?
         let facetAttributes = metadata{"facet"}.asArr().mapIt(it.getStr)
         let facetedResultsE = json{"facets"}.getElems()
         var facetedResults : Table[seq[QValue], seq[QResult]]
         for i in 0 ..< facetedResultsE.len:
            let facetedResultJson = facetedResultsE[i]
            let facetValues = facetedResultJson{"name"}.asArr().mapIt(parseValue(it))
            let subFacetResults = parseResults(facetedResultJson{"results"}, contentsE)
            let resultsJson = facetedResultJson{"results"}
            facetedResults[facetValues] = subFacetResults
         response.results.add(QResult(kind: QResultType.Facet, facetAttributes: facetAttributes, facetedResults: facetedResults))
      else:
         response.results = parseResults(json{"results"}, contentsE)
   elif metadata{"timeSeries"} != nil:
      response.results = @[parseTimeseries(json{"timeSeries"}, metadata{"timeSeries"}{"contents"}.getElems())]
   elif json{"error"} != nil:
      response.error = some(json{"error"}.getStr)


proc key(account: int): string =
   keys["keys"][$account].asStr

proc query*(account: int, queryStr: string): QResponse =

   var headers = newHttpHeaders({"X-Query-Key": key(account)})

   var syncClient = newHttpClient()
   let response = syncClient.request(
      url = &"https://insights-api.newrelic.com/v1/accounts/{account}/query?nrql={encodeUrl(queryStr)}",
      httpMethod = HttpGet,
      headers = headers)

   let json = parseJson(response.body)

   # let json = parseJson(cannedResponse)
   info &"Raw response\n{json.pretty()}"
   parse(json, result)
   info &"Parsed response\n{$result}"

proc queryAsync*(account: int, queryStr: string): Future[QResponse] {.async.} =
   var client = newAsyncHttpClient()
   var headers = newHttpHeaders({"X-Query-Key": key(account)})

   let response = await client.request(
      url = &"https://insights-api.newrelic.com/v1/accounts/{account}/query?nrql={encodeUrl(queryStr)}",
      httpMethod = HttpGet,
      headers = headers)

   let json = parseJson(await response.body)

   # let json = parseJson(cannedResponse)
   info &"Raw response\n{json.pretty()}"
   parse(json, result)
   info &"Parsed response\n{$result}"


when isMainModule:

   #echo repr query(313870, "SELECT hostname FROM NrqlParser SINCE 1 minute ago")
   discard query(313870, "SELECT count(*), percentile(index, 50) FROM NrqlParser SINCE 5 minute ago TIMESERIES 1 minute")

