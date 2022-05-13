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

  BubbleMod* = object
    kind*: BubbleModKind
    number*: int

  Bubble* = object
    position*: Vec2f
    radius: float32
    velocity*: Vec2f
    number*: int
    maxNumber: int
    color*: BubbleColor
    elasticity: float32
    modifiers*: seq[BubbleMod]

  Stage* = object
    active*: bool
    bounds*: Rectf
    bubbles*: seq[Entity]
    cannon*: Entity
    linearDrag*: float32
    magazine*: seq[Entity]
    progress*: int
    progressRequired*: Option[int]
    level*: int

  StageDescription* = object
    cannonPosition*: Vec2f
    cannonVelocity*: float
    linearDrag*: float32
    progressRequired*: Option[int]
    level*: int
    makeActive*: bool

  Reward* = object
    bubbles*: seq[Entity]

  Player* = object
    bubbles*: seq[Entity]
    pendingRewards*: seq[Reward]
    completedLevel*: int

  Cannon* = object
    position*: Vec2f
    direction*: Vec2f
    maxVelocity*: float
    currentVelocityScale*: float

  BubbleMovedEvent* = ref object of GameEvent
    stage*: Entity
    bubble*: Entity

  BubbleStoppedEvent* = ref object of GameEvent
    stage*: Entity
    bubble*: Entity

  BubblePoppedEvent* = ref object of GameEvent
    stage*: Entity
    bubble*: Entity

  BubbleCollisionEvent* = ref object of GameEvent
    stage*: Entity
    bubbles*: (Entity, Entity)

  BubbleCollisionEndEvent* = ref object of GameEvent
    stage*: Entity
    bubbles*: (Entity, Entity)

  BubbleRewardCreatedEvent* = ref object of GameEvent
    bubble*: Entity


defineReflection(Bubble)
defineReflection(Stage)
defineReflection(Cannon)
defineReflection(Player)

eventToStr(BubbleMovedEvent)
eventToStr(BubbleStoppedEvent)
eventToStr(BubblePoppedEvent)
eventToStr(BubbleCollisionEvent)
eventToStr(BubbleCollisionEndEvent)
eventToStr(BubbleRewardCreatedEvent)


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


proc radius*(b: ref Bubble) : float32 =
  result = b.radius
  for m in b.modifiers:
    if m.kind == BubbleModKind.Big:
      result = 32.0f32

proc elasticity*(b: ref Bubble) : float32 =
  result = b.elasticity
  for m in b.modifiers:
    case m.kind:
      of BubbleModKind.Bouncy: result += 0.15f32
      else: discard

proc maxNumber*(b: ref Bubble) : int =
  result = b.maxNumber
  for m in b.modifiers:
    case m.kind:
      of BubbleModKind.HighNumber:
        result += max(m.number, 1)
      else: discard

proc hasModifier*(b: ref Bubble, m: BubbleModKind) : bool =
  b.modifiers.anyMatchIt(it.kind == m)

proc bubbleMod*(k: BubbleModKind, num: int = 1) : BubbleMod =
  BubbleMod(kind: k, number: num)

proc toRomanNumeral*(i: int) : string =
  case i:
    of 0: "0"
    of 1: "I"
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
    of BubbleModKind.Bouncy: &"Bouncy {toRomanNumeral(m.number)}"
    of BubbleModKind.Big: &"Big {toRomanNumeral(m.number)}"
    of BubbleModKind.HighNumber: &"Difficult {toRomanNumeral(m.number)}"
    of BubbleModKind.Normal: "Normal"