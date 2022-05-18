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

  BubbleMod* = object
    kind*: BubbleModKind
    number*: int

  Wall* {.pure.} = enum
    Left
    Right
    Top
    Bottom

  Bubble* = object
    archetype*: ref BubbleArchetype
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
    onPopEffects*: seq[PlayerEffect]
    inPlayPlayerMods*: seq[CombatantMod]

  BubbleArchetype* = object
    name*: string
    maxNumber*: int
    color*: BubbleColor
    secondaryColors*: seq[BubbleColor]
    modifiers*: seq[BubbleMod]
    onPopEffects*: seq[PlayerEffect]
    inPlayPlayerMods*: seq[CombatantMod]

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
    enemy*: Entity

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


  CombatantMod* = object
    kind*: CombatantModKind
    number*: int

  PlayerEffectKind* {.pure.} = enum
    Attack
    Block
    Mod

  PlayerEffect* = object
    amount*: int
    case kind*: PlayerEffectKind:
      of PlayerEffectKind.Attack, PlayerEffectKind.Block: discard
      of PlayerEffectKind.Mod:
        modifier*: CombatantMod


  Player* = object
    bubbles*: seq[Entity]
    pendingRewards*: seq[Reward]
    completedLevel*: int
    actionProgress*: Table[PlayerActionKind, int]
    actionProgressRequired*: Table[PlayerActionKind, int]
    effects*: Table[PlayerActionKind, seq[PlayerEffect]]
    playArea*: Rectf


  Cannon* = object
    position*: Vec2f
    direction*: Vec2f
    maxVelocity*: float
    currentVelocityScale*: float

  IntentKind* {.pure.} = enum
    Attack
    Block

  Intent* = object
    amount*: int
    duration*: Reduceable[int]
    case kind*: IntentKind
    of IntentKind.Attack:
      discard
    of IntentKind.Block:
      discard

  Enemy* = object
    intents*: seq[Intent]
    activeIntent*: Intent

  BubbleEvent* = ref object of GameEvent

  CharacterEvent* = ref object of GameEvent

  BubbleMovedEvent* = ref object of BubbleEvent
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

  BlockGainedEvent* = ref object of CharacterEvent
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


proc rgba*(color: BubbleColor) : RGBA =
  case color:
    of BubbleColor.Red: rgba(160,15,30,255)
    of BubbleColor.Green: rgba(15, 160, 30, 255)
    of BubbleColor.Blue: rgba(15, 30, 160, 255)
    of BubbleColor.Grey: rgba(125, 125, 125, 255)
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


proc icon*(intent: Intent): Image =
  case intent.kind:
    of IntentKind.Attack: image("bubbles/images/icons/attack.png")
    of IntentKind.Block: image("bubbles/images/icons/block.png")

proc color*(intent: Intent): RGBA =
  case intent.kind:
    of IntentKind.Attack: rgba(0.75, 0.15, 0.2, 1.0)
    of IntentKind.Block: rgba(0.2, 0.1, 0.75, 1.0)


proc icon*(m: CombatantModKind): Image =
  case m:
    of CombatantModKind.Strength: image("bubbles/images/icons/strength.png")
    of CombatantModKind.Dexterity: image("bubbles/images/icons/dex.png")

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
  matcher(cv.asStr):
    extractMatches(ModRE, kind, num):
      a.kind = parseEnum[CombatantModKind](kind)
      if num.nonEmpty:
        a.number = parseInt(num)
      else:
        a.number = 1
    warn &"Invalid CombatantMod expression: {cv}"

const AttackRE = re"(?i)attack\s?\(([0-9]+)\)"
const BlockRE = re"(?i)block\s?\(([0-9]+)\)"
proc readFromConfig*(cv: ConfigValue, a: var PlayerEffect) =
  matcher(cv.asStr):
    extractMatches(AttackRE, num):
      a = PlayerEffect(kind: PlayerEffectKind.Attack, amount: parseInt(num))
    extractMatches(BlockRE, num):
      a = PlayerEffect(kind: PlayerEffectKind.Block, amount: parseInt(num))
    a = PlayerEffect(kind: PlayerEffectKind.Mod, modifier: readInto(cv, CombatantMod))


proc readFromConfig*(cv: ConfigValue, a: var BubbleArchetype) =
  cv["name"].readInto(a.name)
  cv["maxNumber"].readIntoOrElse(a.maxNumber, 3)
  cv["color"].readInto(a.color)
  cv["secondaryColors"].readInto(a.secondaryColors)
  cv["modifiers"].readInto(a.modifiers)
  cv["onPopEffects"].readInto(a.onPopEffects)
  cv["inPlayPlayerMods"].readInto(a.inPlayPlayerMods)

defineSimpleLibrary[BubbleArchetype]("bubbles/game/bubbles.sml", "Bubbles")

for t, v in library(BubbleArchetype):
  info &"{t} : {v[]}"