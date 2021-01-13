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

let keys = readConfigFromFile(getHomeDir() & "/.nimrelic/keys")
echo $keys

variantp QValue:
   Float(nValue: float)
   Int(iValue: BiggestInt)
   String(sValue: string)
   Boolean(bValue: bool)
   Nil

type
   QResultType* = enum
      Aggregate
      Timeseries
      Events
      Facet

   QEventColumn* = object
      attributeName*: string
      values*: seq[QValue]

   QResult* = object
      case kind*: QResultType
      of Aggregate:
         label*: string
         value*: QValue
      of Facet:
         facet*: seq[string]
         facetResults*: seq[QResult]
      of Events:
         columns*: seq[QEventColumn]
      of Timeseries:
         discard

   QResponse* = object
      results*: seq[QResult]
      error*: Option[string]


proc `$`*(v: QValue): string =
   match v:
      Float(f): $f
      Int(i): $i
      String(s): $s
      Boolean(b): $b
      Nil: "nil"


proc parseValue(json: JsonNode): QValue =
   if json == nil:
      Nil()
   elif json.kind == JsonNodeKind.JString:
      String(json.getStr)
   elif json.kind == JsonNodeKind.JInt:
      Int(json.getInt)
   elif json.kind == JsonNodeKind.JFloat:
      Float(json.getFloat)
   elif json.kind == JsonNodeKind.JBool:
      Boolean(json.getBool)
   else:
      Nil()

proc parseAggregate(json: JsonNode, funcName: string): QResult =
   for jkey in json.keys():
      if $jkey.toLowerAscii == $funcName.toLowerAscii:
         result = QResult(
            kind: QResultType.Aggregate,
            label: funcName,
            value: parseValue(json{jkey})
         )

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

proc parse(json: JsonNode, response: var QResponse) =
   let metadata = json{"metadata"}
   let contentsNode = metadata{"contents"}
   if contentsNode != nil:
      let contentsE = contentsNode.getElems()


      let resultsE = json{"results"}.getElems()
      for i in 0 ..< contentsE.len:
         let contents = contentsE[i]
         let results = resultsE[i]
         if contents{"function"} != nil:
            if contents{"function"}.getStr != "events":
               response.results.add(parseAggregate(results, contents{"function"}.getStr()))
            else:
               let columns = contents{"columns"}.getElems().mapIt(it.getStr)
               response.results.add(parseEvents(results, columns))
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
   echo "Raw response\n", json.pretty()
   parse(json, result)
   echo "Parsed response\n", $result

proc queryAsync*(account: int, queryStr: string): Future[QResponse] {.async.} =
   var client = newAsyncHttpClient()
   var headers = newHttpHeaders({"X-Query-Key": key(account)})

   let response = await client.request(
      url = &"https://insights-api.newrelic.com/v1/accounts/{account}/query?nrql={encodeUrl(queryStr)}",
      httpMethod = HttpGet,
      headers = headers)

   let json = parseJson(await response.body)

   # let json = parseJson(cannedResponse)
   echo "Raw response\n", json.pretty()
   parse(json, result)
   echo "Parsed response\n", $result


when isMainModule:

   echo repr query(313870, "SELECT hostname FROM NrqlParser SINCE 1 minute ago")
