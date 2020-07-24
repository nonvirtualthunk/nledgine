import hex
import engines/event_types
import worlds
import patty
import effect_types
import root_types
import options
import config
import strutils
import noto

# variantp AxEvent:
#    EntityTurnStarted()


type
   # EventKind* = enum
   #    CharacterTurnStartEvent
   #    CharacterTurnEndEvent
   #    CharacterMoveEvent
   #    AttackEvent
   #    StrikeEvent
   #    FlagChangedEvent
   #    ResourceChangedEvent

   # AxEvent* = ref object of GameEvent
   #    entity* : Entity

   #    case kind* : EventKind:
   #    of CharacterTurnStartEvent, CharacterTurnEndEvent:
   #       turnNumber* : int
   #    of CharacterMoveEvent:
   #       fromHex* : AxialVec
   #       toHex* : AxialVec
   #    of AttackEvent:
   #       attack* : ref Attack
   #       attackTargets* : seq[Entity]
   #    of StrikeEvent:
   #       strikeTargets* : seq[Entity]
   #       strikeAttack* : ref Attack
   #       strikeResult* : StrikeResult
   #    of FlagChangedEvent:
   #       flag* : Taxon
   #       oldFlagValue* : int
   #       newFlagValue* : int
   #    of ResourceChangedEvent:
   #       resource* : Taxon
   #       oldResourceValue* : int
   #       newResourceValue* : int
   AxEvent* = ref object of GameEvent
      entity*: Entity

   CharacterTurnStartEvent* = ref object of AxEvent
      turnNumber*: int
   CharacterTurnEndEvent* = ref object of AxEvent
      turnNumber*: int
   CharacterMoveEvent* = ref object of AxEvent
      fromHex*: AxialVec
      toHex*: AxialVec
   AttackEvent* = ref object of AxEvent
      attack*: ref Attack
      targets*: seq[Entity]
   StrikeEvent* = ref object of AxEvent
      targets*: seq[Entity]
      attack*: ref Attack
      result*: StrikeResult
   FlagChangedEvent* = ref object of AxEvent
      flag*: Taxon
      oldValue*: int
      newValue*: int
   WorldInitializedEvent* = ref object of AxEvent



   EventConditionKind* = enum
      OnAttack
      OnAttacked
      OnHit
      OnHitEnemy
      OnMissed
      OnBlocked
      OnTurnStarted
      OnTurnEnded
      OnDodged

   EventCondition* = object
      case kind*: EventConditionKind
      of OnAttack, OnAttacked, OnHit, OnHitEnemy, OnBlocked, OnMissed, OnDodged:
         attackSelector*: Option[AttackSelector]
      of OnTurnStarted, OnTurnEnded:
         discard

# proc matchesEventKind*(condition : EventCondition) : EventKind =
#    case condition.kind:
#    of OnAttacked: AttackEvent
#    of OnAttack: AttackEvent
#    of OnHit: StrikeEvent
#    of OnHitEnemy: StrikeEvent
#    of OnMissed: StrikeEvent
#    of OnBlocked: StrikeEvent
#    of OnTurnStarted: CharacterTurnStartEvent
#    of OnTurnEnded: CharacterTurnEndEvent

proc matchesSelector(view: WorldView, selector: Option[AttackSelector], attack: ref Attack): bool =
   selector.isNone or selector.get.matches(view, attack[])

# proc matches*(view : WorldView, condition : EventCondition, event : AxEvent) : seq[Entity] =
#    case condition.kind:
#    of OnAttacked:
#       if event.kind == AttackEvent and matchesSelector(view, condition.attackSelector, event.attack): result.add(event.attackTargets)
#    of OnAttack:
#       if event.kind == AttackEvent and matchesSelector(view, condition.attackSelector, event.attack): result.add(event.entity)
#    of OnHit:
#       if event.kind == StrikeEvent and event.strikeResult.kind == StrikeResultKind.Hit and matchesSelector(view, condition.attackSelector, event.strikeAttack): result.add(event.strikeTargets)
#    of OnHitEnemy:
#       if event.kind == StrikeEvent and event.strikeResult.kind == StrikeResultKind.Hit and matchesSelector(view, condition.attackSelector, event.strikeAttack): result.add(event.entity)
#    of OnMissed:
#       if event.kind == StrikeEvent and event.strikeResult.kind == StrikeResultKind.Missed and matchesSelector(view, condition.attackSelector, event.strikeAttack): result.add(event.strikeTargets)
#    of OnDodged:
#       if event.kind == StrikeEvent and event.strikeResult.kind == StrikeResultKind.Dodged and matchesSelector(view, condition.attackSelector, event.strikeAttack): result.add(event.strikeTargets)
#    of OnBlocked:
#       if event.kind == StrikeEvent and event.strikeResult.kind == StrikeResultKind.Blocked and matchesSelector(view, condition.attackSelector, event.strikeAttack): result.add(event.strikeTargets)
#    of OnTurnStarted:
#       if event.kind == CharacterTurnStartEvent: result.add(event.entity)
#    of OnTurnEnded:
#       if event.kind == CharacterTurnEndEvent: result.add(event.entity)

