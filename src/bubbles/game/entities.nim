import game/randomness
import worlds
import game/library
import glm
import graphics/images
import core
import tables
import config
import resources
import sets
import sequtils
import patty
import arxregex
import prelude
import strutils
import graphics/color
import noto
import arxmath
import engines/core_event_types


type
  BubbleColor* {.pure.} = enum
    Red
    Green
    Blue
    Grey
    Black
    Yellow

  BubbleModKind* {.pure.} = enum
    Normal
    Bouncy
    Big
    HighNumber
    Chromophobic
    Chromophilic
    Power
    Juggernaut
    Potency
    WallAverse
    Chain
    Exchange
    Selfish
    Exhaust
    Immovable

  BubbleMod* = object
    kind*: BubbleModKind
    number*: int

  CollisionCondition* {.pure.} = enum
    MatchingColor
    NonMatchingColor
    Moving
    NonMoving
    
  OnCollideEffect* = object
    conditions*: seq[CollisionCondition]
    effects*: seq[PlayerEffect]

  Wall* {.pure.} = enum
    Left
    Right
    Top
    Bottom

  Bubble* = object
    name*: string
    image*: Image
    duration*: Reduceable[int]
    numeralColor*: RGBA
    archetype*: Taxon
    position*: Vec2f
    radius: float32
    velocity*: Vec2f
    number*: int
    maxNumber: int
    color*: BubbleColor
    secondaryColors*: seq[BubbleColor]
    elasticity: float32
    modifiers*: seq[BubbleMod]
    bounceCount*: int
    lastHitWall*: Option[Wall]
    onPopEffects*: seq[OnPopEffect]
    onCollideEffects*: seq[OnCollideEffect]
    onFireEffects*: seq[PlayerEffect]
    inPlayPlayerMods*: seq[CombatantMod]

  Rarity* {.pure.} = enum
    None
    Common
    Uncommon
    Rare


  BubbleArchetype* = object
    name*: string
    image*: Image
    duration*: Reduceable[int]
    numeralColor*: RGBA
    rarity*: Rarity
    maxNumber*: int
    color*: BubbleColor
    secondaryColors*: seq[BubbleColor]
    modifiers*: seq[BubbleMod]
    onPopEffects*: seq[OnPopEffect]
    inPlayPlayerMods*: seq[CombatantMod]
    onCollideEffects*: seq[OnCollideEffect]
    onFireEffects*: seq[PlayerEffect]

  Magazine* = ref object
    bubbles*: seq[Entity]

  Stage* = object
    active*: bool
    bounds*: Rectf
    bubbles*: seq[Entity]
    cannon*: Entity
    linearDrag*: float32
    magazines*: seq[Magazine]
    activeMagazine*: Magazine
    progress*: int
    progressRequired*: Option[int]
    level*: int
    enemies*: seq[Entity]
    fired*: seq[Entity]

  StageDescription* = object
    cannonPosition*: Vec2f
    cannonVelocity*: float
    linearDrag*: float32
    progressRequired*: Option[int]
    level*: int
    makeActive*: bool

  Reward* = object
    bubbles*: seq[Entity]

  Combatant* = object
    name*: string
    image*: Image
    health*: Reduceable[int]
    blockAmount*: int
    modifiers*: seq[CombatantMod]
    externalModifiers*: Table[Entity, seq[CombatantMod]]

  PlayerActionKind* {.pure.} = enum
    Attack
    Block
    Skill

  CombatantModKind* {.pure.} = enum
    Strength
    Dexterity
    Vulnerable
    Weak
    Footwork


  CombatantMod* = object
    kind*: CombatantModKind
    number*: int

  PlayerEffectKind* {.pure.} = enum
    Attack
    Block
    Mod
    EnemyMod
    Bubble
    LoseHealth
    TakeDamage

  BubblePlacement* {.pure.} = enum
    Random
    Fire
    FireFromTop
    RandomMagazine
    ActiveMagazine

  PlayerEffect* = object
    amount*: int
    case kind*: PlayerEffectKind:
      of PlayerEffectKind.Attack:
        noBlockLoss*: bool
      of PlayerEffectKind.Block, PlayerEffectKind.LoseHealth, PlayerEffectKind.TakeDamage:
        discard
      of PlayerEffectKind.Mod, PlayerEffectKind.EnemyMod:
        modifier*: CombatantMod
      of PlayerEffectKind.Bubble:
        bubbleArchetype*: Taxon
        bubblePlacement*: BubblePlacement

  PopCondition* {.pure.} = enum
    FromCollision
    FromDuration

  OnPopEffect* = object
    effects*: seq[PlayerEffect]
    conditions*: seq[PopCondition]

  Player* = object
    bubbles*: seq[Entity]
    pendingRewards*: seq[Reward]
    completedLevel*: int
    actionProgress*: Table[PlayerActionKind, int]
    actionProgressRequired*: Table[PlayerActionKind, int]
    effects*: Table[PlayerActionKind, seq[PlayerEffect]]
    playArea*: Rectf
    seenEnemyGroups*: HashSet[Taxon]


  Cannon* = object
    position*: Vec2f
    direction*: Vec2f
    maxVelocity*: float
    currentVelocityScale*: float

  IntentKind* {.pure.} = enum
    Attack
    Block

  Intent* = object
    effects*: seq[PlayerEffect]
    duration*: Reduceable[int]

  Enemy* = object
    intents*: seq[Intent]
    activeIntent*: Intent

  EnemyGroupEntry* = object
    possibleEnemyKinds*: seq[Taxon]

  EnemyGroup* = object
    enemies*: seq[EnemyGroupEntry]
    difficulty*: int

  EnemyArchetype* = object
    enemyData*: Enemy
    combatantData*: Combatant

  BubbleEvent* = ref object of GameEvent

  CharacterEvent* = ref object of GameEvent

  BubbleMovedEvent* = ref object of BubbleEvent
    stage*: Entity
    bubble*: Entity

  BubbleFiredEvent* = ref object of BubbleEvent
    stage*: Entity
    bubble*: Entity

  BubbleStoppedEvent* = ref object of BubbleEvent
    stage*: Entity
    bubble*: Entity

  BubblePoppedEvent* = ref object of BubbleEvent
    stage*: Entity
    bubble*: Entity

  BubbleCollisionEvent* = ref object of BubbleEvent
    stage*: Entity
    bubbles*: (Entity, Entity)

  WallCollisionEvent* = ref object of BubbleEvent
    stage*: Entity
    bubble*: Entity
    wall*: Wall

  BubblePlacedEvent* = ref object of BubbleEvent
    stage*: Entity
    bubble*: Entity
    placement*: BubblePlacement

  BubbleAddedToMagazineEvent* = ref object of BubbleEvent
    stage*: Entity
    bubble*: Entity

  BubbleCollisionEndEvent* = ref object of BubbleEvent
    stage*: Entity
    bubbles*: (Entity, Entity)

  BubbleRewardCreatedEvent* = ref object of BubbleEvent
    bubble*: Entity

  DamageDealtEvent* = ref object of CharacterEvent
    attacker*: Entity
    defender*: Entity
    damage*: int
    blockedDamage*: int

  HealthLostEvent* = ref object of CharacterEvent
    entity*: Entity
    amount*: int

  BlockGainedEvent* = ref object of CharacterEvent
    entity*: Entity
    blockAmount*: int

  BlockLostEvent* = ref object of CharacterEvent
    entity*: Entity
    blockAmount*: int

  ModifierAppliedEvent* = ref object of CharacterEvent
    entity*: Entity
    modifier*: CombatantMod

  EnemyCreatedEvent* = ref object of CharacterEvent
    entity*: Entity

  IntentChangedEvent* = ref object of CharacterEvent
    entity*: Entity


