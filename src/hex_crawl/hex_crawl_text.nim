import game/data
import game_prelude
import noto
import game/flags
import prelude
import std/rdstdin
import game/randomness
import game/logic

proc debugPrint*[T](data: ref T) =
  if data != nil:
    info $T & " {"
    indentLogs()
    for k,v in (data[]).fieldPairs:
      when compiles($v):
        info $k & " : " & $v
      else:
        info $k & " : " & repr(v)

    unindentLogs()
    info "}"

# for k,v in library(EncounterNode):
#   info &"{k} :"
#   debugPrint(v)



let world = createLiveWorld()
let captain = createCaptain(world)
captain[Captain].encounterStack = @[EncounterElement(node: some(taxon("Encounters", "SundarsLanding|Initial")))]

const lineLength = 80

proc print(indent: int, str: string) =
  var counter = 0
  var cur = ""
  for c in str:
    cur.add(c)
    counter.inc
    if counter >= (lineLength - indent*4) and (c == ' '):
      for j in 0 ..< indent:
        stdout.write('\t')
      echo cur
      cur = ""
      counter = 0
  if cur != "":
    for j in 0 ..< indent:
      stdout.write('\t')
    echo cur



proc encounter(enc: Taxon) =
  let node = library(EncounterNode)[enc]
  echo ""
  print(0, node.text)
  echo ""

  let visOpt = visibleOptions(world, captain, enc)
  for i in 0 ..< visOpt.len:
    let opt = node.options[i]
    let avail = isOptionAvailable(world, captain, opt)
    if not avail:
      stdout.write("\u001b[31m")
    print(0, &"{i}) {opt.prompt}")
    if opt.text.nonEmpty:
      print(2, &"{opt.text}")

    stdout.write("\u001b[0m")

  var line = ""
  let ok = readLineFromStdin(">", line)
  if ok:
    let i = parseIntOpt(line)
    if i.isSome and i.get < visOpt.len and i.get >= 0:
      let opt = visOpt[i.get]

      let outcome = determineOutcome(world, captain, opt)
      if outcome.text.nonEmpty:
        print(0, outcome.text)

      var encounterBefore = captain[Captain].encounterStack[^1]
      for eff in outcome.effects:
        print(2, $eff)
        applyEffect(world, captain, eff)
        # case eff.kind:
        #   of EffectKind.Encounter:
        #     changedEncounter = true
        #     encounter(library(EncounterNode)[eff.encounterNode])
        #   else:
        #     print(2, $eff)

      if captain[Captain].encounterStack[^1] == encounterBefore:
        echo "Continue..."
        discard readLineFromStdin("Continue...", line)
      encounter(captain[Captain].encounterStack[^1])
    else:
      encounter(captain[Captain].encounterStack[^1])


captain[Flags].flags[† Qualities.Urchin] = 1

encounter(captain[Captain].encounterStack[^1])