proc matches*(view: WorldView, condition: EventCondition, event: AxEvent): seq[Entity] =
   case condition.kind:
   of OnAttacked:
      ifOfType(AttackEvent, event):
         if matchesSelector(view, condition.attackSelector, event.attack): result.add(event.targets)
   of OnAttack:
      ifOfType(AttackEvent, event):
         if matchesSelector(view, condition.attackSelector, event.attack): result.add(event.entity)
   of OnHit:
      ifOfType(StrikeEvent, event):
         if event.result.kind == StrikeResultKind.Hit and matchesSelector(view, condition.attackSelector, event.attack): result.add(event.targets)
   of OnHitEnemy:
      ifOfType(StrikeEvent, event):
         if event.result.kind == StrikeResultKind.Hit and matchesSelector(view, condition.attackSelector, event.attack): result.add(event.entity)
   of OnMissed:
      ifOfType(StrikeEvent, event):
         if event.result.kind == StrikeResultKind.Missed and matchesSelector(view, condition.attackSelector, event.attack): result.add(event.targets)
   of OnDodged:
      ifOfType(StrikeEvent, event):
         if event.result.kind == StrikeResultKind.Dodged and matchesSelector(view, condition.attackSelector, event.attack): result.add(event.targets)
   of OnBlocked:
      ifOfType(StrikeEvent, event):
         if event.result.kind == StrikeResultKind.Blocked and matchesSelector(view, condition.attackSelector, event.attack): result.add(event.targets)
   of OnTurnStarted:
      ifOfType(CharacterTurnStartEvent, event): result.add(event.entity)
   of OnTurnEnded:
      ifOfType(CharacterTurnEndEvent, event): result.add(event.entity)

# proc matches*(condition : EventCondition, entity : Entity, event : AxEvent) : bool =
#    case condition.kind:
#    of OnAttacked:
#       event.kind == AttackEvent and event.attackTargets.contains(entity)
#    of OnAttack:
#       event.kind == AttackEvent and event.entity == entity
#    of OnHit:
#       event.kind == StrikeEvent and event.attackTargets.contains(entity) and event.strikeResult.kind == StrikeResultKind.Hit
#    of OnHitEnemy:
#       event.kind == StrikeEvent and event.entity == entity and event.strikeResult.kind == StrikeResultKind.Hit
#    of OnMissed:
#       event.kind == StrikeEvent and event.strikeTargets.contains(entity) and event.strikeResult.kind == StrikeResultKind.Missed
#    of OnDodged:
#       event.kind == StrikeEvent and event.strikeTargets.contains(entity) and event.strikeResult.kind == StrikeResultKind.Dodged
#    of OnBlocked:
#       event.kind == StrikeEvent and event.strikeTargets.contains(entity) and event.strikeResult.kind == StrikeResultKind.Blocked
#    of OnTurnStarted:
#       event.kind == CharacterTurnStartEvent and event.entity == entity
#    of OnTurnEnded:
#       event.kind == CharacterTurnEndEvent and event.entity == entity
#    # EntityTurnStarted* = ref object of GameEvent
#    #    entity* : Entity
#    #    turnNumber* : int

   # EntityTurnEnded* = ref object of GameEvent
   #    entity* : Entity
   #    turnNumber* : int

   # EntityMoved* = ref object of GameEvent
   #    entity* : Entity
   #    fromHex* : AxialVec
   #    toHex* : AxialVec




proc readFromConfig*(cv: ConfigValue, v: var EventCondition) =
   var condKind: EventConditionKind
   if cv.isStr:
      case cv.asStr.toLowerAscii:
      of "onattacked": condKind = OnAttacked
      of "onattack": condKind = OnAttack
      of "onhit": condKind = OnHit
      of "onhitenemy": condKind = OnHitEnemy
      of "onmissed": condKind = OnMissed
      of "onblocked": condKind = OnBlocked
      of "onturnstarted": condKind = OnTurnStarted
      of "onturnended": condKind = OnTurnEnded
      else: warn &"invalid configuration string for event condition : {cv.asStr}"

      v = EventCondition(kind: condKind)
   else: warn &"invalid configuration for event condition: {$cv}"