defineReflection(Bubble)
defineReflection(Stage)
defineReflection(Cannon)
defineReflection(Player)
defineReflection(Enemy)
defineReflection(Combatant)

eventToStr(BubbleFiredEvent)
eventToStr(BubbleMovedEvent)
eventToStr(BubbleStoppedEvent)
eventToStr(BubblePoppedEvent)
eventToStr(BubbleCollisionEvent)
eventToStr(BubbleCollisionEndEvent)
eventToStr(BubbleRewardCreatedEvent)
eventToStr(DamageDealtEvent)
eventToStr(BlockGainedEvent)
eventToStr(EnemyCreatedEvent)
eventToStr(IntentChangedEvent)
eventToStr(ModifierAppliedEvent)
eventToStr(WallCollisionEvent)
eventToStr(BubblePlacedEvent)
eventToStr(BubbleAddedToMagazineEvent)
eventToStr(BubbleFiredEvent)
eventToStr(BlockLostEvent)


proc rgba*(color: BubbleColor) : RGBA =
  case color:
    of BubbleColor.Red: rgba(160,15,30,255)
    of BubbleColor.Green: rgba(15, 160, 30, 255)
    of BubbleColor.Blue: rgba(15, 30, 160, 255)
    of BubbleColor.Grey: rgba(100, 100, 100, 255)
    of BubbleColor.Black: rgba(75, 75, 75, 255)
    of BubbleColor.Yellow: rgba(255, 175, 50, 255)


