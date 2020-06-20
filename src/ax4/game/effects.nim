import effect_types
import attacks
import options
import worlds
import tables
import targeting
import prelude
import patty
import noto
import flags

proc effectiveAttack*(character : Entity, effect : GameEffect) : Option[Attack] =
   let attack = resolveAttack(character, effect.attackSelector)
   if attack.isSome:
      var attack = attack.get
      if effect.kind == GameEffectKind.SpecialAttack:
         attack.applyModifiers(effect.attackModifier)
      some(attack)
   else:
      attack

proc expandCosts*(character : Entity, effect : GameEffect) : seq[GameEffect] = 
   case effect.kind:
   of GameEffectKind.BasicAttack, GameEffectKind.SpecialAttack:
      for attack in effectiveAttack(character, effect):
         result = attackCosts(attack)
   else: 
      discard


proc selectionsForEffect*(character : Entity, effect : GameEffect) : Table[SelectorKey, Selector] =
   case effect.kind:
   of GameEffectKind.BasicAttack, GameEffectKind.SpecialAttack:
      for attack in effectiveAttack(character, effect):
         result[Primary()] = match attack.target:
            Single: enemySelector(1)
            Multiple(count): enemySelector(count)
            Shape(shape): charactersInShapeSelector(shape)
   of GameEffectKind.ChangeFlag, GameEffectKind.ChangeResource:
      result[Primary()] = effect.target
   of GameEffectKind.Move:
      result[Subject()] = effect.target
      result[Object()] = pathSelector(effect.moveRange, Subject())
   



proc resolveEffect*(world : World, character : Entity, effectPlay : EffectPlay) : bool =
   withWorld(world):
      let effect = effectPlay.effect
      case effect.kind:
      of GameEffectKind.BasicAttack, GameEffectKind.SpecialAttack:
         let attack = effectiveAttack(character, effect)
         if attack.isSome:
            let attack = attack.get
            
            let targets = effectPlay.selected[Primary()]
            # do attack
      of GameEffectKind.ChangeFlag:
         let flag = effect.flag
         let modifier = effect.flagModifier

         let flags = character.data(Flags)
         var curValue = flags.getOrDefault(flag)
         modifier.apply(curValue)
         character.modify(Flags.flags.put())
      else:
         warn "unimplemented effect : ", $effect