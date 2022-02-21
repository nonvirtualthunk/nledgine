import game_prelude
import engines
import windowingsystem/windowingsystem
import graphics/color
import sequtils
import noto

import hex_crawl/game/logic
import hex_crawl/game/data


type
  EncounterUI* = ref object of GraphicsComponent
    encounterStackWatcher : Watcher[seq[Taxon]]
    encounterUI: Widget
    captain: Entity
    activeOptions: seq[EncounterOption]


  PromptB = object
    prompt: string
    text: string
    id: int
    selectColor: RGBA
    promptColor: RGBA


  EncounterB = object
    text: string
    image: Image
    prompts: seq[PromptB]


method initialize(g: EncounterUI, world: LiveWorld, display: DisplayWorld) =
  g.name = "AsciiWindowingSystemComponent"
  g.initializePriority = 0

  g.captain = toSeq(world.entitiesWithData(Captain))[0]
  g.encounterStackWatcher = watch: world.data(g.captain, Captain).encounterStack
  g.encounterUI = display[WindowingSystem].desktop.createChild("EncounterUI","EncounterWidget")

  recur(display[WindowingSystem].desktop)

  let conf = config("hexcrawl/widgets/EncounterUI.sml")


method update(g: EncounterUI, world: LiveWorld, display: DisplayWorld, df: float): seq[DrawCommand] =
  if g.encounterStackWatcher.hasChanged:
    let stack = g.encounterStackWatcher.currentValue
    if stack.isEmpty:
      g.encounterUI.showing = bindable(false)
    else:
      let enc = stack.last
      g.encounterUI.showing = bindable(true)
      let node = library(EncounterNode)[enc]
      var encB = EncounterB()
      encB.text = node.text
      encB.image = image("hexcrawl/encounters/location_images/city_hex_1.png")
      # encB.image = image("hexcrawl/encounters/location_images/gate.png")

      let visOpt = visibleOptions(world, g.captain, enc)
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

      g.encounterUI.bindValue("encounter", encB)

method onEvent(g : EncounterUI, world : LiveWorld, display : DisplayWorld, event : Event) =
  matcher(event):
    extract(KeyRelease, key):
      if key == KeyCode.R:
        info "Reload"
        for widget in display[WindowingSystem].desktop.descendantsMatching((w) => true):
          widget.markForUpdate(RecalculationFlag.Contents)
      elif key == KeyCode.K1:
        let outcome = determineOutcome(world, g.captain, g.activeOptions[0])
        if outcome.text.nonEmpty:
          info outcome.text
        for eff in outcome.effects:
          applyEffect(world, g.captain, eff)