proc createBubble*(world: LiveWorld) : Entity =
  result = world.createEntity()
  result.attachData(Bubble(
    radius: 24.0f32,
    elasticity: 0.5f32,
    maxNumber: 3
  ))


proc sumModifiers*(b: ref Bubble, k: BubbleModKind) : int =
  result = 0
  for m in b.modifiers:
    if m.kind == k: result += max(m.number, 1)

proc hasModifier*(b: ref Bubble, m: BubbleModKind) : bool =
  b.modifiers.anyMatchIt(it.kind == m)


proc sumModifiers*(b: ref Combatant, k: CombatantModKind) : int =
  result = 0
  for m in b.modifiers:
    if m.kind == k: result += max(m.number, 1)
  for e,ms in b.externalModifiers:
    for m in ms:
      if m.kind == k: result += max(m.number, 1)

proc hasModifier*(b: ref Combatant, k: CombatantModKind) : bool =
  sumModifiers(b, k) > 0

proc radius*(b: ref Bubble) : float32 =
  result = b.radius
  for m in b.modifiers:
    if m.kind == BubbleModKind.Big:
      result = 32.0f32

proc elasticity*(b: ref Bubble) : float32 =
  result = b.elasticity + sumModifiers(b, BubbleModKind.Bouncy).float32 * 0.15f32

proc maxNumber*(b: ref Bubble) : int =
  result = b.maxNumber + sumModifiers(b, BubbleModKind.HighNumber)

proc `maxNumber=`*(b: ref Bubble, i: int) =
  b.maxNumber = i

proc payload*(bubble: ref Bubble) : int =
  let base = if hasModifier(bubble, BubbleModKind.Chain):
    bubble.bounceCount
  else:
    1

  result = base + sumModifiers(bubble, BubbleModKind.Power)

proc potency*(bubble: ref Bubble) : int = 1 + sumModifiers(bubble, BubbleModKind.Potency)


proc bubbleMod*(k: BubbleModKind, num: int = 1) : BubbleMod =
  BubbleMod(kind: k, number: num)

proc combatantMod*(k: CombatantModKind, num: int = 1) : CombatantMod =
  CombatantMod(kind: k, number: num)

proc toRomanNumeral*(i: int, blankAtOne: bool = true) : string =
  case i:
    of 0:
      if blankAtOne: "" else: "0"
    of 1:
      if blankAtOne: "" else: "I"
    of 2: "II"
    of 3: "III"
    of 4: "IV"
    of 5: "V"
    of 6: "VI"
    of 7: "VII"
    of 8: "VIII"
    of 9: "IX"
    of 10: "X"
    else: $i

proc descriptor*(m: BubbleMod) : string =
  case m.kind:
    of BubbleModKind.Chromophobic: "Chromophobic"
    of BubbleModKind.Chromophilic: "Chromophilic"
    of BubbleModKind.Bouncy: &"Bouncy {toRomanNumeral(m.number)}"
    of BubbleModKind.Big: &"Big {toRomanNumeral(m.number)}"
    of BubbleModKind.HighNumber: &"Difficult {toRomanNumeral(m.number)}"
    of BubbleModKind.Normal: "Normal"
    of BubbleModKind.Power: &"x{m.number+1}"
    of BubbleModKind.Juggernaut: &"Juggernaut{toRomanNumeral(m.number)}"
    of BubbleModKind.Potency: &"Potent{toRomanNumeral(m.number)}"
    of BubbleModKind.WallAverse: &"Wall Averse{toRomanNumeral(m.number)}"
    of BubbleModKind.Chain: &"Chain{toRomanNumeral(m.number)}"
    of BubbleModKind.Exchange: &"Exchange"
    of BubbleModKind.Selfish: &"Selfish"
    of BubbleModKind.Exhaust: &"Exhaust"
    of BubbleModKind.Immovable: &"Immovable"


