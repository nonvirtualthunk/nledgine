import itb/game/board
import itb/game/characters
import itb/game/progress
import reflect
import engines
import core
import glm
import options
import noto
import prelude
import patty
import tables

variantp CharActionResult:
  CharMove(path: seq[Vec2i])
  CharDamage(damage: int)


proc moveCharacter*(world: World, ent: Entity, origin: Vec2i, destination: Vec2i, force: bool = false) =
  if inBounds(destination):
    world.eventStmts(EntityMoved(entity: ent, origin: origin, destination: destination, forced: force)):
      if not force:
        let cost = moveCost(world.data(Progress).activeBoard.get.data(Board), destination)
        modify(ent, Character.moves.reduceBy(cost))
      modify(ent, Character.position := destination)


proc moveCharacter*(world: World, ent: Entity, path: Path) =
  for i in 1 ..< path.tiles.len:
    let origin = path.tiles[i-1]
    let destination = path.tiles[i]

    moveCharacter(world, ent, origin, destination)

proc damageCharacter*(world: World, ent: Entity, damage: int) =
  withWorld(world):
    world.eventStmts(EntityDamaged(entity: ent, damage: damage, newHealth : ent.data(Character).health.currentValue - damage)):
      modify(ent, Character.health.reduceBy(damage))
      if ent.data(Character).health.currentValue <= 0:
        modify(ent, Character.dead := true)
        modify(ent, Character.position := vec2i(-10000,-10000))

proc canPerformAction*(view: WorldView, ent: Entity, action: CharAction, target: Vec2i) : bool =
  withView(view):
    let cpos = ent.data(Character).position
    let dist = (target.x - cpos .x).abs + (target.y - cpos.y).abs
    if dist < action.targeting.minRange or dist > action.targeting.maxRange:
      return false

    if action.targeting.straightLine and target.x != cpos.x and target.y != cpos.y:
      return false

    if not action.targeting.arc and dist > 1:
      warn "arc vs no arc not yet implemented"

    true


proc transformVector*(originPos: Vec2i, srcPos: Vec2i, relVec: Vec2i) : Vec2i =
  if originPos == srcPos:
    relVec
  else:
    if srcPos.x != originPos.x and srcPos.y != originPos.y:
      warn "Diagonal vector operations in action effects not yet implemented"
      relVec
    else:
      var forward = vec2i(1,0)
      var ortho = vec2i(0,1)
      if srcPos.x == originPos.x:
        if srcPos.y > originPos.y:
          forward = vec2i(0,1)
          ortho = vec2i(-1,0)
        else:
          forward = vec2i(0,-1)
          ortho = vec2i(1,0)
      else:
        if srcPos.x < originPos.x:
          forward = vec2i(-1,0)
          ortho = vec2i(0,-1)
      forward * relVec.x + ortho * relVec.y



proc startTurn*(world: World, ent: Entity) =
  world.eventStmts(StartEntityTurnEvent(entity: ent)):
    ent.modify(Character.moves := reduceable(ent.data(Character).baseMove))
    ent.modify(Character.ap := reduceable(1))


proc computeActionResults*(world: WorldView, ent: Entity, action: CharAction, target: Vec2i) : Table[Entity, seq[CharActionResult]] =
  withView(world):
    for effect in action.effects:
      var entPos = ent.data(Character).position

      let targetTile = case effect.targetKind:
        of Self: entPos
        of Target:
          target + transformVector(entPos, target, effect.targetOffset)

      case effect.kind:
        of MoveEffect:
          for charAt in characterAt(world, targetTile):
            var path: seq[Vec2i]
            var pos = charAt.data(Character).position
            let relVec = DirectionVectors[effect.Direction.ord]
            let moveVec = transformVector(entPos, target, relVec)
            for i in 0 ..< effect.moveDistance:
              pos += moveVec
              path.add(pos)
            result.mgetOrPut(charAt, @[]).add(CharMove(path))
        of DamageEffect:
          for charAt in characterAt(world, targetTile):
            result.mgetOrPut(charAt, @[]).add(CharDamage(effect.damage))

proc performAction*(world: World, ent: Entity, action: CharAction, target: Vec2i) =
  world.eventStmts(ActionPerformed(entity: ent, action: action, target: target)):
    for char, results in computeActionResults(world, ent, action, target):
      for r in results:
        match r:
          CharMove(path):
            for t in path:
              moveCharacter(world, char, char.data(Character).position, t, true)
          CharDamage(damage):
            damageCharacter(world, char, damage)
    ent.modify(Character.moves := reduceable(0))
    ent.modify(Character.ap := reduceable(0))
