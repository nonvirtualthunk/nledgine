import game_prelude
import engines
import windowingsystem/windowingsystem
import windowingsystem/rich_text
import graphics/color
import sequtils
import noto
import tactical_ui

import hex_crawl/game/logic
import hex_crawl/game/data


type
  EncounterUI* = ref object of GraphicsComponent
    encounterStackWatcher : Watcher[seq[EncounterElement]]
    encounterUI: Widget
    captain: Entity
    activeOptions: seq[EncounterOption]
    displayOutcome: Option[(Taxon, EncounterOption, EncounterOutcome, ChallengeResult)]
    displayOutcomeWatcher: Watcher[bool]
    pendingChallenges: seq[Challenge]
    challengeResults: seq[ChallengeResult]
    pendingOption: Option[EncounterOption]
    pendingChallengesWatcher: Watcher[int]

  PromptB = object
    prompt: RichText
    text: RichText
    id: int
    selectColor: RGBA
    promptColor: RGBA


  EncounterB = object
    text: RichText
    effectText: RichText
    image: Image
    prompts: seq[PromptB]


method initialize(g: EncounterUI, world: LiveWorld, display: DisplayWorld) =
  g.name = "EncounterUI"
  g.initializePriority = 0

  g.captain = toSeq(world.entitiesWithData(Captain))[0]
  g.encounterStackWatcher = watch: world.data(g.captain, Captain).encounterStack
  g.displayOutcomeWatcher = watch: g.displayOutcome.isSome
  g.pendingChallengesWatcher = watch: g.pendingChallenges.len
  g.encounterUI = display[WindowingSystem].desktop.createChild("EncounterUI","EncounterWidget")


method update(g: EncounterUI, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.encounterStackWatcher.hasChanged or g.displayOutcomeWatcher.hasChanged or g.pendingChallengesWatcher.hasChanged:
    let stack = g.encounterStackWatcher.currentValue
    if stack.isEmpty or g.pendingChallenges.nonEmpty:
      g.encounterUI.showing = bindable(false)
    else:
      g.encounterUI.showing = bindable(true)
      var encB = EncounterB()

      if g.displayOutcome.isSome:
        let (nodeT, option, outcome, challengeResult) = g.displayOutcome.get
        let node = library(EncounterNode)[nodeT]
        g.activeOptions = @[EncounterOption()]

        if outcome.text.nonEmpty:
          encB.text = outcome.text
        else:
          encB.text = node.text

        for eff in outcome.effects:
          if eff.kind != EffectKind.Encounter:
            encB.effectText.add(toRichText(world, eff, g.captain, presentTense  = false))
            encB.effectText.add(richTextVerticalBreak())
        encB.image = image("hexcrawl/test/6g5yccljmag81_smaller.png")


        encB.prompts.add(PromptB(
          prompt: richText("Continue..."),
          id: 1,
          promptColor: White,
          selectColor: White
          ))
      else:
        let enc = stack.last
        if enc.node.isSome:
          let node = library(EncounterNode)[enc.node.get]

          encB.text = node.text
          encB.image = image("hexcrawl/encounters/location_images/city_hex_1.png")

          let visOpt = visibleOptions(world, g.captain, enc.node.get)
          g.activeOptions = visOpt
          for i in 0 ..< visOpt.len:
            let opt = node.options[i]
            let avail = isOptionAvailable(world, g.captain, opt)
            var promptColor = rgba(255,255,255,255)
            var selectColor = rgba(255,255,255,255)
            if not avail:
              promptColor = rgba(150,150,150,255)
              selectColor = rgba(150,150,150,255)

            encB.prompts.add(PromptB(
              prompt: opt.prompt,
              text: opt.text,
              id: (i+1),
              promptColor: promptColor,
              selectColor: selectColor
            ))
        else:
          warn &"Encounter element must have node {enc}"

      g.encounterUI.bindValue("encounter", encB)


proc completeChallenges(g: EncounterUI, world: LiveWorld) =
  let opt = g.pendingOption.get
  let stackTop = g.captain[Captain].encounterStack[^1]

  var challengeResult = if g.challengeResults.isEmpty: ChallengeResult.Success else: g.challengeResults[0]
  for i in 1 ..< g.challengeResults.len: challengeResult = min(challengeResult, g.challengeResults[i])

  let outcome = determineOutcome(world, g.captain, opt, challengeResult)
  var needsContinue = outcome.text.nonEmpty
  for e in outcome.effects:
    if e.kind != EffectKind.Encounter:
      needsContinue = true
    applyEffect(world, g.captain, e)
  if needsContinue:
    g.displayOutcome = some((stackTop.node.get, opt, outcome, challengeResult))

  g.pendingOption = none(EncounterOption)
  g.challengeResults.clear()
  g.pendingChallenges.clear()

proc handleNextPendingChallenge(g: EncounterUI, world: LiveWorld, display: DisplayWorld) =
  if g.pendingChallenges.isEmpty:
    completeChallenges(g, world)
  else:
    let challenge = g.pendingChallenges[0]
    if challenge.kind == ChallengeKind.Combat:
      display[CombatUI].startCombat(world, g.captain, challenge)
    else:
      warn &"Unknown challenge kind, can't handle: {challenge}"


method onEvent(g : EncounterUI, world : LiveWorld, display : DisplayWorld, event : Event) =
  if display[CombatUI].challenge.isNone:
    matcher(event):
      extract(KeyRelease, key, modifiers):
        if key == KeyCode.R and modifiers.ctrl:
          for widget in display[WindowingSystem].desktop.descendantsMatching((w) => true):
            widget.markForUpdate(RecalculationFlag.Contents)
        elif key.numeral.isSome and key.numeral.get > 0 and key.numeral.get <= g.activeOptions.len:
          let optionChosen = key.numeral.get - 1
          let cap = g.captain[Captain]

          if g.displayOutcome.isSome:
            g.displayOutcome = none((Taxon, EncounterOption, EncounterOutcome, ChallengeResult))
          else:
            let stackTop = cap.encounterStack[^1]
            let opt = g.activeOptions[optionChosen]
            for challenge in opt.challenges:
              if challenge.kind == ChallengeKind.Combat:
                g.pendingChallenges.add(challenge)
              else:
                g.challengeResults.add(performChallenge(world, g.captain, challenge).result)

            g.pendingOption = some(opt)
            handleNextPendingChallenge(g, world, display)