proc icon*(eff: PlayerEffect): Image =
  case eff.kind:
    of PlayerEffectKind.Attack: image("bubbles/images/icons/attack.png")
    of PlayerEffectKind.Block: image("bubbles/images/icons/block.png")
    of PlayerEffectKind.EnemyMod: image("bubbles/images/icons/debuff.png")
    of PlayerEffectKind.Mod: image("bubbles/images/icons/buff.png")
    of PlayerEffectKind.Bubble: image("bubbles/images/icons/bad_bubble.png")
    of PlayerEffectKind.LoseHealth: image("bubbles/images/icons/debuff.png")
    of PlayerEffectKind.TakeDamage: image("bubbles/images/icons/debuff.png")

proc icon*(intent: Intent): Image =
  # TODO: multiple icons
  for eff in intent.effects:
    return icon(eff)

proc color*(intent: Intent): RGBA =
  # Todo: multiple colors
  for eff in intent.effects:
    return case eff.kind:
      of PlayerEffectKind.Attack: rgba(0.75, 0.15, 0.2, 1.0)
      of PlayerEffectKind.Block: rgba(0.2, 0.1, 0.75, 1.0)
      of PlayerEffectKind.EnemyMod: rgba(0.1, 0.75, 0.2, 1.0)
      of PlayerEffectKind.Mod: rgba(0.2, 0.3, 0.8, 1.0)
      of PlayerEffectKind.Bubble: rgba(0.7, 0.7, 0.7, 1.0)
      of PlayerEffectKind.LoseHealth: rgba(0.75, 0.15, 0.2, 1.0)
      of PlayerEffectKind.TakeDamage: rgba(0.75, 0.15, 0.2, 1.0)

proc text*(intent: Intent): string =
  for eff in intent.effects:
    let tmp = case eff.kind:
      of PlayerEffectKind.Attack: $eff.amount
      of PlayerEffectKind.Block: $eff.amount
      of PlayerEffectKind.EnemyMod: ""
      of PlayerEffectKind.Mod: ""
      of PlayerEffectKind.Bubble: ""
      of PlayerEffectKind.LoseHealth: $eff.amount
      of PlayerEffectKind.TakeDamage: $eff.amount
    if tmp.nonEmpty:
      if result.nonEmpty:
        result.add("/")
      result.add(tmp)



proc icon*(m: CombatantModKind): Image =
  case m:
    of CombatantModKind.Strength: image("bubbles/images/icons/strength.png")
    of CombatantModKind.Dexterity: image("bubbles/images/icons/dex.png")
    of CombatantModKind.Vulnerable: image("bubbles/images/icons/vulnerable.png")
    of CombatantModKind.Weak: image("bubbles/images/icons/weak.png")
    of CombatantModKind.Footwork: image("bubbles/images/icons/footwork.png")

proc icon*(m: CombatantMod): Image =
  icon(m.kind)

proc nonEmpty*(magazine: Magazine): bool = magazine.bubbles.nonEmpty
proc isEmpty*(magazine: Magazine): bool = magazine.bubbles.isEmpty
proc takeBubble*(magazine: Magazine): Entity =
  result = magazine.bubbles[0]
  magazine.bubbles.delete(0)

proc activeMagazineIndex*(stage: ref Stage): int =
  for i in 0 ..< stage.magazines.len:
    if stage.magazines[i] == stage.activeMagazine:
      return i
  0

proc attachModifiers*(world: LiveWorld, src: Entity, target: Entity, combatMod: seq[CombatantMod]) =
  if combatMod.nonEmpty:
    let cd = target[Combatant]
    cd.externalModifiers.mgetOrPut(src, @[]).add(combatMod)

proc detachModifiers*(world: LiveWorld, src: Entity, target: Entity) =
  target[Combatant].externalModifiers.del(src)


proc readFromConfig*(cv: ConfigValue, v: var BubbleModKind) =
  v = parseEnum[BubbleModKind](cv.asStr)

proc readFromConfig*(cv: ConfigValue, v: var CollisionCondition) =
  v = parseEnum[CollisionCondition](cv.asStr)

