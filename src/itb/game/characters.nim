import prelude
import core
import glm
import worlds
import options
import engines/event_types


type
  Character* = object
    name*: string
    className*: string
    health*: Reduceable[int]
    moves*: Reduceable[int]
    ap*: Reduceable[int]
    baseMove* : int
    actions*: seq[CharAction]
    position*: Vec2i
    playerCharacter*: bool
    dead*: bool


  Direction* = enum
    Forward
    Right
    Back
    Left

  EffectKind* = enum
    MoveEffect
    DamageEffect

  TargetKind* = enum
    Target,
    Self,

  Effect* = object
    targetKind*: TargetKind
    targetOffset*: Vec2i # offset expressed in right-facing coordinates, gets rotated based on actual relative position
    case kind*: EffectKind:
    of MoveEffect:
      Direction*: Direction
      moveDistance*: int
    of DamageEffect:
      damage*: int

  Targeting* = object
    minRange*: int
    maxRange*: int
    straightLine*: bool
    arc*: bool


  CharAction* = object
    name*: string
    description*: string
    targeting*: Targeting
    effects*: seq[Effect]



  CharMod* = object
    moves*: int
    health*: int
    armor*: int
    damage*: int

  ActionPerformed* = ref object of GameEvent
    entity*: Entity
    action*: CharAction
    target*: Vec2i

  EntityDamaged* = ref object of GameEvent
    entity*: Entity
    damage*: int
    newHealth*: int

const DirectionVectors* = [vec2i(1,0), vec2i(0,-1), vec2i(-1,0), vec2i(0,1)]


defineReflection(Character)



method toString*(evt: ActionPerformed): string =
   return &"ActionPerformed{$evt[]}"
method toString*(evt: EntityDamaged): string =
   return &"EntityDamaged{$evt[]}"


proc targetAdjacent() : Targeting = Targeting(minRange: 1, maxRange: 1, straightLine: true)


let SwordSlash* = CharAction(
  name: "sword slash",
  description: "slash a single target",
  targeting: targetAdjacent(),
  effects: @[
    Effect(
      kind: DamageEffect,
      targetKind: Target,
      targetOffset: vec2i(0,0),
      damage: 3
    )
  ]
)

let SwordSweep* = CharAction(
  name: "sword sweep",
  description: "slash targets in the three tiles in front of you",
  targeting: targetAdjacent(),
  effects: @[
    Effect(
      kind: DamageEffect,
      targetOffset: vec2i(0,1),
      damage: 2
    ),
    Effect(
      kind: DamageEffect,
      targetOffset: vec2i(0,0),
      damage: 2
    ),
    Effect(
      kind: DamageEffect,
      targetOffset: vec2i(0,-1),
      damage: 2
    )
  ]
)

let ClubAside* : CharAction = CharAction(
  name: "club aside",
  description: "bash a target out of your way",
  targeting: targetAdjacent(),
  effects: @[
    Effect(
      kind: DamageEffect,
      targetKind: TargetKind.Target,
      targetOffset: vec2i(0,0),
      damage: 1
    ),
    Effect(
      kind: MoveEffect,
      targetOffset: vec2i(0,0),
      targetKind: TargetKind.Target,
      Direction: Direction.Left,
      moveDistance: 1,
    ),
  ]
)

proc availableActions*(view: WorldView, c : Entity) : seq[CharAction] =
  withView(view):
    c.data(Character).actions


proc characterAt*(view: WorldView, at: Vec2i): Option[Entity] =
  withView(view):
    for c in view.entitiesWithData(Character):
      if c.data(Character).position == at:
        return some(c)

    none(Entity)