proc readFromConfig*(cv: ConfigValue, v: var PopCondition) =
  v = parseEnum[PopCondition](cv.asStr)

proc readFromConfig*(cv: ConfigValue, v: var Rarity) =
  v = parseEnum[Rarity](cv.asStr)

proc readFromConfig*(cv: ConfigValue, v: var BubblePlacement) =
  v = parseEnum[BubblePlacement](cv.asStr)

proc readFromConfig*(cv: ConfigValue, v: var CombatantModKind) =
  v = parseEnum[CombatantModKind](cv.asStr)


proc readFromConfig*(cv: ConfigValue, v: var BubbleColor) =
  v = parseEnum[BubbleColor](cv.asStr)


const ModRE = re"([a-zA-Z0-9]+)\s?\(?([0-9]+)?\)?"
proc readFromConfig*(cv: ConfigValue, a: var BubbleMod) =
  matcher(cv.asStr):
    extractMatches(ModRE, kind, num):
      a.kind = parseEnum[BubbleModKind](kind)
      if num.nonEmpty:
        a.number = parseInt(num)
      else:
        a.number = 1
    warn &"Invalid BubbleMod expression: {cv}"

proc readFromConfig*(cv: ConfigValue, a: var CombatantMod) =
  if cv.isStr:
    matcher(cv.asStr):
      extractMatches(ModRE, kind, num):
        a.kind = parseEnum[CombatantModKind](kind)
        if num.nonEmpty:
          a.number = parseInt(num)
        else:
          a.number = 1
      warn &"Invalid CombatantMod expression: {cv}"
  else:
    warn &"Invalid CombatantMod expression: {cv}"

const AttackRE = re"(?i)attack\s?\(([0-9]+)\)"
const BlockRE = re"(?i)block\s?\(([0-9]+)\)"
const LoseHealthRE = re"(?i)lose\s?Health\s?\(([0-9]+)\)"
const TakeDamageRE = re"(?i)take\s?Damage\s?\(([0-9]+)\)"
proc readFromConfig*(cv: ConfigValue, a: var PlayerEffect) =
  if cv.isStr:
    matcher(cv.asStr):
      extractMatches(AttackRE, num):
        a = PlayerEffect(kind: PlayerEffectKind.Attack, amount: parseInt(num))
      extractMatches(BlockRE, num):
        a = PlayerEffect(kind: PlayerEffectKind.Block, amount: parseInt(num))
      extractMatches(LoseHealthRE, num):
        a = PlayerEffect(kind: PlayerEffectKind.LoseHealth, amount: parseInt(num))
      extractMatches(TakeDamageRE, num):
        a = PlayerEffect(kind: PlayerEffectKind.TakeDamage, amount: parseInt(num))
      a = PlayerEffect(kind: PlayerEffectKind.Mod, modifier: readInto(cv, CombatantMod))
  elif cv.isArr:
    let sections = cv.asArr
    if sections.len > 0:
      let effKind = sections[0].asStr.toLowerAscii
      case effKind:
        of "mod", "modifier":
          if sections.len != 4: warn &"Array based Mod PlayerEffect must have 4 sections: {sections}"
          let target = sections[1].asStr
          let kind = sections[2].readInto(CombatantModKind)
          let num = sections[3].asInt
          let modifier = CombatantMod(kind: kind, number: num)
          case target.toLowerAscii:
            of "enemy": a = PlayerEffect(kind: PlayerEffectKind.EnemyMod, modifier: modifier)
            of "self": a = PlayerEffect(kind: PlayerEffectKind.Mod, modifier: modifier)
            else: warn &"Invalid target for PlayerEffect: {target}"
        of "bubble":
          if sections.len != 3: warn &"Array based Bubble PlayerEffect must have 4 sections: {sections}"
          let bubbleArch = taxon("bubbles", sections[1].asStr)
          let bubblePlacement = sections[2].readInto(BubblePlacement)
          a = PlayerEffect(kind: PlayerEffectKind.Bubble, bubbleArchetype: bubbleArch, bubblePlacement: bubblePlacement)
        of "attack":
          let damageAmount = sections[1].asInt
          var noBlockLoss = false
          for i in 2 ..< sections.len:
            case sections[i].asStr.toLowerAscii:
              of "no block loss": noBlockLoss = true
              else: warn &"Invalid modifier to attack: {sections[i]}"
          a = PlayerEffect(kind: PlayerEffectKind.Attack, amount: damageAmount, noBlockLoss: noBlockLoss)
        of "losehealth":
          let amount = sections[1].asInt
          a = PlayerEffect(kind: PlayerEffectKind.LoseHealth, amount: amount)
        else: warn &"Invalid effect kind for arr based config: {sections}"
    else:
      warn &"Array based PlayerEffect must have > 0 sections"

proc readFromConfig*(cv: ConfigValue, e: var OnCollideEffect) =
  if cv["effect"].nonEmpty:
    cv["effect"].readInto(e.effects)
  else:
    cv["effects"].readInto(e.effects)
    
  if cv["condition"].nonEmpty:
    cv["condition"].readInto(e.conditions)
  else:
    cv["conditions"].readInto(e.conditions)

proc readFromConfig*(cv: ConfigValue, e: var OnPopEffect) =
  if cv.isStr:
    e.effects = @[cv.readInto(PlayerEffect)]
  elif cv.isArr:
    e.effects = @[cv.readInto(PlayerEffect)]
  else:
    if cv["effect"].nonEmpty:
      cv["effect"].readInto(e.effects)
    else:
      cv["effects"].readInto(e.effects)

    if cv["condition"].nonEmpty:
      cv["condition"].readInto(e.conditions)
    else:
      cv["conditions"].readInto(e.conditions)



proc readFromConfig*(cv: ConfigValue, a: var BubbleArchetype) =
  cv["name"].readInto(a.name)
  let ci = cv["image"]
  if ci.nonEmpty:
    if ci.isStr and not ci.asStr.contains("/"):
      a.image = image(&"bubbles/images/bubble/{ci.asStr}")
    else:
      ci.readInto(a.image)
  cv["numeralColor"].readIntoOrElse(a.numeralColor, rgba(190,190,190,255))
  cv["rarity"].readInto(a.rarity)
  cv["maxNumber"].readIntoOrElse(a.maxNumber, 3)
  cv["color"].readInto(a.color)
  cv["secondaryColors"].readInto(a.secondaryColors)
  cv["modifiers"].readInto(a.modifiers)
  cv["onPopEffects"].readInto(a.onPopEffects)
  cv["onFireEffects"].readInto(a.onFireEffects)
  cv["inPlayPlayerMods"].readInto(a.inPlayPlayerMods)
  cv["onCollideEffects"].readInto(a.onCollideEffects)
  cv["duration"].readInto(a.duration)


proc readFromConfig*(cv: ConfigValue, e: var Combatant) =
  cv["health"].readInto(e.health)
  cv["name"].readInto(e.name)
  cv["image"].readInto(e.image)

proc readFromConfig*(cv: ConfigValue, e: var Intent) =
  if cv["effect"].nonEmpty: cv["effect"].readInto(e.effects)
  if cv["effects"].nonEmpty: cv["effects"].readInto(e.effects)
  cv["duration"].readInto(e.duration)

proc readFromConfig*(cv: ConfigValue, e: var Enemy) =
  cv["intents"].readInto(e.intents)

proc readFromConfig*(cv: ConfigValue, e: var EnemyArchetype) =
  cv.readInto(e.enemyData)
  cv.readInto(e.combatantData)

proc readFromConfig*(cv: ConfigValue, e: var EnemyGroupEntry) =
  if cv.isStr:
    e.possibleEnemyKinds = @[taxon("Enemies", cv.asStr)]
  elif cv.isArr:
    for sv in cv.asArr:
      e.possibleEnemyKinds.add(taxon("Enemies", sv.asStr))

defineSimpleReadFromConfig(EnemyGroup)



defineSimpleLibrary[BubbleArchetype]("bubbles/game/bubbles.sml", "Bubbles")
defineSimpleLibrary[EnemyArchetype]("bubbles/game/enemies.sml", "Enemies")
defineSimpleLibrary[EnemyGroup]("bubbles/game/enemy_groups.sml", "EnemyGroups")

info "=============================================="

for t, v in library(BubbleArchetype):
  info &"{t} : {v[]}"

info "=============================================="

for t, v in library(EnemyArchetype):
  info &"{t} : {v[]}"

info "=============================================="